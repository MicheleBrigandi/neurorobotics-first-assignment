function preprocessing(raw_dir, subj_id, run_type, prep_out_path, cfg)
% PREPROCESSING 
% Integrated pipeline: GDF -> MAT -> PSD -> Extracted Trials.
% 
% Replaces manual processing with calls to modular functions:
% - convert_gdf2mat
% - compute_psd
% - extract_trials

    % Define source directory for GDF files
    gdf_source_dir = fullfile(raw_dir, run_type);
    
    % Check if source directory exists and has GDF files
    % Note: convert_gdf2mat will process all .gdf files in this directory.
    % We assume the folder only contains relevant files for this run_type.
    if ~exist(gdf_source_dir, 'dir')
        fprintf('Directory not found: %s\n', gdf_source_dir);
        return;
    end
    
    % Define temporary directories for intermediate steps
    [out_dir, ~, ~] = fileparts(prep_out_path);
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    % Use distinct temp folders to avoid collisions
    temp_mat_dir = fullfile(out_dir, 'temp_conversion_mat');
    temp_psd_dir = fullfile(out_dir, 'temp_computation_psd');
    
    % Cleanup existing temp dirs if they exist from a failed run
    if exist(temp_mat_dir, 'dir'), rmdir(temp_mat_dir, 's'); end
    if exist(temp_psd_dir, 'dir'), rmdir(temp_psd_dir, 's'); end
    
    % Create temp dirs
    mkdir(temp_mat_dir);
    mkdir(temp_psd_dir);
    
    try
        % 1. Convert GDF to MAT
        convert_gdf2mat(gdf_source_dir, temp_mat_dir);

        % 2. Compute PSD
        compute_psd(temp_mat_dir, temp_psd_dir, cfg.files.laplacian, cfg);

        % 3. Extract Trials
        extract_trials(temp_psd_dir, prep_out_path, cfg);

    catch ME
        fprintf('[process] Error occurred: %s\n', ME.message);
        % Rethrow to ensure the user knows something failed
        rethrow(ME);
    end
    
    % Cleanup
    if exist(temp_mat_dir, 'dir'), rmdir(temp_mat_dir, 's'); end
    if exist(temp_psd_dir, 'dir'), rmdir(temp_psd_dir, 's'); end

end
