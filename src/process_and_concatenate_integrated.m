function process_and_concatenate_integrated(raw_dir, subj_id, run_type, prep_out_path, cfg)
% PROCESS_AND_CONCATENATE_INTEGRATED 
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
        %fprintf('[process] Step 1: Converting GDF to MAT...\n');
        convert_gdf2mat(gdf_source_dir, temp_mat_dir);

        % 2. Compute PSD
        %fprintf('[process] Step 2: Computing PSD...\n');
        % compute_psd(input_dir, output_dir, laplacian_path, cfg)
        compute_psd(temp_mat_dir, temp_psd_dir, cfg.files.laplacian, cfg);

        % 3. Extract Trials
        %fprintf('[process] Step 3: Extracting Trials...\n');
        % extract_trials(input_dir, output_filepath, cfg)
        extract_trials(temp_psd_dir, prep_out_path, cfg);

    catch ME
        fprintf('[process] Error occurred: %s\n', ME.message);
        % Rethrow to ensure the user knows something failed
        rethrow(ME);
    end
    
    % Cleanup
    fprintf('[process] Cleaning up temporary files...\n');
    if exist(temp_mat_dir, 'dir'), rmdir(temp_mat_dir, 's'); end
    if exist(temp_psd_dir, 'dir'), rmdir(temp_psd_dir, 's'); end
    
    fprintf('[process] Processing complete. Result saved to: %s\n', prep_out_path);

end
