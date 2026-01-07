function cfg = get_config()
% GET_CONFIG Returns the global configuration structure for the BCI pipeline.
%
% This function centralises all constant parameters used for signal processing,
% feature extraction, and classification. 
%
% OUTPUT:
%   cfg - Struct containing paths, constants, and algorithm parameters.
%
% USAGE:
%   cfg = get_config();

    %% DIRECTORY STRUCTURE
    cfg.paths.root      = pwd;
    cfg.paths.data      = fullfile(cfg.paths.root, 'data');
    cfg.paths.downloads = fullfile(cfg.paths.data, 'downloads');
    
    % Root folder for organised raw data
    cfg.paths.raw_root = fullfile(cfg.paths.data, 'raw');
    
    % Root folders for outputs
    cfg.paths.data_preproc   = fullfile(cfg.paths.data, 'preprocessed');
    cfg.paths.data_processed = fullfile(cfg.paths.data, 'processed');
    cfg.paths.results        = fullfile(cfg.paths.root, 'results');

    %% FILE REGISTRY
    % Only include files that are common to all subjects
    
    % The spatial Laplacian filter mask (provided with the dataset)
    cfg.files.laplacian = fullfile(cfg.paths.data, 'laplacian16.mat');
    cfg.files.chanlocs = fullfile(cfg.paths.data, 'chanlocs16.mat');
    
    %% ACQUISITION PARAMETERS
    % Sampling rate in Hz.
    % Note: The g.USBamp amplifier used in the experiment is set to 512 Hz
    cfg.fs = 512; 
    
    % Number of EEG channels acquired (10-20 international system)
    cfg.n_channels = 16;

    % Channels names mapping (position correponds to index)
    cfg.channels.names = {'Fz', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', ...
                          'C3', 'C1', 'Cz', 'C2', 'C4', ...
                          'CP3', 'CP1', 'CPz', 'CP2', 'CP4'};
    
    %% SIGNAL PROCESSING (Spectrogram / PSD)
    % These parameters define how the Power Spectral Density (PSD) is computed
    
    % Window length for the spectrogram (in seconds)
    cfg.spec.wlength = 0.5;
    
    % Shift of the external window (sliding step) in seconds
    % 0.0625 s corresponds to a temporal resolution of 16 Hz
    cfg.spec.wshift = 0.0625;
    
    % Shift of the internal windows for PSD averaging
    cfg.spec.pshift = 0.25;
    
    % Length of the moving average filter (in seconds)
    cfg.spec.mlength = 1;
    
    % Frequency band of interest (in Hz)
    cfg.spec.freq_band = [4 48];
    
    %% EVENT CODES (GDF Standard)
    % Hex codes converted to decimal
    cfg.codes.fix      = 786; % 0x0312: Fixation Cross
    cfg.codes.hands    = 773; % 0x0305: Cue - Both Hands
    cfg.codes.feet     = 771; % 0x0303: Cue - Both Feet
    cfg.codes.feedback = 781; % 0x030D: Continuous Feedback Start
    
    %% MACHINE LEARNING PARAMETERS
    % Parameters for dimensionality reduction and classification
    
    % Number of top discriminative features (Frequency-Channel pairs) to select
    % using the Fisher Score algorithm
    cfg.train.n_features = 10;

    %% VISUALISATION PARAMETERS
    % File used for computing mean ERD/ERS on whole population
    cfg.grandaverage.target_filename = 'activity_offline.mat';
end