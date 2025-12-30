%% ========================================================================
%  BCI PIPELINE: MOTOR IMAGERY CLASSIFICATION
%  ========================================================================
%  
%  PIPELINE STRUCTURE:
%    0. SETUP:         Automatic organisation of raw GDF files into subject folders
%    1. PREPROCESSING: GDF -> MAT conversion, Laplacian, PSD, Trial Extraction
%    2. TRAINING:      Feature Selection (Fisher Score) & Model Training (LDA)
%    3. EVALUATION:    Online Testing with Evidence Accumulation
%    4. VISUALISATION: ERD/ERS Maps and Global Power Analysis (Single Subject)
%    5. POPULATION:    Grand Average Analysis
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
    error('Configuration file "get_config.m" not found. Please check directory structure.');
end

fprintf('=== BCI PIPELINE INITIALISED ===\n');

%% CONTROL FLAGS
% Toggle these flags to run specific parts of the pipeline
DO_DATA_SETUP     = true;   % Run once to sort downloaded files
DO_PREPROCESSING  = true;   % Converts GDFs and computes PSD/Activity
DO_TRAINING       = true;   % Feature Selection + LDA Training
DO_TESTING        = true;   % Run Evaluation on Online Data
DO_VISUALISATION  = true;   % Generates ERD maps and Band Power plots

%% 0. SETUP
if DO_DATA_SETUP
    fprintf('\n=== PHASE 0: DATASET ORGANISATION ===\n');
    
    % Define where raw data should be stored
    raw_data_root = fullfile(cfg.paths.data, 'raw');
    
    % Check if downloads folder exists
    if exist(cfg.paths.downloads, 'dir')
        fprintf('Organising dataset from: %s\n', cfg.paths.downloads);
        organize_dataset(cfg.paths.downloads, raw_data_root);
    else
        warning('Downloads folder not found at %s. Assuming data is already in %s.', ...
                cfg.paths.downloads, raw_data_root);
    end
end

%% SUBJECT DISCOVERY
% Scan the 'raw' folder to find all subjects automatically
raw_root = fullfile(cfg.paths.data, 'raw');
if ~exist(raw_root, 'dir')
    error('Raw data folder not found. Run SETUP phase first.');
end

dir_content = dir(raw_root);
% Filter out dots and non-folders to get subject list
subjects = dir_content([dir_content.isdir] & ~startsWith({dir_content.name}, '.'));

if isempty(subjects)
    error('No subjects found in %s.', raw_root);
end

fprintf('\nFound %d subjects: %s\n', length(subjects), strjoin({subjects.name}, ', '));

%% MAIN SUBJECT LOOP
for s = 1:length(subjects)
    subj_id = subjects(s).name;
    
    fprintf('\n-------------------------------------------------\n');
    fprintf('PROCESSING SUBJECT: %s (%d/%d)\n', subj_id, s, length(subjects));
    fprintf('-------------------------------------------------\n');
    
    % Define subject-specific paths
    % Input raw directories
    raw_off_dir = fullfile(raw_root, subj_id, 'offline');
    raw_on_dir  = fullfile(raw_root, subj_id, 'online');
    
    % Intermediate processed directories
    subj_proc_dir = fullfile(cfg.paths.data_processed, subj_id);
    
    temp_off_dir = fullfile(subj_proc_dir, 'temp_raw_offline');
    temp_on_dir  = fullfile(subj_proc_dir, 'temp_raw_online');
    
    psd_off_dir  = fullfile(subj_proc_dir, 'psd_offline');
    psd_on_dir   = fullfile(subj_proc_dir, 'psd_online');
    
    % Final aggregated files
    activity_off_file = fullfile(subj_proc_dir, 'activity_offline.mat');
    activity_on_file  = fullfile(subj_proc_dir, 'activity_online.mat');
    
    % Results/Models
    subj_results_dir = fullfile(cfg.paths.results, subj_id);
    fisher_file      = fullfile(subj_results_dir, 'fisher_results.mat');
    model_file       = fullfile(subj_results_dir, 'classifier_model.mat');
    
    % Ensure results directory exists
    if ~exist(subj_results_dir, 'dir')
        mkdir(subj_results_dir); 
    end

    %% 1. PREPROCESSING
    if DO_PREPROCESSING
        fprintf('[%s] --- PHASE 1: PREPROCESSING ---\n', subj_id);
        
        % Convert GDF to MAT
        convert_gdf2mat(raw_off_dir, temp_off_dir);
        convert_gdf2mat(raw_on_dir,  temp_on_dir);
        
        % Compute PSD
        compute_psd(temp_off_dir, psd_off_dir, cfg.files.laplacian, cfg);
        compute_psd(temp_on_dir,  psd_on_dir,  cfg.files.laplacian, cfg);
        
        % Trial extraction and concatenation
        extract_trials(psd_off_dir, activity_off_file, cfg);
        extract_trials(psd_on_dir,  activity_on_file,  cfg);
        
        fprintf('[%s] Preprocessing complete.\n', subj_id);
    end
    
    %% 2. MODEL CALIBRATION
    if DO_TRAINING
        fprintf('[%s] --- PHASE 2: TRAINING ---\n', subj_id);
        
        if ~exist(activity_off_file, 'file')
            warning('Offline activity file missing for %s. Skipping training.', subj_id);
            continue;
        end
        
        % Feature Selection (Fisher Score)
        select_features(activity_off_file, fisher_file, cfg);
        
        % Classifier Training (LDA)
        train_classifier(activity_off_file, fisher_file, model_file, cfg);
        
        fprintf('[%s] Training complete. Model saved.\n', subj_id);
    end
    
    %% 3. EVALUATION (Online Testing)
    if DO_TESTING
        fprintf('[%s] --- PHASE 3: EVALUATION ---\n', subj_id);
        
        if ~exist(activity_on_file, 'file')
            warning('[%s] Online activity file not found. Skipping evaluation.', subj_id);
        elseif ~exist(model_file, 'file')
            warning('[%s] Model file not found. Skipping evaluation.', subj_id);
        else
            % Evaluate the classifier on online data
            test_classifier(activity_on_file, model_file, cfg);
        end
        
        fprintf('[%s] Evaluation complete.\n', subj_id);
    end

    %% 4. VISUALISATION (Single Subject)
    if DO_VISUALISATION
        fprintf('[%s] --- PHASE 4: VISUALISATION ---\n', subj_id);
        
        if ~exist(activity_off_file, 'file')
            warning('Activity file missing. Skipping visualization.');
        else
            % ERD/ERS Maps (Time-Frequency)
            % Generates 'erd_ers_maps.png' in the subject results folder
            visualize_erd_ers(activity_off_file, subj_results_dir, cfg);
            
            % Global Band Power (Bar Charts)
            % Generates 'global_band_power.png' in the subject results folder
            analyze_eeg(activity_off_file, subj_results_dir, cfg);
        end
    end
    
end

%% 5. POPULATION ANALYSIS
% Runs once after all subjects are processed
if DO_VISUALISATION
    fprintf('\n--- PHASE 5: POPULATION ANALYSIS (GRAND AVERAGE) ---\n');
    
    % Generates 'grand_average_maps.png' in the results folder
    compute_grand_average(cfg.paths.data_processed, cfg.paths.results, ...
                          cfg.grandaverage.target_filename, cfg);
end

fprintf('\n=== PIPELINE EXECUTION FINISHED ===\n');