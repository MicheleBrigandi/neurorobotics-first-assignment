%% ========================================================================
%  BCI PIPELINE: MOTOR IMAGERY CLASSIFICATION (UNIFIED COMPACT MAIN)
%  ========================================================================
%  
%  This script combines the clean, single-loop structure of the original
%  Project A with the advanced modular functions and population analysis
%  of Project B.
%
%  STRUCTURE:
%    0. SETUP: Automatic dataset organisation
%    1. MAIN LOOP (Per Subject):
%       - Preprocessing (GDF -> MAT -> Activity)
%       - Feature Analysis (Stats, ERD, Fisher Score)
%       - Training (LDA)
%       - Testing (Online Evaluation)
%       - Visualisation
%    2. POST-PROCESSING:
%       - Population Grand Average
%       - Metrics Printing
%
%  ========================================================================

%% INITIALISATION
clear; clc; close all;

% Add source and data directories
addpath(genpath('src')); 
addpath(genpath('data')); 

% Optional: Add EEGLAB if available (for topoplots)
% Adjust this path if necessary or keep it generic
eeglab_path = 'C:\Users\Utente\Desktop\neurorobotics\toolboxes\eeglab';
if exist(eeglab_path, 'dir')
    addpath(genpath(eeglab_path));
end

% Load Configuration
if exist('get_config', 'file')
    cfg = get_config();
else
    error('Configuration file "get_config.m" not found.');
end

fprintf('=== BCI PIPELINE INITIALISED ===\n');

%% CONTROL FLAGS
DO_SETUP        = true;  % Organize raw files
DO_PREPROC      = true;  % Convert and extract trials
DO_ANALYSIS     = true;  % Compute stats & visualization
DO_TRAINING     = true;  % Train LDA model
DO_TESTING      = true;  % Test on online data

%% 0. SETUP
if DO_SETUP
    fprintf('\n=== DATASET ORGANISATION ===\n');
    if exist(cfg.paths.downloads, 'dir')
        organize_dataset(cfg.paths.downloads, fullfile(cfg.paths.data, 'raw'));
    else
        warning('Downloads folder not found. Assuming data is already in data/raw.');
    end
end

%% SUBJECT DISCOVERY
raw_root = fullfile(cfg.paths.data, 'raw');
if ~exist(raw_root, 'dir'), error('Raw data folder not found.'); end

dir_content = dir(raw_root);
subjects = dir_content([dir_content.isdir] & ~startsWith({dir_content.name}, '.'));

if isempty(subjects), error('No subjects found.'); end

% Accumulators for Population Analysis (Grand Average)
all_stats = [];  
ga_h = []; ga_f = []; ga_fs = []; ga_ch = []; ga_cf = [];

%% MAIN LOOP
fprintf('\n=== STARTING PROCESSING LOOP (%d Subjects) ===\n', length(subjects));

for s = 1:length(subjects)
    subj_id = subjects(s).name;
    clean_id = strrep(subj_id, '_micontinuous', '');
    
    fprintf('\n-------------------------------------------------\n');
    fprintf('PROCESSING SUBJECT: %s (%d/%d)\n', clean_id, s, length(subjects));
    fprintf('-------------------------------------------------\n');

    % --- Define Paths ---
    subj_raw_dir  = fullfile(raw_root, subj_id);
    subj_prep_dir = fullfile(cfg.paths.data_preproc, subj_id);
    subj_res_dir  = fullfile(cfg.paths.results, subj_id);
    
    if ~exist(subj_res_dir, 'dir'), mkdir(subj_res_dir); end
    
    file_act_off = fullfile(subj_prep_dir, 'activity_offline.mat');
    file_act_on  = fullfile(subj_prep_dir, 'activity_online.mat');
    file_fisher  = fullfile(subj_res_dir, 'fisher_results.mat');
    file_model   = fullfile(subj_res_dir, 'classifier_model.mat');

    % --- 1. PREPROCESSING (Offline & Online) ---
    if DO_PREPROC
        preprocessing(subj_raw_dir, subj_id, 'offline', file_act_off, cfg);
        preprocessing(subj_raw_dir, subj_id, 'online', file_act_on, cfg);
    end

    % --- 2. FEATURE ANALYSIS & STATS ---
    if DO_ANALYSIS && exist(file_act_off, 'file')
        % Compute stats for this subject
        stats = compute_stats(file_act_off, cfg);
        
        if ~isempty(stats)
            stats.id = clean_id; 
            stats.type = 'offline';
            
            % Generate Single Subject Visualizations (Project B style)
            visualize_features(stats, cfg);
            
            % Additional Legacy Visualizations (ERD Maps / Band Power)
            visualize_erd_ers(file_act_off, subj_res_dir, cfg);
            analyze_eeg(file_act_off, subj_res_dir, cfg);
            
            % Accumulate data for Grand Average
            all_stats = [all_stats; stats]; 
            ga_h  = [ga_h, stats.hands_map];
            ga_f  = [ga_f, stats.feet_map];
            ga_fs = cat(3, ga_fs, stats.full_data.fisher_map);
            ga_ch = [ga_ch, stats.curve_h];
            ga_cf = [ga_cf, stats.curve_f]; 
        end
    end

    % --- 3. TRAINING (Offline) ---
    if DO_TRAINING && exist(file_act_off, 'file')
        select_features(file_act_off, file_fisher, cfg);
        train_classifier(file_act_off, file_fisher, file_model, cfg);
    end

    % --- 4. TESTING (Online) ---
    if DO_TESTING && exist(file_act_on, 'file') && exist(file_model, 'file')
        test_classifier(file_act_on, file_model, cfg);
    end
end

%% POST-PROCESSING: POPULATION ANALYSIS (Grand Average)
if DO_ANALYSIS && ~isempty(all_stats)
    fprintf('\n=== POPULATION ANALYSIS (GRAND AVERAGE) ===\n');
    
    % 1. Print Comparative Metrics
    try
        [~, sort_idx] = sort([all_stats.maxFS], 'descend');
        % Select Best 2 and Worst 1 for highlight
        if length(sort_idx) >= 3
            selected_indices = unique([sort_idx(1:min(2, end)), sort_idx(end)]);
        else
            selected_indices = sort_idx;
        end
        print_metrics(all_stats, selected_indices);
    catch
        warning('Could not print sorted metrics (not enough subjects?).');
    end
    
    % 2. Compute Grand Average (Mean across subjects)
    ga.id = 'GrandAverage'; 
    ga.type = 'Offline';
    ga.hands_map = mean(ga_h, 2);
    ga.feet_map  = mean(ga_f, 2);
    ga.full_data.fisher_map = mean(ga_fs, 3);
    ga.curve_h = mean(ga_ch, 2);
    ga.curve_f = mean(ga_cf, 2);
    ga.t_axis  = all_stats(1).t_axis; % Assuming time axis is consistent
    
    % 3. Visualize Grand Average
    visualize_features(ga, cfg);
    
    fprintf('Grand Average computed and saved to Results folder.\n');
end

fprintf('\n=== PIPELINE EXECUTION FINISHED ===\n');