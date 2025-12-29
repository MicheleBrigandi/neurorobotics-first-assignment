function select_features(input_filepath, output_filepath, cfg)
% SELECT_FEATURES Computes Fisher Score to select discriminative features.
%
% This function loads the 'Activity' data, slices it to keep only the 
% active phase (from Cue onset), computes the Fisher Score between the two 
% classes defined in cfg, and selects the top-K features.
%
% INPUTS:
%   input_filepath  - Path to the .mat file.
%   output_filepath - Path where results will be saved.
%   cfg             - Configuration struct (containing .codes and .train).
%
% USAGE:
%   select_features(path_in, path_out, cfg);

    %% Input Validation
    if nargin < 3
        error('[select_features] Error: Not enough input arguments.');
    end
    
    if ~exist(input_filepath, 'file')
        error('[select_features] Input file not found: %s', input_filepath);
    end
    
    % Extract parameters from config
    try
        class_A = cfg.codes.hands;
        class_B = cfg.codes.feet;
        
        if isfield(cfg, 'train') && isfield(cfg.train, 'n_features')
            n_features = cfg.train.n_features;
        else
            n_features = 10;
            warning('[select_features] cfg.train.n_features not found. Using default: 10');
        end
    catch
        error('[select_features] Invalid cfg structure. Ensure .codes.hands and .codes.feet exist.');
    end

    fprintf('[select_features] Loading: %s\n', input_filepath);
    
    % Load data
    data_in = load(input_filepath);
    
    % Check for required variables
    required_vars = {'Activity', 'all_trials_labels', 'all_cue_onsets', 'freqs', 'chanlabs'};
    for v = 1:length(required_vars)
        if ~isfield(data_in, required_vars{v})
            error('[select_features] Missing variable "%s" in input file.', required_vars{v});
        end
    end
    
    Activity = data_in.Activity;
    labels   = data_in.all_trials_labels;
    onsets   = data_in.all_cue_onsets;
    freqs    = data_in.freqs;
    chanlabs = data_in.chanlabs;

    %% Feature Extraction 
    
    fprintf('[select_features] Extracting active phase and averaging...\n');
    
    [~, n_freq, n_chan, n_trials] = size(Activity);
    
    % Initialize feature matrix: [Trials x Freq x Chan]
    feat_FC_T = zeros(n_freq, n_chan, n_trials);
    
    for t = 1:n_trials
        % Start from cue
        t_start = onsets(t);
        
        % Slice active data
        trial_active = Activity(t_start:end, :, :, t);
        
        % Average over time
        feat_FC_T(:, :, t) = squeeze(mean(trial_active, 1, 'omitnan'));
    end
    
    % Flatten for Fisher calculation: [Trials x (Freq*Chan)]
    n_total_features = n_freq * n_chan;
    X = reshape(permute(feat_FC_T, [3 1 2]), n_trials, n_total_features);

    %% Compute Fisher Score
    fprintf('[select_features] Calculating Fisher Score...\n');
    
    scores = calculate_fisher_score(X, labels, class_A, class_B);
    
    % Handle potential NaNs
    scores(isnan(scores)) = 0;

    %% Select Top-K Features
    [sorted_scores, sort_idx] = sort(scores, 'descend');
    
    % Select indices
    best_features_idx = sort_idx(1:min(n_features, length(scores)));
    
    % Map back to [Frequency, Channel] indices
    selected_freq_idx = mod(best_features_idx - 1, n_freq) + 1;
    selected_chan_idx = floor((best_features_idx - 1) / n_freq) + 1;

    %% Visualization
    fisher_map = reshape(scores, n_freq, n_chan);
    
    figure('Name', 'Fisher Score Analysis', 'Color', 'w', 'NumberTitle', 'off');
    
    % Plot Heatmap (Channels on Y, Frequencies on X)
    imagesc(fisher_map'); 
    colorbar;
    
    % X-Axis: Frequencies
    num_xticks = 10;
    xticks_idx = round(linspace(1, n_freq, num_xticks));
    xticks(xticks_idx);
    xticklabels(arrayfun(@(x) sprintf('%.1f', x), freqs(xticks_idx), 'UniformOutput', false));
    xlabel('Frequency (Hz)');
    
    % Y-Axis: Channels
    if ~isempty(chanlabs)
        yticks(1:n_chan);
        yticklabels(chanlabs);
    else
        ylabel('Channel Index');
    end
    
    title(sprintf('Fisher Score: Class %d vs %d', class_A, class_B));
    axis xy; 
    
    fprintf('[select_features] Visualization created.\n');

    %% Saving Results
    output_dir = fileparts(output_filepath);
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    save(output_filepath, ...
         'best_features_idx', ...
         'selected_freq_idx', ...
         'selected_chan_idx', ... 
         'fisher_map', ...  
         'sorted_scores', ...
         'freqs', ...      
         'chanlabs', ...
         'cfg');
     
    fprintf('[select_features] Top %d features selected. Mean Score: %.4f\n', ...
            length(best_features_idx), mean(sorted_scores(1:length(best_features_idx))));
    fprintf('[select_features] Saved to: %s\n', output_filepath);
end

%% Helper Function
function fs = calculate_fisher_score(X, y, classA, classB)
    % Logical indices
    idxA = (y == classA);
    idxB = (y == classB);
    
    if sum(idxA) == 0 || sum(idxB) == 0
        warning('[select_features] Missing samples for one class. Returning zeros.');
        fs = zeros(1, size(X, 2));
        return;
    end
    
    % Split data
    XA = X(idxA, :);
    XB = X(idxB, :);
    
    % Fisher formula
    muA = mean(XA, 1);
    muB = mean(XB, 1);
    varA = var(XA, 0, 1);
    varB = var(XB, 0, 1);
    
    eps0 = 1e-12; 
    fs = (muA - muB).^2 ./ (varA + varB + eps0);
end