function cfg = get_config()
% GET_CONFIG Returns the global configuration structure for the BCI pipeline.
%
% This function centralises all parameters used for signal processing,
% feature extraction, and classification. It ensures consistency across
% different scripts (preprocessing, training, and testing).
%
% OUTPUT:
%   cfg - Struct containing paths, file names, and algorithm parameters.
%
% USAGE:
%   cfg = get_config();

    %% DIRECTORY STRUCTURE

    cfg.paths.root           = pwd;
    cfg.paths.data           = fullfile(cfg.paths.root, 'data');
    cfg.paths.downloads      = fullfile(cfg.paths.data, 'downloads');
    cfg.paths.raw_offline    = fullfile(cfg.paths.data, 'raw', 'offline');
    cfg.paths.raw_online     = fullfile(cfg.paths.data, 'raw', 'online');
    cfg.paths.data_processed = fullfile(cfg.paths.data, 'processed');
    cfg.paths.results        = fullfile(cfg.paths.root, 'results');

    %% FILE REGISTRY
    
    % External Resources / Dependencies
    % The spatial Laplacian filter mask (provided with the dataset).
    cfg.files.laplacian = fullfile(cfg.paths.data, 'laplacian16.mat');
    
    % Intermediate Pipeline Files (Processed Data)
    % Concatenated raw data
    cfg.files.concat_offline = fullfile(cfg.paths.data_processed, 'concat_gdf_offline.mat');
    cfg.files.concat_online  = fullfile(cfg.paths.data_processed, 'concat_gdf_online.mat');
    
    % Power Spectral Density (PSD)
    cfg.files.psd_offline    = fullfile(cfg.paths.data_processed, 'eeg_psd_offline.mat');
    cfg.files.psd_online     = fullfile(cfg.paths.data_processed, 'eeg_psd_online.mat');
    
    % Segmented Trials (Activity Matrix)
    cfg.files.activity_offline = fullfile(cfg.paths.data_processed, 'activity_offline.mat');
    cfg.files.activity_online  = fullfile(cfg.paths.data_processed, 'activity_online.mat');
    
    % Output Results
    % Fisher Score ranking and indices
    cfg.files.fisher_results = fullfile(cfg.paths.results, 'fisher_results.mat');
    % The trained LDA classifier model
    cfg.files.model          = fullfile(cfg.paths.results, 'classifier_model.mat');

    %% ACQUISITION PARAMETERS
    % Sampling rate in Hz.
    % Note: The g.USBamp amplifier used in the experiment is set to 512 Hz
    cfg.fs = 512; 
    
    % Number of EEG channels acquired (10-20 international system)
    cfg.n_channels = 16;
    
    %% SIGNAL PROCESSING (Spectrogram)
    % These parameters define how the Power Spectral Density (PSD) is computed
    
    % Window length for the spectrogram (in seconds)
    cfg.spec.wlength = 0.5;
    
    % Shift of the external window (sliding step) in seconds
    % 0.0625 s corresponds to a temporal resolution of 16 Hz
    cfg.spec.wshift = 0.0625;
    
    % Shift of the internal windows for PSD averaging (Welch's method)
    cfg.spec.pshift = 0.25;
    
    % Length of the moving average filter (in seconds)
    cfg.spec.mlength = 1;
    
    % Frequency band of interest (in Hz)
    cfg.spec.freq_band = [4 48];
    
    %% EVENT CODES (GDF Standard)

    cfg.codes.hands    = 773; % 0x0305: Cue - Both Hands
    cfg.codes.feet     = 771; % 0x0303: Cue - Both Feet
    cfg.codes.feedback = 781; % 0x030D: Continuous Feedback Start
    
    %% MACHINE LEARNING PARAMETERS
    % Parameters for dimensionality reduction and classification
    
    % Number of top discriminative features (Frequency-Channel pairs) to select
    % using the Fisher Score algorithm
    cfg.train.n_features = 30;
end