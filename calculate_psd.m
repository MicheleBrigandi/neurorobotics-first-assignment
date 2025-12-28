% Script to process the entire concatenated EEG data

% Load Laplacian mask and concatenated data
load('laplacian16.mat');


data_dir = 'data'; % Specify the data directory
all_gdf_files = dir(fullfile(data_dir, '**', '*offline*.mat'));
files = cell(1, length(all_gdf_files));
for i = 1:length(all_gdf_files)
    files{i} = fullfile(all_gdf_files(i).folder, all_gdf_files(i).name);
end

all_PSD = [];
PSD_TYP = [];
PSD_DUR = [];
PSD_POS = [];
current_pos_offset = 0;

for i = 1:length(files)
    load(files{i});
    s = data(:, 1:16);

    % Apply the Laplacian filter
    s_lap = s * lap;
    % TODO: consider other filters
    
    % Parameters
    samplerate = 512; % Assuming 512 Hz for the concatenated data
    wlength = 0.5;    % seconds. Length of the external window
    pshift = 0.25;    % seconds. Shift of the internal windows
    wshift = 0.0625;  % seconds. Shift of the external window
    mlength = 1;      % seco
    
    % Compute PSD over time
    fprintf('Computing spectrogram\n');
    [PSD, f] = proc_spectrogram(s_lap, wlength, wshift, pshift, samplerate, mlength);
    
    % Select a subset of frequencies (4 Hz to 48 Hz, step 2 Hz)
    freq_range = 4:2:48;
    [~, freq_idx] = ismember(freq_range, f);
    freq_idx(freq_idx == 0) = []; % Remove indices for frequencies not found
    
    %PSD_selected = PSD(:, freq_idx, :);
    PSD_selected = PSD(:, freq_idx, :);
    f_selected = f(freq_idx);
    
    % Recompute event positions for the concatenated data
    winconv = 'backward';
    POS_win = proc_pos2win(POS, wshift*samplerate, winconv, wlength*samplerate);
    DUR_win = ceil(DUR / (wshift*samplerate));
    
    offset = current_pos_offset;

    % Create a new events structure for the windowed data
    all_PSD = [all_PSD; PSD_selected];
    PSD_TYP = [PSD_TYP; TYP];
    PSD_POS = [PSD_POS; POS_win + current_pos_offset];
    PSD_DUR = [PSD_DUR; DUR_win];
    
    current_pos_offset = current_pos_offset + size(PSD_selected, 1);

    if i == 3
        break;
    end
end
% Save the results to a .mat file

save_filename = 'data_PSD.mat';
save(save_filename, 'all_PSD', 'PSD_TYP', 'PSD_POS', 'PSD_DUR');

fprintf('Saved processed data to %s\n', save_filename);
fprintf('All data processed.\n');
