function axesHandle = plotCleanSignal(axesHandle, session, result, params, ...
        representation, maxDisplayPoints)
% axesHandle = SPARQ.internal.plotCleanSignal(...)
%
% Desenha uma representacao opcional ja calculada por buildCleanSignals.
% Esta funcao e exclusivamente visual: nao recalcula mascara, janelas ou sinal.

    representation = char(string(representation));
    clean = result.cleanSignals;
    signal = clean.(representation);
    channels = clean.channels(:).';
    areas = string(clean.areas(:));
    spacing = params.plot.channelSpacing;
    offsets = (0:numel(channels) - 1) * spacing;

    if strcmp(representation, 'concat')
        x = 1:size(signal, 2);
        xLabel = 'Indice da amostra preservada (nao e tempo continuo)';
        plotTitle = 'Sinal concatenado - emendas nao representam tempo continuo';
    else
        x = session.time;
        xLabel = 'Time (s)';
        plotTitle = 'Sinal com intervalos de ruido substituidos por NaN';
    end

    hold(axesHandle, 'on');
    for row = 1:size(signal, 1)
        trace = signal(row, :) + offsets(row);
        [xToPlot, traceToPlot] = SPARQ.internal.reduceTraceForDisplay( ...
            x, trace, maxDisplayPoints);
        plot(axesHandle, xToPlot, traceToPlot);
    end

    if strcmp(representation, 'concat') && isfield(clean, 'concatEdges')
        for edge = clean.concatEdges(:).'
            xline(axesHandle, edge + 0.5, ':', 'Color', [0.45 0.45 0.45], ...
                'LineWidth', 0.75);
        end
    end
    hold(axesHandle, 'off');

    xlabel(axesHandle, xLabel);
    ylabel(axesHandle, 'Channel');
    set(axesHandle, 'YTick', offsets, 'YTickLabel', cellstr(areas));
    set(axesHandle, 'YDir', 'reverse');
    ylim(axesHandle, [-spacing, offsets(end) + spacing]);
    if isempty(x)
        xlim(axesHandle, [0.5 1.5]);
        text(axesHandle, 1, mean(ylim(axesHandle)), ...
            'Nenhuma amostra preservada', 'HorizontalAlignment', 'center');
    elseif isscalar(x)
        xlim(axesHandle, [x(1) - 0.5, x(1) + 0.5]);
    else
        xlim(axesHandle, [x(1), x(end)]);
    end
    title(axesHandle, {SPARQ.internal.sessionTitle(session, params), ...
        plotTitle});
end
