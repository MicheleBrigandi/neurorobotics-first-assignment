function print_metrics(all_stats, selected_indices)

    if isempty(all_stats)
        fprintf('No stats available to print.\n');
        return;
    end

    fprintf('%-15s | %-8s | %-8s | %-8s | %-8s | %-12s\n', ...
            'Subject ID', 'Max FS', 'Mean FS', 'Peak ERD', 'LI', 'Best F-C');

    fprintf('%s\n', repmat('-', 1, 70));

    for i = 1:length(selected_indices)
        idx = selected_indices(i);
        s = all_stats(idx);
        
     
        clean_id = strrep(s.id, '_micontinuous', '');
        

        if isfield(s, 'bestFreq') && isfield(s, 'bestChan')
            best_feat = sprintf('%.1fHz-%s', s.bestFreq, s.bestChan);
        else
            best_feat = 'N/A';
        end

        fprintf('%-15s | %-8.4f | %-8.4f | %-8.2f | %-8.2f | %-12s\n', ...
                clean_id, s.maxFS, s.meanFS, s.peakERD, s.LI, best_feat);
    end
    fprintf('%s\n', repmat('-', 1, 70));
    fprintf('Note: FS = Fisher Score (squared), ERD = Peak Log-ratio at cue phase.\n\n');
end