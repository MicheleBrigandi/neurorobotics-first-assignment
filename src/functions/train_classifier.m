function model = train_classifier(activity_path, fisher_path, output_model_path, cfg)
% TRAIN_CLASSIFIER Trains an LDA classifier.
%
% This function loads the Activity data, slices it to keep only the active
% feedback phase, reshapes it into a Single Sample dataset 
% [Samples x Features], and trains an LDA model.
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

    fprintf('[train_classifier] Loading data from: %s\n', activity_path);
    
    % Check inputs
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
    
    X_list = cell(n_trials, 1);
    y_list = cell(n_trials, 1);
    
    for t = 1:n_trials
        % Slice
        t_start = onsets(t);
        
        % Check for NaNs (padding) at the end of Activity
        trial_data = Activity(t_start:end, :, :, t);
        
        % Flatten spatial-frequency dimensions: [Time x (Freq*Chan)]
        trial_flat = reshape(trial_data, size(trial_data, 1), n_features_total);
        
        % Remove rows that are fully NaN (padding)
        valid_rows = ~any(isnan(trial_flat), 2);
        trial_flat = trial_flat(valid_rows, :);
        
        X_list{t} = trial_flat;
        
        % Create label vector for these samples
        y_list{t} = repmat(labels(t), size(trial_flat, 1), 1);
    end
    
    % Concatenate all samples from all trials
    X_full = vertcat(X_list{:});
    y_full = vertcat(y_list{:});

    %% Feature Selection
    if isfield(cfg, 'train') && isfield(cfg.train, 'n_features')
        n_feat = cfg.train.n_features;
    else
        n_feat = 10;
    end
    
    % Use the indices from Fisher Score
    selected_idx = best_features_idx(1:min(n_feat, length(best_features_idx)));
    
    X_train = X_full(:, selected_idx);
    y_train = y_full;
    
    fprintf('[train_classifier] Training set: %d samples, %d features.\n', size(X_train, 1), length(selected_idx));

    %% Model Training (LDA)
    fprintf('[train_classifier] Training LDA model...\n');
    t_start = tic;
    
    % Train Linear Discriminant Analysis
    model = fitcdiscr(X_train, y_train, 'DiscrimType', 'linear');
    
    fprintf('[train_classifier] Training completed in %.2f seconds.\n', toc(t_start));

    %% Calibration Accuracy
    pred = predict(model, X_train);
    accuracy = sum(pred == y_train) / length(y_train) * 100;
    
    fprintf('[train_classifier] Calibration Accuracy (Single Sample): %.2f%%\n', accuracy);

    %% Saving
    output_dir = fileparts(output_model_path);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir); 
    end
    
    % Save model and selected features
    save(output_model_path, 'model', 'selected_idx', 'accuracy');
    fprintf('[train_classifier] Model saved to: %s\n', output_model_path);
end