%% ========================================================================
%  BCI PIPELINE: MOTOR IMAGERY CLASSIFICATION
%  ========================================================================
%  
%  PIPELINE STRUCTURE:
%    0. SETUP:            Automatic organisation of raw GDF files into subject folders
%    1. PREPROCESSING:    GDF -> MAT conversion, Laplacian, PSD, Trial Extraction
%    2. FEATURE ANALYSIS: ERD and Fisher score are computed
%    2. TRAINING:         Feature Selection (Fisher Score) & Model Training (LDA)
%    3. EVALUATION:       Online Testing with Evidence Accumulation
%    4. VISUALISATION:    ERD/ERS Maps and Global Power Analysis (Single Subject)
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
DO_DATA_SETUP       = true;
DO_PREPROCESSING    = true;  
DO_FEATURE_ANALYSIS = true;
DO_TRAINING         = true;
DO_TESTING          = true;
DO_VISUALIZATION    = true;

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

all_stats = [];  
ga_h = []; ga_f = []; ga_fs = []; ga_ch = []; ga_cf = [];

%% 1. PREPROCESSING
fprintf('\n=== PHASE 1: PREPROCESSING ===\n');

for s = 1:length(subjects)
    subj_id = subjects(s).name;
    subj_dir = fullfile(raw_root, subj_id); 

    prep_dir = fullfile(cfg.paths.root, 'data', 'preprocessed', subj_id);

    clean_id = strrep(subj_id, '_micontinuous', ''); 
    fprintf('PROCESSING: %s (%s)\n', clean_id, subj_id);
    
    run_types = {'offline', 'online'};
    for t = 1:2
        type = run_types{t}; 
        current_save_path = fullfile(prep_dir, ['activity_', type, '.mat']);
        
        % preprocessing
        if DO_PREPROCESSING
            process_and_concatenate_integrated(subj_dir, subj_id, type, current_save_path, cfg);
        end
        
        % 2. compute features
        if DO_FEATURE_ANALYSIS
            stats = compute_stats(current_save_path, cfg);
    
            if ~isempty(stats)
                stats.id   = clean_id; 
                stats.type = type;
                stats.tag  = '';  
                
                visualize_features(stats, cfg);    
               
                
                if strcmp(type, 'offline')
                    all_stats = [all_stats; stats]; 
                    ga_h  = [ga_h, stats.hands_map];
                    ga_f  = [ga_f, stats.feet_map];
                    ga_fs = cat(3, ga_fs, stats.full_data.fisher_map);
                    ga_ch = [ga_ch, stats.curve_h];
                    ga_cf = [ga_cf, stats.curve_f];         
                end
            end
        end
    end
end

%% 2. FEATURE ANALYSIS
fprintf('\n=== PHASE 2: FEATURE ANALYSIS ===\n');

if DO_FEATURE_ANALYSIS && ~isempty(all_stats)
    % Ranking by Max Fisher Score
    [~, sort_idx] = sort([all_stats.maxFS], 'descend');
    
    % Selecting the best 2 and worst 1 subject
    top_2_idx = sort_idx(1:min(2, length(sort_idx)));
    bottom_1_idx = sort_idx(end);
    selected_indices = unique([top_2_idx, bottom_1_idx]);
    
    % Print
    print_metrics(all_stats, selected_indices);
    
    % Visualization-population
    visualize_features(all_stats(1), cfg, all_stats); 
    

    ga.id = 'GrandAverage'; 
    ga.type = 'Offline';
    ga.hands_map = mean(ga_h, 2);
    ga.feet_map  = mean(ga_f, 2);
    ga.full_data.fisher_map = mean(ga_fs, 3);
    ga.curve_h = mean(ga_ch, 2);
    ga.curve_f = mean(ga_cf, 2);
    ga.t_axis  = all_stats(1).t_axis;
    

    visualize_features(ga, cfg);
    
    fprintf('Section 2 Complete\n');
else
    fprintf('Section 2 failed\n');
end

for s = 1:length(subjects)
    subj_id = subjects(s).name;
    
    fprintf('\n-------------------------------------------------\n');
    fprintf('PROCESSING SUBJECT: %s (%d/%d)\n', subj_id, s, length(subjects));
    fprintf('-------------------------------------------------\n');
    
    % Intermediate processed directories
    subj_preproc_dir = fullfile(cfg.paths.data_preproc, subj_id);
    
    % Final aggregated files
    activity_off_file = fullfile(subj_preproc_dir, 'activity_offline.mat');
    activity_on_file  = fullfile(subj_preproc_dir, 'activity_online.mat');
    
    % Results/Models
    subj_results_dir = fullfile(cfg.paths.results, subj_id);
    fisher_file      = fullfile(subj_results_dir, 'fisher_results.mat');
    model_file       = fullfile(subj_results_dir, 'classifier_model.mat');
    
    % Ensure results directory exists
    if ~exist(subj_results_dir, 'dir')
        mkdir(subj_results_dir); 
    end

    %% 3. TRAINING
    if DO_TRAINING
        fprintf('[%s] --- PHASE 3: TRAINING ---\n', subj_id);
        
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
    
    %% 4. EVALUATION (Online Testing)
    if DO_TESTING
        fprintf('[%s] --- PHASE 4: EVALUATION ---\n', subj_id);
        
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

    %% 5. VISUALIZATION (Single Subject)
    if DO_VISUALIZATION
        fprintf('[%s] --- PHASE 5: VISUALISATION ---\n', subj_id);
        
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

fprintf('\n=== PIPELINE EXECUTION FINISHED ===\n');