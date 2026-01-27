function analyze_eeg(activity_path, output_dir, cfg)
% ANALYZE_EEG Computes and plots global band power distribution per channel.
%
% This function performs the global spectral analysis designed to identify
% which channels show the strongest activity in Mu and Beta bands.
%
% INPUTS:
%   activity_path - Path to file containing Activity matrix.
%   output_dir    - Folder where the plot will be saved.
%   cfg           - Config struct.

    %% Input Validation
    if ~exist(activity_path, 'file')
        warning('[analyze_eeg] Input file not found: %s', activity_path);
        return;
    end
    
    if ~exist(output_dir, 'dir') 
        mkdir(output_dir); 
    end
    
    % Load Data
    data = load(activity_path);
    Activity = data.Activity;
    freqs    = data.freqs;
    chanlabs = data.chanlabs;
    
    %% Compute Global PSD
 
    avg_psd = squeeze(mean(mean(Activity, 1, 'omitnan'), 4, 'omitnan'));
    
    %% Band Power Integration
    
    mu_band   = [8 13];
    beta_band = [13 30];
    
    % Find frequency indices
    idx_mu   = freqs >= mu_band(1) & freqs <= mu_band(2);
    idx_beta = freqs >= beta_band(1) & freqs <= beta_band(2);
    
    % Sum power in bands for each channel
    mu_power   = sum(avg_psd(idx_mu, :), 1);
    beta_power = sum(avg_psd(idx_beta, :), 1);
    
    %% Visualisation
    
    if isfield(cfg, 'channels') && isfield(cfg.channels, 'names')
        % Ensure we don't exceed the number of actual data channels
        n_ch = min(length(cfg.channels.names), length(mu_power));
        x_labels = cfg.channels.names(1:n_ch);
    elseif ~isempty(chanlabs)
        x_labels = chanlabs;
    end

    % Create figure
    fig = figure('Name', 'Global Band Power', 'Color', 'w', 'Visible', 'off', ...
                 'Position', [0 0 800 600]);
    
    % Subplot 1: Mu Band
    subplot(2, 1, 1);
    bar(mu_power, 'FaceColor', [0.2, 0.6, 0.8]);
    title('Average Mu Band Power (8-12 Hz)');
    ylabel('Power [\muV^2/Hz]');
    
    % Set X-ticks labels dynamically
    set(gca, 'XTick', 1:length(x_labels), 'XTickLabel', x_labels);
    xtickangle(45);
    xlim([0.5, length(x_labels)+0.5]);
    grid on;
    
    % Subplot 2: Beta Band
    subplot(2, 1, 2);
    bar(beta_power, 'FaceColor', [0.8, 0.4, 0.2]);
    title('Average Beta Band Power (13-30 Hz)');
    ylabel('Power [\muV^2/Hz]');
    
    % Set X-ticks labels dynamically
    set(gca, 'XTick', 1:length(x_labels), 'XTickLabel', x_labels);
    xtickangle(45);
    xlim([0.5, length(x_labels)+0.5]);
    grid on;
    
    %% Save
    out_file = fullfile(output_dir, 'global_band_power.png');
    saveas(fig, out_file);
    close(fig);
    
end