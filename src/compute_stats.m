function stats = compute_stats(prep_out_path, cfg)
% COMPUTE_STATS Calculates statistical metrics (Fisher, ERD, Lateralization).
%
% This function extracts key features for visualization and population analysis.
% Refactored to remove hardcoded channel indices and frequency bands.

    if ~exist(prep_out_path, 'file'), stats = []; 
        return; 
    end
    data = load(prep_out_path);
    
    Activity = data.Activity; 
    labels   = data.all_trials_labels; 
    pre_win  = data.all_cue_onsets(1) - 1;
    freqs    = data.freqs;
    chanlabs = data.chanlabs;
    
    %% 1. Dynamic Parameter Lookup
    % Define standard bands from config (fallback to 8-13 if missing)
    if isfield(cfg, 'bands') && isfield(cfg.bands, 'mu')
        mu_range = cfg.bands.mu;
    else
        mu_range = [8 13];
    end
    
    % Find Channel Indices dynamically (Robust against channel reordering)
    % We need C3 (Hands ROI), Cz (Feet ROI), and C4 (Lateralization)
    idx_c3 = find(strcmpi(chanlabs, 'C3'), 1);
    idx_cz = find(strcmpi(chanlabs, 'Cz'), 1);
    idx_c4 = find(strcmpi(chanlabs, 'C4'), 1);
    
    % Fallback if labels don't match standard names
    if isempty(idx_c3), idx_c3 = 7; end
    if isempty(idx_cz), idx_cz = 9; end
    if isempty(idx_c4), idx_c4 = 11; end

    %% 2. ERD Computation
    % Use omitnan for baseline calculation just in case
    baseline = mean(Activity(1:pre_win, :, :, :), 1, 'omitnan');
    ERD = log(Activity ./ baseline); 
    
    % Slice active phase
    act_phase = ERD(pre_win+1:end, :, :, :);
    
    % Identify Mu band frequency bins
    mu_idx = (freqs >= mu_range(1) & freqs <= mu_range(2));
    
    %% 3. Spatial Patterns (Topoplots)
    % Averaging over time (1) and frequency (2)
    spatial_patterns = squeeze(mean(mean(act_phase(:, mu_idx, :, :), 1, 'omitnan'), 2, 'omitnan')); 
    
    % Hands = 773, Feet = 771
    idx_hands = (labels == cfg.codes.hands);
    idx_feet  = (labels == cfg.codes.feet);
    
    % Averaging over trials
    stats.hands_map = mean(spatial_patterns(:, idx_hands), 2, 'omitnan');
    stats.feet_map  = mean(spatial_patterns(:, idx_feet), 2, 'omitnan');
    
    %% 4. ERD Curves (Time Courses)
    % Averaging over frequency (2) and trials (4)
    % Hands -> C3, Feet -> Cz
    stats.curve_h = squeeze(mean(mean(ERD(:, mu_idx, idx_c3, idx_hands), 2, 'omitnan'), 4, 'omitnan'));
    stats.curve_f = squeeze(mean(mean(ERD(:, mu_idx, idx_cz, idx_feet), 2, 'omitnan'), 4, 'omitnan'));
    stats.t_axis  = (0:size(ERD,1)-1) * cfg.spec.wshift;

    %% 5. Fisher Score
    % Averaging over time (1) with omitnan to get one value per feature
    [n_f, n_c, n_t] = size(squeeze(mean(act_phase, 1, 'omitnan')));
    X = reshape(permute(squeeze(mean(act_phase, 1, 'omitnan')), [3 1 2]), n_t, n_f * n_c);
    
    m1 = mean(X(idx_hands, :), 1, 'omitnan'); 
    m2 = mean(X(idx_feet, :), 1, 'omitnan');
    v1 = var(X(idx_hands, :), 0, 1, 'omitnan'); 
    v2 = var(X(idx_feet, :), 0, 1, 'omitnan');
    
    fs_vector = (m1 - m2).^2 ./ (v1 + v2 + 1e-10);
    
    %% 6. Statistics & Lateralization
    [max_fs, best_idx] = max(fs_vector);
    
    % Fisher Score Stats
    stats.maxFS  = max_fs;  
    stats.meanFS = mean(fs_vector, 'omitnan'); 
    
    % Map best feature back to Freq and Channel
    f_idx = mod(best_idx-1, n_f) + 1;
    c_idx = floor((best_idx-1)/n_f) + 1;
    stats.bestFreq = freqs(f_idx);  
    stats.bestChan = chanlabs{c_idx}; 
    
    % Peak ERD (min value in map)
    avg_erd_map = mean(act_phase, 4, 'omitnan');   
    stats.peakERD = min(avg_erd_map(:));
    
    % Lateralization Index (C3 - C4)
    % Averaging over time (1)
    stats.ERD_C3 = mean(avg_erd_map(:, f_idx, idx_c3), 1, 'omitnan');
    stats.ERD_C4 = mean(avg_erd_map(:, f_idx, idx_c4), 1, 'omitnan');
    stats.LI     = stats.ERD_C3 - stats.ERD_C4;

    %% 7. Package Full Data for Population Analysis
    stats.full_data.fisher_map = reshape(fs_vector, n_f, n_c);
    stats.full_data.freqs = freqs;
    stats.full_data.ERD = ERD; 
    stats.full_data.labels = labels;
    stats.full_data.pre_win = pre_win;
end