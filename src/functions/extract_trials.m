function extract_trials(input_filepath, output_filepath)
% EXTRACT_TRIALS Segments the continuous PSD data into task-specific trials.
%
% This function loads the continuous Power Spectral Density data and extracts
% specific time windows corresponding to the Motor Imagery tasks.
%
% INPUTS:
%   input_filepath  - Path to the .mat file containing continuous PSD data.
%   output_filepath - Path where the segmented 'Activity' matrix will be saved.
%
% USAGE:
%   extract_trials(cfg.files.psd_offline, cfg.files.activity_offline);

    %% Configuration
    % Load the central configuration if available
    if evalin('base', 'exist(''cfg'',''var'')')
        cfg = evalin('base', 'cfg');
    else
        cfg = get_config();
    end

    fprintf('Extracting trials from: %s\n', input_filepath);

    %% Data Loading
    if ~exist(input_filepath, 'file')
        error('Input file not found: %s', input_filepath);
    end
    
    % Load data into a structure to keep the workspace clean
    data_in = load(input_filepath);
    
    % Unpack variables using the standard names
    if isfield(data_in, 'PSD_selected')
        all_PSD = data_in.PSD_selected;
    else
        error('Variable "PSD_selected" missing in input file.');
    end
    
    if isfield(data_in, 'events_win')
        PSD_TYP = data_in.events_win.TYP;
        PSD_POS = data_in.events_win.POS;
        PSD_DUR = data_in.events_win.DUR;
    else
        error('Structure "events_win" missing in input file.');
    end
    
    % Get event codes from config
    CODE_HANDS = cfg.codes.hands;    
    CODE_FEET = cfg.codes.feet;     
    CODE_FEEDBACK = cfg.codes.feedback; 

    %% Trial Identification
    % We identify the Cue (Hands/Feet) and then extract the data 
    % from the subsequent Continuous Feedback phase
    
    % Find indices of all Cue events
    cue_indices = find(PSD_TYP == CODE_HANDS | PSD_TYP == CODE_FEET);
    num_potential_trials = length(cue_indices);
    
    % Initialise temporary storage
    % We use a cell array because trial durations might vary slightly
    mi_class_events = zeros(num_potential_trials, 1);
    trial_data_list = cell(num_potential_trials, 1);
    
    max_len = 0; % Track maximum trial length for matrix pre-allocation
    valid_trials_count = 0;

    %% Extraction Loop
    for i = 1:num_potential_trials
        idx_cue = cue_indices(i);
        
        % Search for the Feedback event immediately following the Cue
        % We look ahead a few events (e.g., 5) to be robust against artefacts
        idx_feedback = -1;
        search_window = 5; 
        
        for k = 1:search_window
            current_idx = idx_cue + k;
            if current_idx <= length(PSD_TYP) && PSD_TYP(current_idx) == CODE_FEEDBACK
                idx_feedback = current_idx;
                break;
            end
        end
        
        % If a valid feedback event is found, proceed with extraction
        if idx_feedback ~= -1
            valid_trials_count = valid_trials_count + 1;
            
            % Save the class label
            mi_class_events(valid_trials_count) = PSD_TYP(idx_cue);
            
            % Extract data
            start_pos = PSD_POS(idx_feedback);
            duration = PSD_DUR(idx_feedback);
            end_pos = start_pos + duration - 1;
            
            % Boundary check to prevent indexing errors
            if end_pos <= size(all_PSD, 1)
                trial_sample = all_PSD(start_pos:end_pos, :, :);
                trial_data_list{valid_trials_count} = trial_sample;
                
                % Update max length found so far
                if size(trial_sample, 1) > max_len
                    max_len = size(trial_sample, 1);
                end
            else
                warning('Trial %d truncated: End position exceeds data limits.', i);
            end
        end
    end

    % Resize arrays to keep only valid trials
    mi_class_events = mi_class_events(1:valid_trials_count);
    num_trials = valid_trials_count;

    %% Formatting Output Matrix
    % Create the 4D Activity Matrix: [Samples x Freq x Chan x Trials]
    [~, num_freq, num_chan] = size(all_PSD);
    Activity = NaN(max_len, num_freq, num_chan, num_trials);

    for i = 1:num_trials
        curr_data = trial_data_list{i};
        len = size(curr_data, 1);
        Activity(1:len, :, :, i) = curr_data;
    end

    %% Saving Results
    % Create output directory if needed
    output_dir = fileparts(output_filepath);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Save the structured data and the labels
    save(output_filepath, 'Activity', 'mi_class_events', 'cfg');
    
    fprintf('Extracted %d valid trials. Saved to %s\n', num_trials, output_filepath);
end
