function extract_trials(input_dir, output_filepath, cfg)
% EXTRACT_TRIALS Segments full trials (Fixation -> Feedback).
%
% This function extracts the full time window from the start of the Fixation
% Cross to the end of the Continuous Feedback.
%
% INPUTS:
%   input_dir       - Folder containing processed PSD .mat files.
%   output_filepath - Path where the aggregated 'Activity' .mat will be saved.
%   cfg             - Config struct containing event codes.

    %% Input Validation
    if ~exist(input_dir, 'dir')
        error('[extract_trials] Input dir not found: %s\n', input_dir); 
    end
    
    files = dir(fullfile(input_dir, '*.mat'));
    if isempty(files)
        warning('[extract_trials] No files found.\n'); 
        return; 
    end
    
    fprintf('[extract_trials] Extracting trials from %s\n', input_dir);

    %% Accumulators
    all_trials_data = {}; 
    all_trials_labels = [];
    all_cue_onsets = [];
    
    CODE_FIXATION = cfg.codes.fix;
    CODE_HANDS    = cfg.codes.hands;    
    CODE_FEET     = cfg.codes.feet;     
    CODE_FEEDBACK = cfg.codes.feedback; 

    %% Processing Loop
    total_valid_trials = 0;
    
    %% CONCATENATION
    for i = 1:length(files)
        filepath = fullfile(input_dir, files(i).name);
        tmp = load(filepath); 
        
        if ~isfield(tmp, 'PSD') || ~isfield(tmp, 'Events') 
            continue; 
        end
        
        PSD_run = tmp.PSD;
        Evt     = tmp.Events;
        
        % Find cues
        cue_indices = find(Evt.TYP == CODE_HANDS | Evt.TYP == CODE_FEET);
        
        for k = 1:length(cue_indices)
            idx_cue = cue_indices(k);
            
            % Search backward for fixation
            idx_fix = -1;
            % Look back up to 3 events
            for j = 1:3 
                if (idx_cue - j) >= 1 && Evt.TYP(idx_cue - j) == CODE_FIXATION
                    idx_fix = idx_cue - j;
                    break;
                end
            end
            
            % Search forward for feedback
            idx_feed = -1;
            for j = 1:5
                if (idx_cue + j) <= length(Evt.TYP) && Evt.TYP(idx_cue + j) == CODE_FEEDBACK
                    idx_feed = idx_cue + j;
                    break;
                end
            end
            
            % Extract if both found
            if idx_fix ~= -1 && idx_feed ~= -1
                
                % Start of trial
                t_start = Evt.POS(idx_fix);
                
                % End of trial
                t_end = Evt.POS(idx_feed) + Evt.DUR(idx_feed) - 1;
                
                % Cue onset
                rel_cue_start = Evt.POS(idx_feed) - t_start + 1; 
                
                if t_start > 0 && t_end <= size(PSD_run, 1)
                    trial_chunk = PSD_run(t_start:t_end, :, :);
                    
                    all_trials_data{end+1} = trial_chunk; 
                    all_trials_labels(end+1, 1) = Evt.TYP(idx_cue); 
                    all_cue_onsets(end+1, 1) = rel_cue_start;
                    
                    total_valid_trials = total_valid_trials + 1;
                end
            end
        end
    end
    
    if total_valid_trials == 0 
        warning('[extract_trials] No valid trials found.\n'); 
        return; 
    end

    %% Standardization
    % Padding with NaNs to the maximum length found
    max_len = max(cellfun(@(x) size(x, 1), all_trials_data));
    [~, n_freqs, n_chans] = size(all_trials_data{1});
    
    Activity = NaN(max_len, n_freqs, n_chans, total_valid_trials);
    
    for t = 1:total_valid_trials
        chunk = all_trials_data{t};
        len = size(chunk, 1);
        Activity(1:len, :, :, t) = chunk;
    end

    %% Save
    out_dir = fileparts(output_filepath);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir); 
    end
    
    freqs = tmp.freqs; 
    chanlabs = tmp.chanlabs;
    
    save(output_filepath, 'Activity', 'all_trials_labels', 'all_cue_onsets', 'freqs', 'chanlabs', 'cfg');
end