function compute_psd(input_dir, output_dir, laplacian_path, cfg)
% COMPUTE_PSD Computes Power Spectral Density (PSD) for single EEG runs.
%
% This function iterates over raw .mat files, applies a spatial Laplacian 
% filter, computes the spectrogram, and saves the resulting features (PSD) 
% into new .mat files.
%
% INPUTS:
%   input_dir      - Folder containing raw .mat files.
%   output_dir     - Folder where processed PSD files will be saved.
%   laplacian_path - Path to the file containing Laplacian mask.
%   cfg            - Config struct with spectrogram parameters (.spec).
%
% OUTPUTS:
%   None. Files are saved to disk with the following variables:
%     - PSD:      [Windows x Freqs x Channels] Power Spectral Density matrix.
%     - freqs:    [Freqs x 1] Vector of frequency bins.
%     - Events:   Struct (TYP, POS, DUR) aligned to spectrogram windows.
%     - chanlabs: Cell array of channel labels.
%     - cfg:      Configuration used for processing.

    %% Input Validation
    if ~exist(output_dir, 'dir') 
        mkdir(output_dir); 
    end
    
    if ~exist(laplacian_path, 'file')
        error('[compute_psd] Laplacian file not found: %s\n', laplacian_path);
    end
    load(laplacian_path, 'lap'); 

    files = dir(fullfile(input_dir, '*.mat'));
    if isempty(files)
        warning('[compute_psd] No .mat files found in %s\n', input_dir);
        return;
    end
    
    fprintf('[compute_psd] Found %d files. Starting PSD computation...\n', length(files));

    %% Processing Loop
    for i = 1:length(files)
        filename = files(i).name;
        full_path = fullfile(input_dir, filename);
        
        try
            % Load raw data
            tmp = load(full_path); 
            
            % Spatial filtering
            n_lap_channels = size(lap, 1);
            if size(tmp.data, 2) < n_lap_channels
                warning('Skipping %s: Not enough channels.\n', filename);
                continue;
            end
            
            s_eeg = tmp.data(:, 1:n_lap_channels); 
            s_lap = s_eeg * lap;
            
            % Copy labels
            if isfield(tmp, 'chanlabs')
                chanlabs = tmp.chanlabs(1:n_lap_channels);
            else
                chanlabs = {}; 
            end

            % Spectrogram
            [PSD_full, f_full] = proc_spectrogram(s_lap, ...
                                        cfg.spec.wlength, ...
                                        cfg.spec.wshift, ...
                                        cfg.spec.pshift, ...
                                        tmp.fs, ...
                                        cfg.spec.mlength);
            
            % Feature selection
            freq_idx = f_full >= cfg.spec.freq_band(1) & f_full <= cfg.spec.freq_band(2);
            
            PSD = PSD_full(:, freq_idx, :);
            freqs = f_full(freq_idx);        
            
            % Event realignment
            wshift_samples  = cfg.spec.wshift * tmp.fs;
            wlength_samples = cfg.spec.wlength * tmp.fs;
            winconv = 'backward'; 
            
            Events.POS = proc_pos2win(tmp.events.POS, wshift_samples, winconv, wlength_samples);
            Events.DUR = ceil(tmp.events.DUR / wshift_samples);
            Events.TYP = tmp.events.TYP;
            
            % Save processed data
            [~, name_no_ext, ~] = fileparts(filename);
            out_name = fullfile(output_dir, [name_no_ext '.mat']);
            
            % Save variables
            save(out_name, 'PSD', 'freqs', 'Events', 'chanlabs', 'cfg');
            
        catch ME
            fprintf('[compute_psd] Error processing %s: %s\n', filename, ME.message);
        end
    end
end