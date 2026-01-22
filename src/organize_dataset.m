function organize_dataset(source_dir, output_root_dir)
% ORGANISE_DATASET Sorts raw GDF files into a subject-specific structure.
%
% This function scans the source directory, identifies the subject ID from 
% the filename, and copies files into a structured hierarchy:
%   <output_root_dir>/<subject_id>/offline/
%   <output_root_dir>/<subject_id>/online/
%
% INPUTS:
%   source_dir      - String path to the downloaded dataset (source).
%   output_root_dir - String path to the root raw data folder (destination).
%
% USAGE:
%   organize_dataset(cfg.paths.downloads, fullfile(cfg.paths.data, 'raw'));

    %% Input Validation
    if nargin < 2
        error('[organize_dataset] Error: Both source_dir and output_root_dir must be provided.');
    end

    if ~exist(source_dir, 'dir')
        warning('[organize_dataset] Source directory "%s" not found.', source_dir);
        return;
    end

    % Ensure the output root exists
    if ~exist(output_root_dir, 'dir')
        mkdir(output_root_dir);
    end
    
    % Recursively find all .gdf files
    all_files = dir(fullfile(source_dir, '**', '*.gdf'));
    
    if isempty(all_files)
        warning('[organize_dataset] No GDF files found.');
        return;
    end

    %% Sorting Procedure
    count_files = 0;
    fprintf('[organize_dataset] Found %d files. Starting sorting...\n', length(all_files));
    
    for i = 1:length(all_files)
        filename = all_files(i).name;
        full_source_path = fullfile(all_files(i).folder, filename);
        
        % Extract subject ID
        % Assumption: filename format is 'subjectID.date.time.type...' 
        tokens = strsplit(filename, '.');
        if isempty(tokens)
            fprintf('[organize_dataset] [SKIP] Could not parse filename: %s\n', filename);
            continue;
        end
        subject_id = tokens{1};
        
        % Determine run type
        if contains(filename, 'offline', 'IgnoreCase', true)
            run_type = 'offline';
        elseif contains(filename, 'online', 'IgnoreCase', true)
            run_type = 'online';
        else
            fprintf('[organize_dataset] [SKIP] Unclassified run type: %s\n', filename);
            continue;
        end
        
        % Construct subject-specific destination path
        target_dir = fullfile(output_root_dir, subject_id, run_type);
        target_path = fullfile(target_dir, filename);
        
        % Ensure the target directory exists
        if ~exist(target_dir, 'dir')
            mkdir(target_dir);
        end
        
        % Copy file
        if ~exist(target_path, 'file')
            copyfile(full_source_path, target_path);
            count_files = count_files + 1;
        end
    end
    
    %% Final Summary
    fprintf('[organize_dataset] Organisation complete.\n');
    fprintf('[organize_dataset] Total files organised: %d\n', count_files);
    fprintf('[organize_dataset] Data structure ready at: %s\n', output_root_dir);
end