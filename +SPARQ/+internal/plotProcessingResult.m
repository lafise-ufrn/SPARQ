function plotProcessingResult(session, result, params, maxDisplayPoints)
% SPARQ.internal.plotProcessingResult(session, result, params, maxDisplayPoints)
%
% Desenha as tres figuras posteriores a selecao da referencia para o fluxo
% generico: limites por canal, ruido cross-channel e resumo de preservacao.
% Quando solicitadas, acrescenta as figuras do sinal concatenado e/ou com NaN.

    if ~params.plot.enabled
        return;
    end
    if nargin < 4 || isempty(maxDisplayPoints)
        maxDisplayPoints = Inf;
    end

    tags = SPARQ.internal.figureTags();
    thresholdFigure = SPARQ.internal.getOrCreateFigure(tags.thresholds);
    thresholdAxes = axes('Parent', thresholdFigure);
    SPARQ.viz.channels(session, params, thresholdAxes, ...
        'MaxDisplayPoints', maxDisplayPoints);
    SPARQ.viz.withThresholds(thresholdAxes, session, result.noise, params);

    noiseFigure = SPARQ.internal.getOrCreateFigure(tags.noiseWindows);
    noiseAxes = axes('Parent', noiseFigure);
    SPARQ.viz.channels(session, params, noiseAxes, ...
        'MaxDisplayPoints', maxDisplayPoints);
    SPARQ.viz.withThresholds(noiseAxes, session, result.noise, params);
    SPARQ.viz.withNoiseWindows(noiseAxes, session, result.noise, params);
    SPARQ.internal.highlightNoiseTraces( ...
        noiseAxes, session, result.noise, params);
    title(noiseAxes, sprintf('%s - Cross-Channel Noise Windows', ...
        SPARQ.internal.sessionTitle(session, params)));

    summaryFigure = SPARQ.internal.getOrCreateFigure(tags.summary);
    summaryAxes = axes('Parent', summaryFigure);
    SPARQ.viz.preservationSummary(result.noise, ...
        SPARQ.internal.sessionTitle(session, params), summaryAxes);

    plotOptionalSignal(session, result, params, maxDisplayPoints, ...
        tags.concat, 'concat');
    plotOptionalSignal(session, result, params, maxDisplayPoints, ...
        tags.nan, 'nan');
end

% ------------------------------------------------------------------------
function plotOptionalSignal(session, result, params, maxDisplayPoints, ...
        figureTag, representation)
    hasRepresentation = isfield(result, 'cleanSignals') && ...
        isfield(result.cleanSignals, representation);
    if ~hasRepresentation
        staleFigures = findall(groot, 'Type', 'figure', 'Tag', figureTag);
        delete(staleFigures);
        return;
    end

    signalFigure = SPARQ.internal.getOrCreateFigure(figureTag);
    signalAxes = axes('Parent', signalFigure);
    SPARQ.internal.plotCleanSignal(signalAxes, session, result, params, ...
        representation, maxDisplayPoints);
end
