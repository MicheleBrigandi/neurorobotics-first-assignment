function concat_gdf(input_dir, output_filepath)
% CONCAT_GDF Concatenates all GDF files found in a directory.
%
% This function looks for all .gdf files in the specified input directory,
% loads them, concatenates signals and events, and saves the result to a
% single .mat file.
%
% INPUTS:
%   input_dir       - String. Path to the folder containing .gdf files.
%   output_filepath - String. Full destination path (including filename)
%                     where the output .mat file will be saved.
%
% USAGE:
%   concat_gdf(cfg.paths.raw_offline, cfg.files.concat_offline);

    %% File Discovery
    % Search for all .gdf files in the specified directory
    search_pattern = fullfile(input_dir, '*.gdf');
    gdf_files = dir(search_pattern);
    
    if isempty(gdf_files)
        warning('No GDF files found in: %s', input_dir);
        return;
    end
    
    fprintf('Found %d files in %s. Starting concatenation...\n', length(gdf_files), input_dir);

    %% Initialisation
    % Initialise empty arrays for the concatenated dataset
    all_data = [];
    all_TYP  = [];
    all_DUR  = [];
    all_POS  = [];
    current_pos_offset = 0;

    %% Processing Loop
    for i = 1:length(gdf_files)
        file_path = fullfile(gdf_files(i).folder, gdf_files(i).name);
        fprintf('Processing file %d/%d: %s\n', i, length(gdf_files), gdf_files(i).name);

        % Load GDF file
        try
            [s, h] = sload(file_path);
        catch ME
            error('Failed to load %s. Ensure BioSig is installed.', gdf_files(i).name);
        end

        % Concatenate event information
        if isfield(h, 'EVENT') && isstruct(h.EVENT)
            % Append TYP and DUR directly
            if isfield(h.EVENT, 'TYP'), all_TYP = [all_TYP; h.EVENT.TYP]; end
            if isfield(h.EVENT, 'DUR'), all_DUR = [all_DUR; h.EVENT.DUR]; end
            
            % Append POS adjusting for the cumulative offset
            if isfield(h.EVENT, 'POS')
                all_POS = [all_POS; h.EVENT.POS + current_pos_offset];
            end
        end

        % Concatenate signal data
        all_data = [all_data; s];

        % Update offset
        current_pos_offset = size(all_data, 1);
    end

    %% Saving Results
    % Create the output directory if it doesn't exist
    output_dir = fileparts(output_filepath);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Save the standard variables required by the processing pipeline.
    save(output_filepath, 'all_data', 'all_TYP', 'all_DUR', 'all_POS');
    fprintf('Concatenated data saved to %s\n', output_filepath);
end

