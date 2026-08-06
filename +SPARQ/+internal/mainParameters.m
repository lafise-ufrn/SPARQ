function params = mainParameters(session, config)
% params = SPARQ.internal.mainParameters(session, config)
%
% Constroi os parametros genericos de uma sessao e aplica somente as
% sobrescritas explicitamente preenchidas no bloco editavel de main.m.

    params = SPARQ.processingOptions(size(session.lfp, 1));
    params.channels.excluded = config.excludedChannels(:).';
    if isempty(config.detection.minSimultaneousChannels)
        params.detection.minSimultaneousChannels = min( ...
            params.detection.minSimultaneousChannels, ...
            params.channels.count - numel(params.channels.excluded));
    end

    fields = {'thresholdStd', 'minSimultaneousChannels', 'mergeGapSamples', ...
        'settleWindowSamples', 'settleToleranceStd'};
    for i = 1:numel(fields)
        field = fields{i};
        value = config.detection.(field);
        if ~isempty(value)
            params.detection.(field) = value;
        end
    end

    params.output.includeConcat = config.output.includeConcat;
    params.output.includeNaN = config.output.includeNaN;
    params.plot.enabled = config.plot.enabled;
    params.plot.thresholdStd = params.detection.thresholdStd;
    SPARQ.internal.validateParameters(params);
end
