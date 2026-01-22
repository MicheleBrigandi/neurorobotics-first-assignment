function test_classifier(activity_path, model_path, cfg)
% TEST_CLASSIFIER Evaluates the trained BCI model on online data.
%
% This function performs the evaluation phase of the BCI pipeline.
% It loads the online 'Activity' data and the pre-trained LDA model.
% It calculates:
%   1. Single Sample Accuracy (Raw classifier performance)
%   2. Trial Accuracy (Using Evidence Accumulation Framework)
%   3. Average Time to Command (Latency)
%   4. Confusion Matrix
%   5. Cohen's Kappa
%
% INPUTS:
%   activity_path - Path to the 'Activity_online.mat' file.
%   model_path    - Path to the 'classifier_model.mat' file.
%   cfg           - Configuration struct.

    %% 1. Input Validation and Loading
    if nargin < 3
        error('[test_classifier] Error: Not enough input arguments.');
    end
    
    if ~exist(activity_path, 'file') || ~exist(model_path, 'file')
        error('[test_classifier] Input files not found.');
    end

    % Load Data
    data_act = load(activity_path);
    Activity = data_act.Activity;            
    labels   = data_act.all_trials_labels;
    onsets   = data_act.all_cue_onsets;
    
    % Load Model
    data_model = load(model_path);
    model = data_model.model;
    selected_idx = data_model.selected_idx;

    fprintf('[test_classifier] Model loaded. Features: %d\n', length(selected_idx));

    %% 2. Parameters for Evidence Accumulation
    % Framework: Exponential Smoothing of Posterior Probabilities
    % P(t) = alpha * P(t-1) + (1-alpha) * P_current
    
    alpha = 0.95;       % Smoothing factor (0 < alpha < 1). High = more stable/slow.
    threshold = 0.70;   % Probability threshold to send a command.
    
    class_A = cfg.codes.hands;
    class_B = cfg.codes.feet;

    %% 3. Evaluation Loop
    
    [~, n_freq, n_chan, n_trials] = size(Activity);
    n_features_total = n_freq * n_chan;
    
    % Accumulators
    ss_correct = 0;
    ss_total = 0;
    
    trial_results = zeros(n_trials, 1); % 1 = Correct, 0 = Incorrect/Timeout
    trial_latencies = [];               % Store time to command
    
    % For Confusion Matrix
    true_labels_list = [];
    pred_labels_list = [];

    fprintf('[test_classifier] Evaluating %d trials...\n', n_trials);

    for t = 1:n_trials
        % --- A. Prepare Data (Same as Training) ---
        t_start = onsets(t);
        
        % Slice active phase (Cue -> End)
        trial_data = Activity(t_start:end, :, :, t);
        
        % Flatten: [Time x Features]
        trial_flat = reshape(trial_data, size(trial_data, 1), n_features_total);
        
        % Remove NaNs (padding)
        valid_rows = ~any(isnan(trial_flat), 2);
        X_trial = trial_flat(valid_rows, :);
        
        % Select features used during calibration
        X_trial = X_trial(:, selected_idx);
        
        y_true = labels(t);
        
        % --- B. Single Sample Evaluation ---
        [pred_ss, scores_ss] = predict(model, X_trial);
        
        ss_correct = ss_correct + sum(pred_ss == y_true);
        ss_total = ss_total + length(pred_ss);
        
        % --- C. Evidence Accumulation (Online Simulation) ---
        accum_prob = [0.5, 0.5]; % Start neutral (assuming 2 classes)
        command_sent = false;
        pred_trial = NaN;
        
        % Identify column indices for classes in 'scores_ss'
        % LDA model stores ClassNames. We need to map scores to class A/B.
        idx_A = find(model.ClassNames == class_A);
        idx_B = find(model.ClassNames == class_B);
        
        for i = 1:size(scores_ss, 1)
            curr_prob = scores_ss(i, :);
            
            % Exponential Smoothing
            accum_prob = alpha * accum_prob + (1 - alpha) * curr_prob;
            
            % Check Threshold
            if accum_prob(idx_A) >= threshold
                pred_trial = class_A;
                command_sent = true;
            elseif accum_prob(idx_B) >= threshold
                pred_trial = class_B;
                command_sent = true;
            end
            
            if command_sent
                % Record Latency
                latency = i * cfg.spec.wshift; % Samples * Seconds/Sample
                trial_latencies(end+1) = latency;
                break; % Stop trial
            end
        end
        
        % --- D. Record Trial Result ---
        true_labels_list = [true_labels_list; y_true];
        
        if command_sent
            pred_labels_list = [pred_labels_list; pred_trial];
            if pred_trial == y_true
                trial_results(t) = 1;
            else
                trial_results(t) = 0;
            end
        else
            % Timeout / No decision
            pred_labels_list = [pred_labels_list; -1]; % -1 indicates Timeout
            trial_results(t) = 0;
        end
    end

    %% 4. Metrics Calculation

    % Accuracy
    acc_ss = (ss_correct / ss_total) * 100;
    acc_trial = (sum(trial_results) / n_trials) * 100;
    avg_latency = mean(trial_latencies);
    
    % Filter out timeouts for Confusion Matrix and Kappa
    valid_idx = pred_labels_list ~= -1;
    y_true_valid = true_labels_list(valid_idx);
    y_pred_valid = pred_labels_list(valid_idx);
    
    % Confusion Matrix
    % Order: Class A, Class B
    if isempty(y_pred_valid)
        C = zeros(2);
    else
        C = confusionmat(y_true_valid, y_pred_valid, 'Order', [class_A, class_B]);
    end
    
    % Cohen's Kappa
    % k = (Po - Pe) / (1 - Pe)
    total_valid = sum(C(:));
    if total_valid > 0
        % Observed Agreement (Po)
        Po = sum(diag(C)) / total_valid;
        
        % Expected Agreement (Pe)
        % Row sums * Col sums / Total^2
        row_sum = sum(C, 2);
        col_sum = sum(C, 1);
        Pe = sum(row_sum .* col_sum') / (total_valid^2);
        
        if Pe == 1
            kappa = 1; % Perfect agreement potential
        else
            kappa = (Po - Pe) / (1 - Pe);
        end
    else
        kappa = 0;
    end

    %% 5. Display and Save
    fprintf('\n=========================================\n');
    fprintf('       EVALUATION RESULTS (Online)       \n');
    fprintf('=========================================\n');
    fprintf('Single Sample Accuracy:   %.2f%%\n', acc_ss);
    fprintf('Trial Accuracy:           %.2f%%\n', acc_trial);
    fprintf('Average Time to Command:  %.2f s\n', avg_latency);
    fprintf('Cohen''s Kappa:            %.4f\n', kappa);
    fprintf('\nConfusion Matrix (Rows=True, Cols=Pred):\n');
    fprintf('\tHands\t\tFeet\n');
    fprintf('Hands\t%d\t\t%d\n', C(1,1), C(1,2));
    fprintf('Feet\t%d\t\t%d\n', C(2,1), C(2,2));
    fprintf('-----------------------------------------\n');
    fprintf('Note: %d trials timed out (undecided).\n', sum(~valid_idx));

    % Save results structure
    results.acc_ss = acc_ss;
    results.acc_trial = acc_trial;
    results.latency = avg_latency;
    results.kappa = kappa;
    results.confusion_matrix = C;
    
    output_dir = fileparts(model_path);
    save(fullfile(output_dir, 'evaluation_results.mat'), 'results');
end