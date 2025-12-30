function results = test_classifier(activity_path, model_path, cfg)
% TEST_CLASSIFIER Evaluates the BCI model on online data.
%
% This function loads the online 'Activity' data and the trained model.
% It performs two types of evaluation:
%   1. Single Sample: Accuracy of the classifier on every individual time point.
%   2. Simulated Online Control: Applies an evidence accumulation framework
%      (exponential smoothing) on the posterior probabilities to determine
%      trial accuracy and command delivery latency.
%
% INPUTS:
%   activity_path - Path to the 'Activity' .mat file (Online runs).
%   model_path    - Path to the trained 'classifier_model.mat'.
%   cfg           - Configuration struct.
%
% OUTPUT:
%   results       - Struct containing accuracy metrics and latencies.

    %% Input Validation
    if nargin < 3
        error('[test_classifier] Not enough input arguments.');
    end

    fprintf('[test_classifier] Loading data: %s\n', activity_path);
    fprintf('[test_classifier] Loading model: %s\n', model_path);

    if ~exist(activity_path, 'file') || ~exist(model_path, 'file')
        error('[test_classifier] Input files missing.');
    end

    % Load Data
    data_act = load(activity_path);
    Activity = data_act.Activity;            
    labels   = data_act.all_trials_labels;
    onsets   = data_act.all_cue_onsets;
    
    % Load Model and selected feature indices
    data_model   = load(model_path);
    model        = data_model.model;
    selected_idx = data_model.selected_idx;

    %% Configuration for Evidence Accumulation
    % alpha: Smoothing factor (0 to 1). Higher = more smoothing (slower but more stable).
    % threshold: Confidence level required to deliver a command.
    accum_alpha     = 0.95; 
    accum_threshold = 0.75; 
    
    class_A = cfg.codes.hands;
    class_B = cfg.codes.feet;
    
    %% Evaluation Loop
    fprintf('[test_classifier] Evaluating %d trials...\n', length(labels));
    
    [~, n_freq, n_chan, n_trials] = size(Activity);
    n_features_total = n_freq * n_chan;

    % Accumulators for Global Metrics
    total_samples = 0;
    correct_samples = 0;
    
    trial_results = zeros(n_trials, 1); % 1 = Correct, 0 = Incorrect/Miss
    command_latencies = [];             % Time (seconds) to reach threshold
    
    for t = 1:n_trials
        %% 1. Data Preparation (Same as Training)
        t_start = onsets(t);
        
        % Slice active phase (Cue -> Feedback End)
        trial_data = Activity(t_start:end, :, :, t);
        
        % Flatten: [Time x Features]
        trial_flat = reshape(trial_data, size(trial_data, 1), n_features_total);
        
        % Handle NaNs (padding)
        valid_rows = ~any(isnan(trial_flat), 2);
        X_trial = trial_flat(valid_rows, :);
        
        % Select Features (Crucial: Must match training features)
        X_trial_selected = X_trial(:, selected_idx);
        
        true_label = labels(t);
        
        %% 2. Single Sample Prediction
        % predict returns: label, score (posterior probabilities)
        [pred_labels, post_probs] = predict(model, X_trial_selected);
        
        % Calculate Single Sample Accuracy
        correct_samples = correct_samples + sum(pred_labels == true_label);
        total_samples = total_samples + length(pred_labels);
        
        %% 3. Evidence Accumulation (Simulated Online Control)
        % We smooth the posterior probabilities over time.
        % Formula: P(t) = alpha * P(t-1) + (1-alpha) * current_posterior
        
        % Determine column index for the true class in posterior matrix
        % The 'ClassNames' property tells us which column is which
        class_names = model.ClassNames;
        idx_hands_col = find(class_names == class_A);
        idx_feet_col  = find(class_names == class_B);
        
        % Initialize accumulated probability (start neutral at 0.5)
        accum_prob = [0.5, 0.5]; 
        
        command_delivered = false;
        
        for i = 1:size(post_probs, 1)
            current_post = post_probs(i, :);
            
            % Update evidence
            accum_prob = accum_alpha * accum_prob + (1 - accum_alpha) * current_post;
            
            % Check Thresholds
            % If probability of Hands > Threshold
            if accum_prob(idx_hands_col) >= accum_threshold
                predicted_trial_class = class_A;
                command_delivered = true;
            % If probability of Feet > Threshold
            elseif accum_prob(idx_feet_col) >= accum_threshold
                predicted_trial_class = class_B;
                command_delivered = true;
            end
            
            % If command delivered, record latency and stop integrating
            if command_delivered
                if predicted_trial_class == true_label
                    trial_results(t) = 1; % Correct
                    
                    % Calculate time in seconds relative to cue
                    % i is samples from cue onset
                    time_sec = i * cfg.spec.wshift; 
                    command_latencies(end+1) = time_sec;
                else
                    trial_results(t) = 0; % Wrong command
                end
                break; % Stop trial simulation
            end
        end
        
        % If trial ends without threshold crossing, it's a "Miss" (0 accuracy)
        if ~command_delivered
             trial_results(t) = 0;
        end
    end
    
    %% Compute Final Metrics
    single_sample_acc = (correct_samples / total_samples) * 100;
    trial_acc = (sum(trial_results) / n_trials) * 100;
    avg_latency = mean(command_latencies);
    
    %% Report Results
    fprintf('-------------------------------------------------\n');
    fprintf('EVALUATION RESULTS (Online Data)\n');
    fprintf('-------------------------------------------------\n');
    fprintf('Single Sample Accuracy:  %.2f%%\n', single_sample_acc);
    fprintf('Trial Accuracy:          %.2f%%\n', trial_acc);
    fprintf('Avg Time to Command:     %.2f s\n', avg_latency);
    fprintf('-------------------------------------------------\n');

    %% Save Results
    results.single_sample_acc = single_sample_acc;
    results.trial_acc = trial_acc;
    results.avg_latency = avg_latency;
    results.latencies = command_latencies;
    results.trial_results = trial_results;
    
    % Save to the same directory as the model
    output_dir = fileparts(model_path);
    save(fullfile(output_dir, 'evaluation_results.mat'), 'results');
end