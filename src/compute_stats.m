function stats = compute_stats(prep_out_path, cfg)
    if ~exist(prep_out_path, 'file'), stats = []; 
        return; 
    end
    data = load(prep_out_path);
    
    Activity = data.Activity; 
    labels   = data.all_trials_labels; 
    pre_win  = data.all_cue_onsets(1) - 1;
    freqs    = data.freqs;
    
    %ERD: using Log
    baseline = mean(Activity(1:pre_win, :, :, :), 1);
    ERD = log(Activity ./ baseline); 
    
    % features
    act_phase = ERD(pre_win+1:end, :, :, :);
    mu_idx = (freqs >= 8 & freqs <= 13);
    spatial_patterns = squeeze(mean(mean(act_phase(:, mu_idx, :, :), 1), 2)); 
    
    % Hands =773, Feet =771
    idx_hands = (labels == 773);
    idx_feet  = (labels == 771);
    stats.hands_map = mean(spatial_patterns(:, idx_hands), 2);
    stats.feet_map  = mean(spatial_patterns(:, idx_feet), 2);
    
    % Curve
    stats.curve_h = squeeze(mean(mean(ERD(:, mu_idx, 7, idx_hands), 2), 4));
    stats.curve_f = squeeze(mean(mean(ERD(:, mu_idx, 9, idx_feet), 2), 4));
    stats.t_axis  = (0:size(ERD,1)-1) * cfg.spec.wshift;

    % Fisher Score
    [n_f, n_c, n_t] = size(squeeze(mean(act_phase, 1)));
    X = reshape(permute(squeeze(mean(act_phase, 1)), [3 1 2]), n_t, n_f * n_c);
    m1 = mean(X(idx_hands, :), 1); m2 = mean(X(idx_feet, :), 1);
    v1 = var(X(idx_hands, :), 0, 1); v2 = var(X(idx_feet, :), 0, 1);
    fs_vector = (m1 - m2).^2 ./ (v1 + v2 + 1e-10);
    
    %Stats
    [max_fs, best_idx] = max(fs_vector);
    
       %Fisher Score
    stats.maxFS  = max_fs;  
    stats.meanFS = mean(fs_vector); 
    
    % Freq and Channel
    f_idx = mod(best_idx-1, n_f) + 1;
    c_idx = floor((best_idx-1)/n_f) + 1;
    stats.bestFreq = freqs(f_idx);  
    stats.bestChan = data.chanlabs{c_idx}; 
    
    % ERD
    avg_erd_map = mean(act_phase, 4);   
    stats.peakERD = min(avg_erd_map(:));
    
    % Lateralization
    stats.ERD_C3 = mean(avg_erd_map(:, f_idx, 7), 1);
    stats.ERD_C4 = mean(avg_erd_map(:, f_idx, 11), 1);
    stats.LI     = stats.ERD_C3 - stats.ERD_C4;

    %Save
    stats.full_data.fisher_map = reshape(fs_vector, n_f, n_c);
    stats.full_data.freqs = freqs;
    stats.full_data.ERD = ERD; 
    stats.full_data.labels = labels;
    stats.full_data.pre_win = pre_win;
end
