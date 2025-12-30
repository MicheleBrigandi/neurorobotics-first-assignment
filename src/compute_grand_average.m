function compute_grand_average(input_dir, output_dir, target_filename, cfg)
% COMPUTE_GRAND_AVERAGE Performs population-level ERD/ERS analysis.
%
% This function aggregates processed data from all subjects found in the
% input directory to compute a robust Grand Average (GA). It aligns 
% individual trials based on cue onsets and visualises the mean population 
% response.
%
% INPUTS:
%   input_dir       - Directory containing processed subject folders.
%   output_dir      - Directory where the output plot will be saved.
%   target_filename - Name of file to load (e.g., 'activity_offline.mat').
%   cfg             - Configuration struct containing parameters.
%
% USAGE:
%   compute_grand_average(cfg.paths.data_processed, cfg.paths.results, cfg);

    %% Input Validation
    if nargin < 3
        error('[compute_grand_average] Error: Not enough input arguments.');
    end

    if ~exist(input_dir, 'dir')
        error('[compute_grand_average] Input directory not found: %s', input_dir);
    end

    %% Subject Discovery
    dir_content = dir(input_dir);
    subject_list = dir_content([dir_content.isdir] & ~startsWith({dir_content.name}, '.'));

    if isempty(subject_list)
        warning('[compute_grand_average] No subjects found in %s.', input_dir);
        return;
    end

    % Accumulators
    grand_avg_hands = [];
    grand_avg_feet  = [];
    time_axis = [];
    freq_axis = [];
    
    mean_cue_index = 0;
    n_subjects_processed = 0;

    %% Aggregation Loop
    fprintf('[compute_grand_average] Aggregating data from %d subjects (Target: %s)...\n', ...
            length(subject_list), target_filename);

    for i = 1:length(subject_list)
        subject_id = subject_list(i).name;
        file_path  = fullfile(input_dir, subject_id, target_filename);

        if ~exist(file_path, 'file') 
            warning('[compute_grand_average] File %s doesn''t exist for subject %s. Skipping.', ...
                    target_filename, subject_id)
            continue; 
        end

        % Load data
        data = load(file_path);
        
        % Validate required fields
        if ~isfield(data, 'Activity')
            warning('[compute_grand_average] Subject %s missing Activity data. Skipping.', subject_id);
            continue; 
        end

        activity_data = data.Activity;            
        trial_labels = data.all_trials_labels;
        cue_onsets = data.all_cue_onsets;
        chanlabs = data.chanlabs;
        
        if isempty(freq_axis)
            freq_axis = data.freqs; 
        end

        % Find indices for the requested channels using cfg
        target_channels = {'C3', 'Cz', 'C4'};
        roi_indices = resolve_channel_indices(chanlabs, target_channels, cfg);
        
        % Skip if crucial channels are missing
        if any(roi_indices == 0)
            warning('[compute_grand_average] Subject %s missing required ROI channels. Skipping.', ...
                    subject_id);
            continue;
        end

        % Compute individual ERD
        % Baseline
        ref_samples = floor(median(cue_onsets));
        ref_samples = max(1, min(ref_samples, size(activity_data, 1)));
        
        reference_block = activity_data(1:ref_samples, :, :, :);
        mean_baseline = mean(reference_block, 1, 'omitnan');
        
        % Log-Ratio ERD calculation
        erd_log = log(activity_data ./ mean_baseline);

        % Average per class (Hands vs Feet)
        mean_hands = mean(erd_log(:, :, roi_indices, trial_labels == cfg.codes.hands), 4, 'omitnan');
        mean_feet = mean(erd_log(:, :, roi_indices, trial_labels == cfg.codes.feet),  4, 'omitnan');

        if any(isnan(mean_hands(:))) || any(isnan(mean_feet(:)))
            continue; 
        end

        % Accumulation and length normalisation
        if n_subjects_processed == 0
            % Initialize accumulators
            grand_avg_hands = mean_hands;
            grand_avg_feet = mean_feet;
            
            n_samples = size(mean_hands, 1);
            time_axis = (0:n_samples-1) * cfg.spec.wshift;
            mean_cue_index = ref_samples;
        else
            % Handle varying trial lengths: crop to minimum common length
            current_len = size(grand_avg_hands, 1);
            new_len = size(mean_hands, 1);
            common_len = min(current_len, new_len);
            
            % Crop accumulators
            grand_avg_hands = grand_avg_hands(1:common_len, :, :);
            grand_avg_feet  = grand_avg_feet(1:common_len, :, :);
            time_axis = time_axis(1:common_len);
            
            % Add new subject
            grand_avg_hands = grand_avg_hands + mean_hands(1:common_len, :, :);
            grand_avg_feet = grand_avg_feet + mean_feet(1:common_len, :, :);
        end

        n_subjects_processed = n_subjects_processed + 1;
        fprintf('[compute_grand_average] Included: %s\n', subject_id);
    end

    %% Final Averaging and Saving
    if n_subjects_processed == 0
        warning('[compute_grand_average] No valid data processed.');
        return;
    end

    % Arithmetic mean
    grand_avg_hands = grand_avg_hands / n_subjects_processed;
    grand_avg_feet = grand_avg_feet / n_subjects_processed;

    fprintf('[compute_grand_average] Grand Average computed across %d subjects.\n', n_subjects_processed);

    % Generate and save plot
    save_grand_average_plot(grand_avg_hands, grand_avg_feet, ...
                            time_axis, freq_axis, mean_cue_index, ...
                            target_channels, output_dir);
end


%% HELPER FUNCTIONS

function indices = resolve_channel_indices(channels, targets, cfg)
% RESOLVE_CHANNEL_INDICES Maps anatomical names to indices in the data file.

    indices = zeros(1, length(targets));
    
    for k = 1:length(targets)
        target_name = targets{k};
        idx = [];

        % Check against the standard layout in config
        if isfield(cfg, 'channels') && isfield(cfg.channels, 'names')
            idx = find(strcmpi(cfg.channels.names, target_name), 1);
        end
        
        % Check against the raw file labels
        if isempty(idx)
            idx = find(strcmpi(channels, name), 1);
        end
        
        % Fallback to standard 16-channel montage indices
        if isempty(idx)
            if strcmp(name, 'C3'), idx = 7;  end
            if strcmp(name, 'Cz'), idx = 9;  end
            if strcmp(name, 'C4'), idx = 11; end
            warning('[compute_grand_average] Channel %s not found. Using fallback index %d.', name, idx);
        end
        
        indices(k) = idx;
    end
end

function save_grand_average_plot(data_hands, data_feet, t, f, cue_idx, ch_names, out_dir)
% SAVE_GRAND_AVERAGE_PLOT Creates the 2x3 grid visualisation and saves to disk.

    fig = figure('Name', 'Grand Average', 'Color', 'w', ...
                 'Visible', 'off', 'Position', [0, 0, 1200, 800]);
    set(gcf, 'Renderer', 'painters');

    row_data = {data_hands, data_feet};
    row_titles = {'Hands', 'Feet'};
    
    % Loop: Rows (Classes) x Columns (Channels)
    for r = 1:2
        for c = 1:length(ch_names)
            subplot_idx = (r - 1) * length(ch_names) + c;
            subplot(2, length(ch_names), subplot_idx);
            
            % Extract map for current channel
            chan_map = row_data{r}(:, :, c);
            
            imagesc(t, f, chan_map');
            set(gca, 'YDir', 'normal');
            
            % Decorations
            title(sprintf('%s - %s', row_titles{r}, ch_names{c}), 'FontWeight', 'bold');
            
            if cue_idx <= length(t)
                xline(t(cue_idx), 'k--', 'LineWidth', 1.5);
            end
            
            colorbar; 
            clim([-0.5 0.5]);
            
            if r == 2, xlabel('Time [s]'); end
            if c == 1, ylabel('Frequency [Hz]'); end
        end
    end
    
    sgtitle('Grand Average Analysis');
    
    % Ensure output directory exists
    if ~exist(out_dir, 'dir')
        mkdir(out_dir); 
    end
    
    filename = fullfile(out_dir, 'grand_average_maps.png');
    saveas(fig, filename);
    close(fig);
    
    fprintf('[compute_grand_average] Grand Average plot saved to: %s\n', filename);
end