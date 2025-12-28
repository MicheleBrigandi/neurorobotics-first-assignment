%% ========================================================================
%  BCI PIPELINE: MOTOR IMAGERY CLASSIFICATION
%  ========================================================================
%  
%  PIPELINE STRUCTURE:
%    0. SETUP:         Automatic organisation of raw GDF files
%    1. PREPROCESSING: Concatenation, Spatial Filtering, PSD, Segmentation
%    2. TRAINING:      Feature Selection (Fisher Score) & Model Training (LDA)
%    3. EVALUATION:    Online Testing
%    4. VISUALISATION: ERD/ERS Maps and Global Power Analysis
%
%  USAGE:
%    Set the boolean flags below to 'true' or 'false' to control which
%    phases of the pipeline are executed.
%  ========================================================================

%% INITIALISATION
clear; clc; close all;

% Add source and data directories to the MATLAB path
addpath(genpath('src')); 
addpath(genpath('data')); 

% Load the centralised configuration structure
if exist('get_config', 'file')
    cfg = get_config();
else
    error('Configuration file "src/scripts/get_config.m" not found. Please check directory structure.');
end

fprintf('=== BCI PIPELINE INITIALISED ===\n');

%% CONTROL FLAGS
% Toggle these flags to run specific parts of the pipeline.

DO_DATA_SETUP     = true;
DO_PREPROCESSING  = true;  
DO_TRAINING       = true;  
DO_TESTING        = false;  
DO_VISUALISATION  = false; 

%% 0. SETUP
if DO_DATA_SETUP
    fprintf('\n=== PHASE 0: SETUP ===\n');
    
    % Check if the download folder exists and contains GDF files
    if exist(cfg.paths.downloads, 'dir') && ~isempty(dir(fullfile(cfg.paths.downloads, '**', '*.gdf')))
        
        % Check if the destination folder is empty to avoid redundant copying
        if isempty(dir(fullfile(cfg.paths.raw_offline, '*.gdf')))
            fprintf('New raw dataset detected. Organising file structure...\n');
            
            % Call the organisation function with the path from config
            organize_dataset(cfg.paths.downloads);
        else
            fprintf('Dataset already organised. Skipping setup.\n');
        end
    else
        fprintf('No downloads detected or folders already set up.\n');
    end
end

%% 1. PREPROCESSING
if DO_PREPROCESSING
    fprintf('\n=== PHASE 1: DATA PREPROCESSING ===\n');
    
    % Data Ingestion
    % Merges individual GDF files into single continuous MAT files
    fprintf('Concatenating GDF files...\n');
    concat_gdf(cfg.paths.raw_offline, cfg.files.concat_offline);
    concat_gdf(cfg.paths.raw_online,  cfg.files.concat_online);
    
    % Spectrogram Computation (PSD)
    % Applies Laplacian spatial filter and computes PSD over time windows
    fprintf('Computing Power Spectral Density (PSD)...\n');
    compute_psd(cfg.files.concat_offline, cfg.files.psd_offline);
    compute_psd(cfg.files.concat_online,  cfg.files.psd_online);
    
    % Trial Segmentation
    % Extracts the relevant "Continuous Feedback" phase based on Cue triggers
    fprintf('Segmenting trials...\n');
    extract_trials(cfg.files.psd_offline, cfg.files.activity_offline);
    extract_trials(cfg.files.psd_online,  cfg.files.activity_online);
    
    fprintf('Preprocessing completed successfully.\n');
else
    fprintf('\n[Phase 1 Skipped] Assuming preprocessed data exists.\n');
end

%% 2. MODEL CALIBRATION
if DO_TRAINING
    fprintf('\n=== PHASE 2: TRAINING ===\n');
    
    % Ensure offline data is available
    if ~exist(cfg.files.activity_offline, 'file')
        error('Offline Activity data missing. Run Phase 1 first.');
    end
    
    % Feature Selection
    % Analyses the offline data to find the most discriminative 
    % Frequency-Channel pairs.
    fprintf('Selecting features...\n');
    select_features(cfg.files.activity_offline, cfg.files.fisher_results);
    
    % Classifier Training
    % Trains the Linear Discriminant Analysis model using the selected features
    fprintf('Training classifier...\n');
    train_classifier(cfg.files.activity_offline, ...
                     cfg.files.fisher_results, ...
                     cfg.files.model);
                     
    fprintf('Training completed. Model saved.\n');
else
    fprintf('\n[Phase 2 Skipped] Assuming model already trained.\n');
end

%% 3. EVALUATION
if DO_TESTING
    fprintf('\n=== PHASE 3: ONLINE EVALUATION ===\n');
else
    fprintf('\n[Phase 3 Skipped]\n');
end

%% 4. VISUALISATION
if DO_VISUALISATION
    fprintf('\n=== PHASE 4: VISUALISATION ===\n');
    
    % Band Power Analysis
    % Generates a bar chart of Mu/Beta power across channels
    fprintf('Running Global Band Power Analysis...\n');
    run('analyze_eeg.m');
    
    % ERD/ERS Maps
    % Generates Time-Frequency maps for C3/C4 channels.
    fprintf('Running ERD/ERS visualisation...\n');
    run('visualize_erd_ers.m');
    
    fprintf('Visualisation generated.\n');
end

fprintf('\n=== PIPELINE EXECUTION FINISHED ===\n');