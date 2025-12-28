% =========================================================================
% SCRIPT: CONVERT_SINGLE_GDF
% Purpose: Converts individual GDF files into single MAT-files.
%
% This script iterates through all GDF files in the raw data directory
% (defined in the configuration) and saves them as separate .mat files.
% =========================================================================

%% Configuration
% Load the central configuration if not already present in the workspace
if ~exist('cfg', 'var')
    cfg = get_config();
end

% Define input directory
% You can manually change this to cfg.paths.raw_online if needed
input_dir = cfg.paths.raw_offline;

% Define output directory for individual files
output_dir = fullfile(cfg.paths.data_processed, 'individual_runs');

% Create the directory if it does not exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% File Discovery
% Search for all .gdf files in the input directory
search_pattern = fullfile(input_dir, '*.gdf');
gdf_files = dir(search_pattern);

if isempty(gdf_files)
    warning('No GDF files found in %s', input_dir);
else
    fprintf('Found %d files in %s. Starting conversion...\n', length(gdf_files), input_dir);
end

%% Processing Loop
% Iterate through each file found and convert it
for i = 1:length(gdf_files)
    filename = gdf_files(i).name;
    full_path = fullfile(gdf_files(i).folder, filename);
    
    fprintf('Converting file %d/%d: %s ... ', i, length(gdf_files), filename);
    
    % Load GDF file
    try
        [s, h] = sload(full_path);
    catch
        warning('Failed to load %s. Skipping.', filename);
        continue;
    end
    
    % Extract Data and Event Structure
    data = s;
    TYP = []; DUR = []; POS = [];
    
    if isfield(h, 'EVENT') && isstruct(h.EVENT)
        if isfield(h.EVENT, 'TYP'), TYP = h.EVENT.TYP; end
        if isfield(h.EVENT, 'DUR'), DUR = h.EVENT.DUR; end
        if isfield(h.EVENT, 'POS'), POS = h.EVENT.POS; end
    end
    
    %% Saving Individual File
    % Construct the output filename by replacing extension .gdf with .mat
    [~, name, ~] = fileparts(filename);
    out_name = strcat(name, '.mat');
    out_path = fullfile(output_dir, out_name);
    
    % Save variables to the new MAT file
    save(out_path, 'data', 'TYP', 'DUR', 'POS');
    fprintf('Saved to: %s\n', out_name);
end

if ~isempty(gdf_files)
    fprintf('Batch conversion completed successfully.\n');
end