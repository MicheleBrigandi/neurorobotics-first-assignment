function model = train_classifier(activity_path, fisher_path, output_model_path, cfg)
% TRAIN_CLASSIFIER Trains an LDA classifier and evaluates training performance.
%
% This function loads the Activity data, selects features based on Fisher Score,
% trains an LDA model, and generates performance reports.
% It calculates two metrics:
%   1. Single Sample Accuracy
%   2. Offline Trial Accuracy
%
% INPUTS:
%   activity_path     - Path to file containing 'Activity' matrix.
%   fisher_path       - Path to file containing Fisher Scores.
%   output_model_path - Path where the trained model will be saved.
%   cfg               - Config struct.
%
% OUTPUT:
%   model - Trained ClassificationDiscriminant object.

    %% Input Validation
    if nargin < 4
        error('[train_classifier] Not enough input arguments.');
    end
    
    if ~exist(activity_path, 'file') || ~exist(fisher_path, 'file')
        error('[train_classifier] Input files missing. Run feature selection first.');
    end

    % Load data
    data_act = load(activity_path);
    data_fish = load(fisher_path);
    
    Activity = data_act.Activity;            
    labels   = data_act.all_trials_labels;
    onsets   = data_act.all_cue_onsets;
    
    best_features_idx = data_fish.best_features_idx;

    %% Data Preparation
    fprintf('[train_classifier] Preparing Single Sample dataset...\n');
    
    [~, n_freq, n_chan, n_trials] = size(Activity);
    n_features_total = n_freq * n_chan;
    
    % Store trials individually for the simulation step later
    X_list = cell(n_trials, 1);
    
    for t = 1:n_trials
        t_start = onsets(t);
        trial_data = Activity(t_start:end, :, :, t);
        trial_flat = reshape(trial_data, size(trial_data, 1), n_features_total);
        
        valid_rows = ~any(isnan(trial_flat), 2);
        X_list{t} = trial_flat(valid_rows, :);
    end
    
    % Concatenate for model training
    X_full = vertcat(X_list{:});
    
    % Create label vector
    y_list = cell(n_trials, 1);
    for t = 1:n_trials
        y_list{t} = repmat(labels(t), size(X_list{t}, 1), 1);
    end
    y_full = vertcat(y_list{:});

    %% Feature Selection
    if isfield(cfg, 'train') && isfield(cfg.train, 'n_features')
        n_feat = cfg.train.n_features;
    else
        n_feat = 10;
    end
    
    selected_idx = best_features_idx(1:min(n_feat, length(best_features_idx)));
    X_train = X_full(:, selected_idx);
    y_train = y_full;
    
    fprintf('[train_classifier] Training set: %d samples, %d features.\n', size(X_train, 1), length(selected_idx));

    %% Model Training (LDA)
    t_start = tic;
    
    model = fitcdiscr(X_train, y_train, 'DiscrimType', 'linear');
    
    fprintf('[train_classifier] Training completed in %.2f seconds.\n', toc(t_start));

    %% 1. Single Sample Accuracy
    pred = predict(model, X_train);
    
    classes = [cfg.codes.hands, cfg.codes.feet];
    class_names = {'Hands', 'Feet'};
    
    C = confusionmat(y_train, pred, 'Order', classes);
    
    acc_hands   = C(1,1) / sum(C(1,:)) * 100;
    acc_feet    = C(2,2) / sum(C(2,:)) * 100;
    acc_overall = sum(diag(C)) / sum(C(:)) * 100;
    
    fprintf('[train_classifier] Single Sample Accuracy: Overall=%.2f%% | Hands=%.2f%% | Feet=%.2f%%\n', ...
            acc_overall, acc_hands, acc_feet);

    %% 2. Offline Trial Accuracy
    alpha = 0.95;       
    threshold = 0.70;   
    
    trial_results = zeros(n_trials, 1);
    
    % Find column indices for probability scores
    idx_A = find(model.ClassNames == cfg.codes.hands);
    idx_B = find(model.ClassNames == cfg.codes.feet);
    
    for t = 1:n_trials
        % Get samples for this trial using selected features
        X_trial = X_list{t}(:, selected_idx);
        y_true = labels(t);
        
        % Get posterior probabilities
        [~, scores] = predict(model, X_trial);
        
        % Accumulation loop
        accum_prob = [0.5, 0.5]; 
        command_sent = false;
        pred_trial = NaN;
        
        for i = 1:size(scores, 1)
            curr_prob = scores(i, :);
            accum_prob = alpha * accum_prob + (1 - alpha) * curr_prob;
            
            if accum_prob(idx_A) >= threshold
                pred_trial = cfg.codes.hands;
                command_sent = true;
            elseif accum_prob(idx_B) >= threshold
                pred_trial = cfg.codes.feet;
                command_sent = true;
            end
            
            if command_sent, break; end
        end
        
        % Check success
        if command_sent && pred_trial == y_true
            trial_results(t) = 1;
        end
    end
    
    acc_trial = (sum(trial_results) / n_trials) * 100;
    fprintf('[train_classifier] Offline Trial Accuracy: %.2f%%\n', acc_trial);

    %% Visualisation & Saving
    output_dir = fileparts(output_model_path);
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    % 1. Bar Plot
    fig_bar = figure('Name', 'Training Accuracy', 'Color', 'w', 'Visible', 'off');
    bar([acc_overall, acc_hands, acc_feet], 'FaceColor', [0.2 0.6 0.8]);
    set(gca, 'XTickLabel', {'Overall', 'Hands', 'Feet'});
    ylabel('Accuracy (%)');
    title('Training Performance (Offline)');
    grid on; ylim([0 100]);

    ylim([0 115]);
    
    % Add text labels on bars
    text(1:3, [acc_overall, acc_hands, acc_feet], ...
         num2str([acc_overall; acc_hands; acc_feet], '%.1f%%'), ...
         'vert', 'bottom', 'horiz', 'center');
     
    saveas(fig_bar, fullfile(output_dir, 'training_accuracy_bar.png'));
    close(fig_bar);
    
    % 2. Confusion Matrix Plot
    fig_cm = figure('Name', 'Training Confusion Matrix', 'Color', 'w', 'Visible', 'off');
    confusionchart(C, class_names);
    title(sprintf('Confusion Matrix (Training) - Acc: %.1f%%', acc_overall));
    
    saveas(fig_cm, fullfile(output_dir, 'training_confusion_matrix.png'));
    close(fig_cm);

    % Save model
    save(output_model_path, 'model', 'selected_idx', 'acc_overall', 'acc_hands', 'acc_feet', 'acc_trial');
end