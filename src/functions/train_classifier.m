function train_classifier(input_activity, input_fisher, output_model)
% TRAIN_CLASSIFIER Trains the LDA model for Single Sample Classification.
%
% This function prepares the training dataset by flattening the temporal
% dimension of the trials (Single Sample approach). It selects the top
% discriminative features based on the Fisher Score and trains a Linear
% Discriminant Analysis (LDA) classifier.
%
% INPUTS:
%   input_activity - Path to the segmented Activity matrix (Offline).
%   input_fisher   - Path to the Fisher Score results (Indices).
%   output_model   - Path where the trained model will be saved.
%
% USAGE:
%   train_classifier(cfg.files.activity_offline, cfg.files.fisher_results, cfg.files.model);

    %% Configuration
    if evalin('base', 'exist(''cfg'',''var'')')
        cfg = evalin('base', 'cfg');
    else
        cfg = get_config();
    end

    fprintf('Starting Classifier Training (LDA)...\n');

    % Check inputs
    if ~exist(input_activity, 'file') || ~exist(input_fisher, 'file')
        error('Input files missing. Run feature selection first.');
    end

    % Load Data
    load(input_activity, 'Activity', 'mi_class_events');
    load(input_fisher, 'best_features_idx');

    %% Data Preparation (Reshaping for Single Sample)
    % Activity structure: [Samples x Freq x Chan x Trials]
    % Target X matrix:    [(Samples*Trials) x (Freq*Chan)]
    % Target y vector:    [(Samples*Trials) x 1]
    
    [n_samples, n_freq, n_chan, n_trials] = size(Activity);
    
    fprintf('Preparing training matrix from %d trials...\n', n_trials);

    % Permute to bring Samples and Trials together in the first dimensions
    % and Features (Freq, Chan) to the end.
    % New order: [Samples, Trials, Freq, Chan]
    Activity_perm = permute(Activity, [1 4 2 3]);
    
    % Reshape into 2D Matrix [Rows, Features]
    % Rows = Samples * Trials
    % Features = Freq * Chan
    n_rows = n_samples * n_trials;
    n_features_total = n_freq * n_chan;
    
    X_full = reshape(Activity_perm, n_rows, n_features_total);
    
    % Create label vector
    y_full = repelem(mi_class_events, n_samples);

    %% Feature Selection
    % Determine how many features to use
    n_features_model = cfg.train.n_features;
    
    % Select the top K indices derived from Fisher Score
    selected_indices = best_features_idx(1:n_features_model);
    
    X_train = X_full(:, selected_indices);
    y_train = y_full;
    
    fprintf('Selected top %d features. Training set size: %d samples.\n', ...
            n_features_model, size(X_train, 1));

    %% Model Training (LDA)
    t_start = tic;
    model = fitcdiscr(X_train, y_train);
    train_time = toc(t_start);
    
    fprintf('Model trained in %.2f seconds.\n', train_time);

    %% Calibration Accuracy
    pred = predict(model, X_train);
    accuracy = sum(pred == y_train) / length(y_train) * 100;
    
    fprintf('Calibration Accuracy: %.2f%%\n', accuracy);

    %% Saving Model
    % Create output directory if needed
    output_dir = fileparts(output_model);
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    % Save the model and the indices needed to preprocess new data
    save(output_model, 'model', 'selected_indices', 'accuracy', 'cfg');
    
    fprintf('Model saved to %s\n', output_model);
end