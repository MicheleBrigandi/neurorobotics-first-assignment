function convert_gdf2mat(input_dir, output_dir)
% CONVERT_GDF2MAT Converts GDF files into MATLAB .mat format.
%
% This function scans a directory for GDF files, loads them using the BioSig 
% toolbox, and saves the raw data, events, and channel metadata into 
% individual .mat files.
%
% INPUTS:
%   input_dir  - String path to the folder containing source .gdf files.
%   output_dir - String path to the destination folder for .mat files.
%
% OUTPUTS:
%   None. Files are saved to disk with the following variables:
%     - data:     [Samples x Channels] Raw EEG signal.
%     - events:   Struct containing TYP, POS, DUR vectors.
%     - fs:       Sampling rate (Hz).
%     - chanlabs: Cell array of channel labels (e.g., {'C3', 'Cz'}).
%
% USAGE:
%   convert_gdf2mat('data/raw/ai7/offline', 'data/processed/ai7/temp_raw_off');

    %% Input Validation
    if nargin < 2
        error('[convert_gdf2mat] Error: Input and output directories must be specified.\n');
    end

    % Check if source directory exists
    if ~exist(input_dir, 'dir')
        warning('[convert_gdf2mat] Input directory not found: %s\n', input_dir);
        return;
    end

    % Create output directory if it does not exist
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% File Discovery
    % Search for all GDF files in the directory
    gdf_files = dir(fullfile(input_dir, '*.gdf'));
    
    if isempty(gdf_files)
        warning('[convert_gdf2mat] No .gdf files found in %s\n', input_dir);
        return;
    end
    
    fprintf('[convert_gdf2mat] Found %d files. Starting conversion...\n', length(gdf_files));

    %% Conversion Loop
    for i = 1:length(gdf_files)
        filename = gdf_files(i).name;
        full_path = fullfile(gdf_files(i).folder, filename);
        
        fprintf('[convert_gdf2mat] Converting file %d/%d: %s ...\n', i, length(gdf_files), filename);
        
        try
            % Load data
            [s, h] = sload(full_path);
            
            % Extract Events
            events.TYP = []; 
            events.POS = []; 
            events.DUR = [];
            
            if isfield(h, 'EVENT')
                if isfield(h.EVENT, 'TYP'), events.TYP = h.EVENT.TYP; end
                if isfield(h.EVENT, 'POS'), events.POS = h.EVENT.POS; end
                if isfield(h.EVENT, 'DUR'), events.DUR = h.EVENT.DUR; end
            end
            
            % Extract signal metadata
            data = s; 
            fs = h.SampleRate; 
            
            % Extract channel labels
            if isfield(h, 'Label')
                chanlabs = cellstr(h.Label);   % Convert char array to cell array
                chanlabs = strtrim(chanlabs);  % Remove trailing whitespace
            end
            
            % Save to disk
            % Construct output filename (replace .gdf with .mat)
            [~, name_no_ext, ~] = fileparts(filename);
            out_filename = fullfile(output_dir, [name_no_ext '.mat']);
            
            % Save variables
            save(out_filename, 'data', 'events', 'fs', 'chanlabs');
            
        catch ME
             fprintf('\n[convert_gdf2mat] Failed to convert %s. Error: %s\n', filename, ME.message);
        end
    end

    fprintf('[convert_gdf2mat] Conversion completed.\n');
end