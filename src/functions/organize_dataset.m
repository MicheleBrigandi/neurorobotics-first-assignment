function organize_dataset(source_dir)
% ORGANISE_DATASET Automatically sorts raw GDF files into pipeline folders.
%
% This function recursively scans a source directory and sorts files into 
% offline/online folders based on their filenames.
%
% INPUTS:
%   source_dir (Optional) - String path to the downloaded dataset.
%                           If not provided, uses cfg.paths.downloads.
%
% USAGE:
%   organize_dataset();                   % Uses default config path
%   organize_dataset('C:/Downloads/EEG'); % Uses custom path

    %% Configuration
    % Load configuration to get destination paths
    if evalin('base', 'exist(''cfg'',''var'')')
        cfg = evalin('base', 'cfg');
    else
        cfg = get_config();
    end

    % Handle input argument
    if nargin < 1 || isempty(source_dir)
        source_dir = cfg.paths.downloads;
    end

    % Define destinations
    dest_offline = cfg.paths.raw_offline;
    dest_online  = cfg.paths.raw_online;

    % Validation
    if ~exist(source_dir, 'dir')
        warning('Source directory "%s" not found. Skipping organisation.', source_dir);
        return;
    end

    % Ensure destination directories exist
    if ~exist(dest_offline, 'dir'), mkdir(dest_offline); end
    if ~exist(dest_online, 'dir'),  mkdir(dest_online);  end

    %% File Discovery
    fprintf('Scanning for GDF files in: %s ...\n', source_dir);
    
    % Recursively find all .gdf files
    all_files = dir(fullfile(source_dir, '**', '*.gdf'));
    
    if isempty(all_files)
        warning('No GDF files found. Check if the dataset is extracted.');
        return;
    end

    %% Sorting
    count_off = 0;
    count_on  = 0;
    
    fprintf('Found %d files. Sorting...\n', length(all_files));
    
    for i = 1:length(all_files)
        filename = all_files(i).name;
        full_source_path = fullfile(all_files(i).folder, filename);
        
        % Check if the file is offline or online using case-insensitive search
        is_offline = contains(filename, 'offline', 'IgnoreCase', true);
        is_online  = contains(filename, 'online',  'IgnoreCase', true);
        
        target_path = '';
        
        if is_offline
            target_path = fullfile(dest_offline, filename);
            count_off = count_off + 1;
            type_str = '[OFFLINE]';
        elseif is_online
            target_path = fullfile(dest_online, filename);
            count_on = count_on + 1;
            type_str = '[ONLINE]';
        else
            fprintf('[SKIP] Unclassified file: %s\n', filename);
            continue;
        end
        
        % Copy
        if ~exist(target_path, 'file')
            copyfile(full_source_path, target_path);
            fprintf('%s Copied: %s\n', type_str, filename);
        end
    end
    
    %% Final Summary
    fprintf('--- Organisation Complete ---\n');
    fprintf('New files in offline: %d\n', count_off);
    fprintf('New files in online: %d\n', count_on);
end

