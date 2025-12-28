function select_features(input_filepath, output_filepath)
% SELECT_FEATURES Computes Fisher Score to select the most discriminative features.
%
% This function loads the segmented 'Activity' data, flattens the temporal
% dimension (averaging over time), and calculates the Fisher Score for each
% Frequency-Channel pair. It then selects the top K features defined in the
% configuration.
%
% INPUTS:
%   input_filepath  - Path to the .mat file containing 'Activity' and labels.
%   output_filepath - Path where the ranking and selected indices will be saved.
%
% USAGE:
%   select_features(cfg.files.activity_offline, cfg.files.fisher_results);

    %% Configuration
    if evalin('base', 'exist(''cfg'',''var'')')
        cfg = evalin('base', 'cfg');
    else
        cfg = get_config();
    end

    fprintf('Starting Feature Selection...\n');
    
    if ~exist(input_filepath, 'file')
        error('Input file not found: %s', input_filepath);
    end
    load(input_filepath, 'Activity', 'mi_class_events');

    %% Feature Extraction
    % We average over the time samples to get a single power value per freq/chan.
    
    % Squeeze removes the singleton dimension (Samples) after averaging
    % feat_FC_T: [Freq x Chan x Trials]
    feat_FC_T = squeeze(mean(Activity, 1, 'omitnan')); 
    
    [n_freq, n_chan, n_trials] = size(feat_FC_T);
    n_features = n_freq * n_chan;

    % Flatten (Freq x Chan) into a single feature vector D per trial
    % X: [Trials x (Freq*Chan)]
    X = reshape(permute(feat_FC_T, [3 1 2]), n_trials, n_features);

    %% Compute Fisher Score
    % Get class codes from config
    class_A = cfg.codes.hands;
    class_B = cfg.codes.feet;
    
    fprintf('Calculating Fisher Scores for %d features...\n', n_features);
    scores = calculate_fisher_score(X, mi_class_events, class_A, class_B);

    %% Feature Selection (Top K)
    top_k = cfg.train.n_features;
    
    % Sort scores in descending order
    [sorted_scores, sort_idx] = sort(scores, 'descend');
    
    % Select the indices of the best features
    best_features_idx = sort_idx(1:top_k);
    
    % Map the linear index back to [Frequency, Channel] pairs
    selected_freq_idx = mod(best_features_idx - 1, n_freq) + 1;
    selected_chan_idx = floor((best_features_idx - 1) / n_freq) + 1;

    % Load frequency vector for reference
    if exist(cfg.files.psd_offline, 'file')
        tmp = load(cfg.files.psd_offline, 'f_selected');
        selected_freqs_hz = tmp.f_selected(selected_freq_idx);
    else
        selected_freqs_hz = [];
    end

    %% Visualization
    fisher_map = reshape(scores, n_freq, n_chan);
    
    figure('Name', 'Fisher Score Analysis', 'Color', 'w');
    imagesc(fisher_map');
    colorbar;
    title('Fisher Score Feature Importance');
    xlabel('Frequency Bin Index');
    ylabel('Channel Index');
    axis xy;
    
    fprintf('Visualisation created. High values indicate discriminative features.\n');

    %% Saving Results
    % Create output directory if needed
    output_dir = fileparts(output_filepath);
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    save(output_filepath, ...
         'best_features_idx', ...
         'selected_freq_idx', ...
         'selected_chan_idx', ... 
         'fisher_map', ...  
         'sorted_scores', ...
         'cfg');
     
    fprintf('Mean Score (Top %d): %.4f\n', top_k, mean(sorted_scores(1:top_k)));
    fprintf('Feature selection saved to %s\n', output_filepath);
end

%% Helper Function
function fs = calculate_fisher_score(X, y, classA, classB)
% CALCULATE_FISHER_SCORE Computes the Fisher Score for binary classification.
% Formula: (muA - muB)^2 / (varA + varB)

    % Logical indices for the two classes
    idxA = (y == classA);
    idxB = (y == classB);
    
    % Split data
    XA = X(idxA, :);
    XB = X(idxB, :);
    
    % Compute mean and variance
    muA = mean(XA, 1);
    muB = mean(XB, 1);
    varA = var(XA, 0, 1);
    varB = var(XB, 0, 1);
    
    % Compute score (adding epsilon to avoid division by zero)
    eps0 = 1e-12;
    fs = (muA - muB).^2 ./ (varA + varB + eps0);
end