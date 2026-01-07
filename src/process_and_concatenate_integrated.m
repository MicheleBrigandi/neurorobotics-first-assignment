function process_and_concatenate_integrated(raw_dir, subj_id, run_type, prep_out_path, cfg)

    files = dir(fullfile(raw_dir, run_type, ['*', run_type, '*.gdf']));

    if isempty(files)
        fprintf('No %s files found in: %s\n', run_type, raw_dir);
        return; 
    end
    
    
    load(cfg.files.laplacian, 'lap');
    
    PSD_concat = []; POS_concat = []; TYP_concat = []; DUR_concat = [];
    fs = cfg.fs;
    
    
    for i = 1:length(files)   
        [s, h] = sload(fullfile(raw_dir, run_type, files(i).name));       
        s_lap = s(:, 1:cfg.n_channels) * lap;        
        %PSD
        [PSD_full, f_full] = proc_spectrogram(s_lap, cfg.spec.wlength, cfg.spec.wshift, ...
                                      cfg.spec.pshift, h.SampleRate, cfg.spec.mlength);
        
        freq_idx = f_full >= cfg.spec.freq_band(1) & f_full <= cfg.spec.freq_band(2);
        PSD = PSD_full(:, freq_idx, :);
        freqs = f_full(freq_idx);

        %proc_pros2win
        wshift_samples = cfg.spec.wshift * h.SampleRate;
        mlength_samples = cfg.spec.mlength * h.SampleRate;
        pos_win = proc_pos2win(h.EVENT.POS, wshift_samples, 'backward', mlength_samples);
        
        %concat
        offset = size(PSD_concat, 1);
        PSD_concat = cat(1, PSD_concat, PSD);
        POS_concat = [POS_concat; pos_win + offset];
        TYP_concat = [TYP_concat; h.EVENT.TYP];
        DUR_concat = [DUR_concat; ceil(h.EVENT.DUR / wshift_samples)];
        
        if i == 1, 
            chanlabs = h.Label(1:cfg.n_channels); 
        end
    end
    
    % Extract Trial
    wshift = cfg.spec.wshift;
    pre_win  = round(1.0 / wshift); 
    post_win = round(4.0 / wshift);
    trial_len = pre_win + post_win;
    
    %CUE
    cue_mask = ismember(TYP_concat, [cfg.codes.hands, cfg.codes.feet]);
    cue_indices = find(cue_mask);
    num_trials = length(cue_indices);
    
    % 4D Activity
    Activity = zeros(trial_len, length(freqs), cfg.n_channels, num_trials);
    all_trials_labels = TYP_concat(cue_indices);
    all_cue_onsets = repmat(pre_win + 1, num_trials, 1); 
    
    for t = 1:num_trials
        t_start = POS_concat(cue_indices(t)) - pre_win;
        t_end   = t_start + trial_len - 1;
        
        % check
        if t_start > 0 && t_end <= size(PSD_concat, 1)
            Activity(:, :, :, t) = PSD_concat(t_start:t_end, :, :);
        end
    end
    
    %Save
    out_dir = fileparts(prep_out_path);
    if ~exist(out_dir, 'dir'), 
        mkdir(out_dir); 
    end
    
    save(prep_out_path, 'Activity', 'all_trials_labels', 'all_cue_onsets', ...
         'freqs', 'chanlabs', 'cfg', '-v7.3');
end