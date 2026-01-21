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
    % Use omitnan for baseline calculation just in case
    baseline = mean(Activity(1:pre_win, :, :, :), 1, 'omitnan');
    ERD = log(Activity ./ baseline); 
    
    % features
    act_phase = ERD(pre_win+1:end, :, :, :);
    mu_idx = (freqs >= 8 & freqs <= 13);
    
    % Averaging over time (1) and frequency (2)
    spatial_patterns = squeeze(mean(mean(act_phase(:, mu_idx, :, :), 1, 'omitnan'), 2, 'omitnan')); 
    
    % Hands =773, Feet =771
    idx_hands = (labels == 773);
    idx_feet  = (labels == 771);
    
    % Averaging over trials
    stats.hands_map = mean(spatial_patterns(:, idx_hands), 2, 'omitnan');
    stats.feet_map  = mean(spatial_patterns(:, idx_feet), 2, 'omitnan');
    
    % Curve
    % Averaging over frequency (2) and trials (4)
    stats.curve_h = squeeze(mean(mean(ERD(:, mu_idx, 7, idx_hands), 2, 'omitnan'), 4, 'omitnan'));
    stats.curve_f = squeeze(mean(mean(ERD(:, mu_idx, 9, idx_feet), 2, 'omitnan'), 4, 'omitnan'));
    stats.t_axis  = (0:size(ERD,1)-1) * cfg.spec.wshift;

    % Fisher Score
    % Averaging over time (1) with omitnan
    [n_f, n_c, n_t] = size(squeeze(mean(act_phase, 1, 'omitnan')));
    X = reshape(permute(squeeze(mean(act_phase, 1, 'omitnan')), [3 1 2]), n_t, n_f * n_c);
    
    m1 = mean(X(idx_hands, :), 1, 'omitnan'); 
    m2 = mean(X(idx_feet, :), 1, 'omitnan');
    v1 = var(X(idx_hands, :), 0, 1, 'omitnan'); 
    v2 = var(X(idx_feet, :), 0, 1, 'omitnan');
    
    fs_vector = (m1 - m2).^2 ./ (v1 + v2 + 1e-10);
    
    %Stats
    [max_fs, best_idx] = max(fs_vector);
    
       %Fisher Score
    stats.maxFS  = max_fs;  
    stats.meanFS = mean(fs_vector, 'omitnan'); 
    
    % Freq and Channel
    f_idx = mod(best_idx-1, n_f) + 1;
    c_idx = floor((best_idx-1)/n_f) + 1;
    stats.bestFreq = freqs(f_idx);  
    stats.bestChan = data.chanlabs{c_idx}; 
    
    % ERD
    % Averaging over trials (4)
    avg_erd_map = mean(act_phase, 4, 'omitnan');   
    stats.peakERD = min(avg_erd_map(:));
    
    % Lateralization
    % Averaging over time (1)
    stats.ERD_C3 = mean(avg_erd_map(:, f_idx, 7), 1, 'omitnan');
    stats.ERD_C4 = mean(avg_erd_map(:, f_idx, 11), 1, 'omitnan');
    stats.LI     = stats.ERD_C3 - stats.ERD_C4;

    %Save
    stats.full_data.fisher_map = reshape(fs_vector, n_f, n_c);
    stats.full_data.freqs = freqs;
    stats.full_data.ERD = ERD; 
    stats.full_data.labels = labels;
    stats.full_data.pre_win = pre_win;
end