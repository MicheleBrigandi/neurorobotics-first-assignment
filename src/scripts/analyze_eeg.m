% =========================================================================
% SCRIPT: ANALYZE_EEG
% Purpose: Computes global Band Power (Mu/Beta) for the entire session.
%
% This script computes the Power Spectral Density (PSD) using Welch's method 
% over the entire dataset to identify channels with strong Mu (8-12 Hz) or 
% Beta (13-30 Hz) activity.
% =========================================================================

%% Configuration
if ~exist('cfg', 'var')
    cfg = get_config();
end

% Define input
input_file = cfg.files.concat_offline;

% Define output
output_file = fullfile(cfg.paths.results, 'global_band_power.mat');

%% Data Loading
fprintf('Loading concatenated data: %s...\n', input_file);
if ~exist(input_file, 'file')
    error('Input file not found. Run the preprocessing pipeline first.');
end

tmp = load(input_file);
% Extract signal
if isfield(tmp, 'all_data')
    raw_signal = tmp.all_data(:, 1:cfg.n_channels);
else
    error('Variable "all_data" not found in the input file.');
end

%% Analysis Parameters
% We use the frequency bands defined in the configuration
fs = cfg.fs;
mu_band = [8 12];
beta_band = [13 30];

num_channels = size(raw_signal, 2);

% Initialise arrays for results
mu_power = zeros(1, num_channels);
beta_power = zeros(1, num_channels);

%% Power Computation Loop
fprintf('Analysing %d channels using Welch''s method...\n', num_channels);

for i = 1:num_channels
    % Extract single channel data
    chan_data = raw_signal(:, i);
    
    % Calculate PSD using Welch's method
    [psd, freqs] = pwelch(chan_data, fs, fs/2, [], fs);
    
    % Compute band power by integrating the PSD in the specific range
    mu_power(i) = bandpower(psd, freqs, mu_band, 'psd');
    beta_power(i) = bandpower(psd, freqs, beta_band, 'psd');
end

%% Saving Results
if ~exist(cfg.paths.results, 'dir')
    mkdir(cfg.paths.results);
end

save(output_file, 'mu_power', 'beta_power', 'mu_band', 'beta_band', 'fs');
fprintf('Analysis results saved to: %s\n', output_file);

%% Visualisation
figure('Name', 'Global Band Power Analysis', 'Color', 'w');

% Subplot 1: Mu Band
subplot(2, 1, 1);
bar(mu_power, 'FaceColor', [0.2, 0.6, 0.8]);
title('Average Mu Band Power (8-12 Hz)');
xlabel('Channel Index'); ylabel('Power [\muV^2/Hz]');
grid on;

% Subplot 2: Beta Band
subplot(2, 1, 2);
bar(beta_power, 'FaceColor', [0.8, 0.4, 0.2]);
title('Average Beta Band Power (13-30 Hz)');
xlabel('Channel Index'); ylabel('Power [\muV^2/Hz]');
grid on;

fprintf('Visualisation generated.\n');