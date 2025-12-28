% =========================================================================
% SCRIPT: VISUALIZE_ERD_ERS
% Purpose: Computes and visualises Event-Related Desynchronisation (ERD)
%          and Synchronisation (ERS) maps.
%
% This script takes the segmented trial data (Activity), computes the
% logarithmic power relative to a baseline reference, and plots the
% Time-Frequency maps for specific channels (C3/C4).
% =========================================================================

%% Configuration
if ~exist('cfg', 'var')
    cfg = get_config();
end

% Define inputs
file_activity = cfg.files.activity_offline;
file_psd = cfg.files.psd_offline;

fprintf('Loading data for ERD/ERS analysis...\n');

% Load Activity Matrix [Samples x Freq x Chan x Trials]
if ~exist(file_activity, 'file'), error('Activity file not found.'); end
load(file_activity, 'Activity', 'mi_class_events');

% Load Frequency Vector
if ~exist(file_psd, 'file'), error('PSD file not found.'); end
load(file_psd, 'f_selected');

%% Parameters & Channels
% Define the channels of interest for Motor Imagery
chan_C3 = 7; 
chan_C4 = 11;

% Define class codes
CODE_HANDS = cfg.codes.hands;
CODE_FEET = cfg.codes.feet;

%% Compute Reference
ref_seconds = 1.0; % Duration of the baseline window in seconds
ref_samples = round(ref_seconds / cfg.spec.wshift);

fprintf('Computing Reference (first %.1fs of each trial)...\n', ref_seconds);

% Extract the baseline portion from the Activity matrix
max_avail_samples = size(Activity, 1);
ref_len = min(ref_samples, max_avail_samples);

Reference = Activity(1:ref_len, :, :, :);

% Compute Mean Reference Power across the time axis (for each freq/chan/trial)
mean_ref = mean(Reference, 1, 'omitnan');

%% Compute ERD/ERS
fprintf('Computing ERD/ERS maps...\n');

% Replicate mean_ref to match the size of Activity for element-wise division
ERD_ERS = log(Activity ./ mean_ref);

%% Average Across Trials
fprintf('Averaging trials by class...\n');

% Filter by hands 
idx_hands = (mi_class_events == CODE_HANDS);
map_C3_hands = mean(ERD_ERS(:, :, chan_C3, idx_hands), 4, 'omitnan');
map_C4_hands = mean(ERD_ERS(:, :, chan_C4, idx_hands), 4, 'omitnan');

% Filter by feet
idx_feet = (mi_class_events == CODE_FEET);
map_C3_feet = mean(ERD_ERS(:, :, chan_C3, idx_feet), 4, 'omitnan');
map_C4_feet = mean(ERD_ERS(:, :, chan_C4, idx_feet), 4, 'omitnan');

%% Visualisation
fprintf('Generating plots...\n');

% Create time axis
[n_time, n_freq, ~, ~] = size(Activity);
time_axis = (0:n_time-1) * cfg.spec.wshift;

figure('Name', 'ERD/ERS Analysis', 'Color', 'w', 'Position', [100, 100, 1000, 800]);

% Determine common color limits for comparison
all_vals = [map_C3_hands(:); map_C4_hands(:); map_C3_feet(:); map_C4_feet(:)];
clim_range = [prctile(all_vals, 5), prctile(all_vals, 95)];

% Plot row 1
subplot(2, 2, 1);
imagesc(time_axis, f_selected, map_C3_hands');
title(['Class ' num2str(CODE_HANDS) ' - Channel C3']);
xlabel('Time [s]'); ylabel('Freq [Hz]');
set(gca, 'YDir', 'normal', 'CLim', clim_range);
colorbar;

subplot(2, 2, 2);
imagesc(time_axis, f_selected, map_C4_hands');
title(['Class ' num2str(CODE_HANDS) ' - Channel C4']);
xlabel('Time [s]'); ylabel('Freq [Hz]');
set(gca, 'YDir', 'normal', 'CLim', clim_range);
colorbar;

% Plot row 2
subplot(2, 2, 3);
imagesc(time_axis, f_selected, map_C3_feet');
title(['Class ' num2str(CODE_FEET) ' - Channel C3']);
xlabel('Time [s]'); ylabel('Freq [Hz]');
set(gca, 'YDir', 'normal', 'CLim', clim_range);
colorbar;

subplot(2, 2, 4);
imagesc(time_axis, f_selected, map_C4_feet');
title(['Class ' num2str(CODE_FEET) ' - Channel C4']);
xlabel('Time [s]'); ylabel('Freq [Hz]');
set(gca, 'YDir', 'normal', 'CLim', clim_range);
colorbar;

sgtitle('ERD/ERS Maps (Log Ratio vs Baseline)');

%% Statistical Summary
fprintf('Channel C3 Mean Activity: %.4f\n', mean(ERD_ERS(:, :, chan_C3, :), 'all', 'omitnan'));
fprintf('Channel C4 Mean Activity: %.4f\n', mean(ERD_ERS(:, :, chan_C4, :), 'all', 'omitnan'));
fprintf('Visualisation complete.\n');