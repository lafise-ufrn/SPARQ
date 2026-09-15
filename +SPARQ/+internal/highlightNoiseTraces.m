function axesHandle = highlightNoiseTraces(axesHandle, session, noise, params, varargin)
% axesHandle = SPARQ.internal.highlightNoiseTraces(...)
%
% Sobrepoe em vermelho as amostras pertencentes a janelas de ruido
% cross-channel. Esta funcao e exclusivamente visual e nao recalcula janelas.

    parser = inputParser();
    parser.FunctionName = 'SPARQ.internal.highlightNoiseTraces';
    addParameter(parser, 'MaxDisplayPoints', Inf, ...
        @(x) isnumeric(x) && isreal(x) && isscalar(x) && ...
        ((isfinite(x) && x >= 100 && x == round(x)) || ...
         (isinf(x) && x > 0)));
    parse(parser, varargin{:});

    layout = SPARQ.internal.plotLayout(session, params);
    hold(axesHandle, 'on');
    nWindows = size(noise.windows, 1);
    if nWindows == 0
        return;
    end
    pointsPerWindow = parser.Results.MaxDisplayPoints;
    if isfinite(pointsPerWindow)
        pointsPerWindow = max(100, floor(pointsPerWindow / nWindows));
    end
    for channelIndex = 1:numel(layout.channels)
        plottedTime = cell(1, nWindows);
        plottedTrace = cell(1, nWindows);
        for windowIndex = 1:nWindows
            indices = noise.windows(windowIndex, 1):noise.windows(windowIndex, 2);
            channel = layout.channels(channelIndex);
            trace = session.lfp(channel, indices) + ...
                layout.offsets(channelIndex);
            [windowTime, windowTrace] = SPARQ.internal.reduceTraceForDisplay( ...
                session.time(indices), trace, pointsPerWindow);
            plottedTime{windowIndex} = [windowTime, NaN];
            plottedTrace{windowIndex} = [windowTrace, NaN];
        end
        plot(axesHandle, [plottedTime{:}], [plottedTrace{:}], ...
            'Color', [1 0 0], 'LineWidth', 1);
    end
end
