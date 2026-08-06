function axesHandle = highlightNoiseTraces(axesHandle, session, noise, params)
% axesHandle = SPARQ.internal.highlightNoiseTraces(...)
%
% Sobrepoe em vermelho as amostras pertencentes a janelas de ruido
% cross-channel. Esta funcao e exclusivamente visual e nao recalcula janelas.

    layout = SPARQ.internal.plotLayout(session, params);
    hold(axesHandle, 'on');
    for windowIndex = 1:size(noise.windows, 1)
        indices = noise.windows(windowIndex, 1):noise.windows(windowIndex, 2);
        for channelIndex = 1:numel(layout.channels)
            channel = layout.channels(channelIndex);
            trace = session.lfp(channel, indices) + ...
                layout.offsets(channelIndex);
            plot(axesHandle, session.time(indices), trace, ...
                'Color', [1 0 0], 'LineWidth', 1);
        end
    end
end
