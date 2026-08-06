function [timeToPlot, signalToPlot] = reduceTraceForDisplay(time, signal, maxPoints)
% [timeToPlot, signalToPlot] = SPARQ.internal.reduceTraceForDisplay(...)
%
% Reduz somente os vertices desenhados por um envelope minimo/maximo. Os
% dados usados pelo detector nunca passam por esta funcao.

    time = double(time(:).');
    signal = signal(:).';
    nSamples = numel(time);
    if isinf(maxPoints) || nSamples <= maxPoints
        timeToPlot = time;
        signalToPlot = signal;
        return;
    end

    nBins = max(1, floor(maxPoints / 3));
    edges = round(linspace(1, nSamples + 1, nBins + 1));
    timeToPlot = nan(1, 3 * nBins);
    signalToPlot = nan(1, 3 * nBins);
    for bin = 1:nBins
        indices = edges(bin):edges(bin + 1) - 1;
        base = 3 * (bin - 1);
        midpoint = (time(indices(1)) + time(indices(end))) / 2;
        timeToPlot(base + (1:2)) = [midpoint, midpoint];
        signalToPlot(base + (1:2)) = ...
            [min(signal(indices)), max(signal(indices))];
    end
end
