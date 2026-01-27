function visualize_features(s, cfg)
    
    prefix = strrep(s.id, '_micontinuous', '');
    out_dir = fullfile(cfg.paths.results, prefix);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir); 
    end
    load(cfg.files.chanlocs, 'chanlocs16');

    % Topoplot: Hands, Feet, Fisher
    plot_data = {s.hands_map, s.feet_map, mean(s.full_data.fisher_map, 1)'};
    titles = {'Both Hands (773)', 'Both Feet (771)', 'Fisher Map'};
    tags = {'HandsERD', 'FeetERD', 'FisherMap'};

    for i = 1:3
        figure('Color', 'w', 'Visible', 'off');
        topoplot(plot_data{i}, chanlocs16, 'style', 'both', 'colormap', jet);
        colorbar; 
        title([prefix ' - ' titles{i}], 'Interpreter', 'none');
        saveas(gcf, fullfile(out_dir, [s.type '_' tags{i} '.png']));
        close(gcf);
    end

    % ERD Curve
    figure('Color', 'w', 'Visible', 'off'); 
    hold on;
    plot(s.t_axis, s.curve_h, 'r', 'LineWidth', 1.5, 'DisplayName', 'C3 (Hands)');
    plot(s.t_axis, s.curve_f, 'b', 'LineWidth', 1.5, 'DisplayName', 'Cz (Feet)');
    xline(1.0, '--k', 'Cue');
    xlabel('Time (s)'); 
    ylabel('Log Power Ratio'); 
    title([prefix ' - ERD Curves']);
    legend; 
    grid on;
    saveas(gcf, fullfile(out_dir, [s.type '_ERD_Curve.png']));
    close(gcf);
end