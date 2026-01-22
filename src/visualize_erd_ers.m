function visualize_erd_ers(activity_path, output_dir, cfg)
% VISUALIZE_ERD_ERS Generates Time-Frequency ERD/ERS maps.
%
% This function visualises the Event-Related Desynchronisation (ERD) and 
% Synchronisation (ERS) for Motor Imagery tasks. It processes the segmented
% activity data, calculates the logarithmic power relative to the fixation 
% baseline, and produces a comparative plot for channels C3, Cz, and C4.
%
% INPUTS:
%   activity_path - Path to file containing Activity matrix.
%   output_dir    - Directory where the output PNG will be saved.
%   cfg           - Configuration structure containing channel names and codes.

    %% Input Validation
    if ~exist(activity_path, 'file')
        return;
    end
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir); 
    end
    
    % Load processed variables
    data = load(activity_path);
    Activity = data.Activity;            
    labels   = data.all_trials_labels;   
    onsets   = data.all_cue_onsets;     
    freqs    = data.freqs;
    chanlabs = data.chanlabs;            

    %% Channel Identification
    % Identify the indices for the Region of Interest (ROI): C3, Cz, C4.
    
    target_channels = {'C3', 'Cz', 'C4'};
    roi_indices = zeros(1, length(target_channels));
    
    for i = 1:length(target_channels)
        name = target_channels{i};
        idx = [];
        
        % Check against the standard layout in config
        if isfield(cfg, 'channels') && isfield(cfg.channels, 'names')
            idx = find(strcmpi(cfg.channels.names, name), 1);
        end
        
        % Check against the raw file labels
        if isempty(idx)
            idx = find(strcmpi(chanlabs, name), 1);
        end
        
        % Fallback to standard 16-channel montage indices
        if isempty(idx)
            if strcmp(name, 'C3'), idx = 7;  end
            if strcmp(name, 'Cz'), idx = 9;  end
            if strcmp(name, 'C4'), idx = 11; end
            warning('[visualize_erd_ers] Channel %s not found. Using fallback index %d.', name, idx);
        end
        
        roi_indices(i) = idx;
    end

    %% Reference Computation
    % The reference period is defined as the fixation interval preceding the cue.
    % We use the median duration of the pre-cue period across all trials.
    
    ref_len = floor(median(onsets));
    
    % Ensure reference length is within valid bounds
    if ref_len < 1, ref_len = 1; end
    if ref_len > size(Activity, 1), ref_len = size(Activity, 1); end
    
    % Extract the reference activity
    Reference = Activity(1:ref_len, :, :, :);

    %% ERD/ERS Calculation
    % Compute the mean power during the reference period (averaged over time)
    mean_ref = mean(Reference, 1, 'omitnan');
    
    % Calculate the Log-Ratio: log(Activity / Reference)
    ERD_ERS = log(Activity ./ mean_ref);

    %% Visualisation
    % Configure the time axis for plotting
    n_samples = size(Activity, 1);
    time_axis = (0:n_samples-1) * cfg.spec.wshift;
    
    % Define classes for comparison
    classes = [cfg.codes.hands, cfg.codes.feet];
    class_names = {'Hands', 'Feet'};
    
    % Initialise figure for batch processing
    fig = figure('Name', 'ERD Analysis', 'Color', 'w', ...
                 'Visible', 'off', 'Position', [0, 0, 1200, 800]);
    set(gcf, 'Renderer', 'painters');
    
    clim_range = [-0.6 0.6];
    
    % Nested loop: Iterate through Classes (Rows) and Channels (Columns)
    for r = 1:length(classes)
        curr_code = classes(r);
        curr_name = class_names{r};
        
        for c = 1:length(target_channels)
            chan_idx = roi_indices(c);
            chan_name = target_channels{c};
            
            % Average the ERD/ERS map across all trials for the current class
            class_map = mean(ERD_ERS(:, :, chan_idx, labels == curr_code), 4, 'omitnan');
            
            % Select subplot position
            subplot(2, 3, (r-1)*3 + c);
            
            % Plot the Time-Frequency map
            imagesc(time_axis, freqs, class_map');
            
            % Formatting
            set(gca, 'YDir', 'normal');
            title(sprintf('%s - %s', curr_name, chan_name));
            xline(time_axis(ref_len), 'k--', 'LineWidth', 1.5);
            
            colorbar;
            clim(clim_range);
            
            if r == 2, xlabel('Time [s]'); end
            if c == 1, ylabel('Frequency [Hz]'); end
        end
    end
    
    sgtitle('ERD/ERS Analysis');

    %% Save 
    output_filename = fullfile(output_dir, 'erd_ers_maps.png');
    saveas(fig, output_filename);
    close(fig);
end