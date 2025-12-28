function compute_psd(input_filepath, output_filepath)
% COMPUTE_PSD Computes the Power Spectral Density (PSD) for EEG data.
%
% This function loads concatenated EEG data, applies a spatial Laplacian
% filter, computes the spectrogram using a sliding window approach, and
% extracts the relevant frequency bands. It also realigns the event markers
% to match the new time windows.
%
% INPUTS:
%   input_filepath  - Path to the .mat file containing concatenated raw data
%                     (must contain 'all_data', 'all_TYP', 'all_POS', 'all_DUR').
%   output_filepath - Path where the processed PSD data will be saved.
%
% USAGE:
%   compute_psd(cfg.files.concat_offline, cfg.files.psd_offline);

    %% Configuration
    % Load the central configuration if available.
    if evalin('base', 'exist(''cfg'',''var'')')
        cfg = evalin('base', 'cfg');
    else
        cfg = get_config();
    end
    
    fprintf('Starting PSD computation for: %s\n', input_filepath);

    %% Data Loading
    % Load the concatenated EEG data
    if ~exist(input_filepath, 'file')
        error('Input file not found: %s', input_filepath);
    end
    data_struct = load(input_filepath);
    
    % Extract variables
    if isfield(data_struct, 'all_data')
        raw_data = data_struct.all_data;
        events.TYP = data_struct.all_TYP;
        events.POS = data_struct.all_POS;
        events.DUR = data_struct.all_DUR;
    else
        error('The input file does not contain the required variable "all_data".');
    end

    %% Spatial Filtering (Laplacian)
    % Load the Laplacian mask
    if ~exist(cfg.files.laplacian, 'file')
        error('Laplacian filter file not found at: %s', cfg.files.laplacian);
    end
    load(cfg.files.laplacian, 'lap');
    
    % Select only the first 16 channels
    % Ensure data dimensions match the filter
    n_channels = size(lap, 1);
    s_raw = raw_data(:, 1:n_channels);
    
    % Apply the spatial filter
    fprintf('Applying Laplacian spatial filter...\n');
    s_lap = s_raw * lap;

    %% Spectrogram Computation
    % Compute the spectrogram using the parameters from get_config
    fprintf('Computing spectrogram (Window: %.2fs, Step: %.4fs)...\n', ...
            cfg.spec.wlength, cfg.spec.wshift);
            
    % Note: proc_spectrogram is an external function provided in the repo
    [PSD_full, f_full] = proc_spectrogram(s_lap, ...
                                          cfg.spec.wlength, ...
                                          cfg.spec.wshift, ...
                                          cfg.spec.pshift, ...
                                          cfg.fs, ...
                                          cfg.spec.mlength);

    %% Feature Selection
    % Select only the frequencies within the band of interest
    freq_min = cfg.spec.freq_band(1);
    freq_max = cfg.spec.freq_band(2);
    
    % Find indices corresponding to the desired range.
    freq_idx = find(f_full >= freq_min & f_full <= freq_max);
    
    if isempty(freq_idx)
        warning('No frequencies found in the range [%d, %d] Hz.', freq_min, freq_max);
    end
    
    % Extract the subset of the PSD matrix
    PSD_selected = PSD_full(:, freq_idx, :);
    f_selected = f_full(freq_idx);
    
    fprintf('Selected %d frequency bins between %d Hz and %d Hz.\n', ...
            length(f_selected), freq_min, freq_max);

    %% Event Realignment
    % The spectrogram reduces the temporal resolution. We must convert event
    % positions (in samples) to window indices
    fprintf('Realigning events to windowed time frame...\n');
    
    win_conv_direction = 'backward';
    win_scale = cfg.spec.wshift * cfg.fs;   % Window shift in samples
    win_len = cfg.spec.wlength * cfg.fs;    % Window length in samples
    
    % Convert POS and DUR using the provided helper function
    POS_win = proc_pos2win(events.POS, win_scale, win_conv_direction, win_len);
    DUR_win = proc_pos2win(events.DUR, win_scale, win_conv_direction, win_len);
    
    % Update the event structure
    events_win.TYP = events.TYP;
    events_win.POS = POS_win;
    events_win.DUR = DUR_win;

    %% Saving Results
    % Create output directory if needed
    output_dir = fileparts(output_filepath);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Save all necessary variables
    save(output_filepath, 'PSD_selected', 'f_selected', 'events_win', 'cfg');
    
    fprintf('Processed PSD data saved to %s\n', output_filepath);
end

