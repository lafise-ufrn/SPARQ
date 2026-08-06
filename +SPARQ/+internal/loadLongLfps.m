function [session, cacheKey, cacheData] = loadLongLfps(source, selector, options, cacheKey, cacheData)
% [session, cacheKey, cacheData] = SPARQ.internal.loadLongLfps(...)
%
% Carrega somente o bloco condicao/sujeito necessario e o reutiliza enquanto
% trials consecutivos compartilham a mesma origem.

    required = {'condition', 'subjectIndex', 'trialIndex'};
    if ~isstruct(selector) || ~all(isfield(selector, required))
        error('SPARQ:io:longlfps:badSelector', ...
            'Use selectors returned by SPARQ.discoverSessions.');
    end
    condition = upper(string(selector.condition));
    if ~ismember(condition, ["A", "V"])
        error('SPARQ:io:longlfps:badCondition', 'Condition must be A or V.');
    end
    subject = double(selector.subjectIndex);
    trial = double(selector.trialIndex);
    newKey = condition + ":" + subject;
    if cacheKey ~= newKey || isempty(cacheData)
        variable = "LFPall" + condition + "trials";
        raw = load(source, 'srate', 'NewAreas', ...
            'GOODTRIALS_A', 'GOODTRIALS_V', 'electLeft', 'electRight');
        file = matfile(source);
        variableInfo = whos(file, char(variable));
        if isempty(variableInfo) || subject < 1 || subject > variableInfo.size(2)
            error('SPARQ:io:longlfps:badSubject', ...
                'subjectIndex is outside the available range.');
        end
        block = file.(char(variable))(:, subject);
        trialCounts = zeros(numel(block), 1);
        for area = 1:numel(block)
            trialCounts(area) = size(block{area}, 1);
        end
        if numel(unique(trialCounts)) ~= 1
            error('SPARQ:io:longlfps:trialCountMismatch', ...
                'Areas contain different numbers of trials for this subject.');
        end
        cacheData.block = block;
        cacheData.samplingRate = raw.srate;
        cacheData.labels = raw.NewAreas;
        cacheData.goodTrials = raw.("GOODTRIALS_" + condition){subject};
        cacheData.electLeft = fieldOr(raw, 'electLeft', []);
        cacheData.electRight = fieldOr(raw, 'electRight', []);
        cacheKey = newKey;
        clear raw file;
    end
    if trial < 1 || trial > size(cacheData.block{1}, 1)
        error('SPARQ:io:longlfps:badTrial', ...
            'trialIndex is outside the available range.');
    end
    nAreas = numel(cacheData.block);
    nSamples = size(cacheData.block{1}, 2);
    lfp = zeros(nAreas, nSamples, 'like', cacheData.block{1});
    for area = 1:nAreas
        if size(cacheData.block{area}, 2) ~= nSamples
            error('SPARQ:io:longlfps:sampleCountMismatch', ...
                'Areas contain different sample counts.');
        end
        lfp(area, :) = cacheData.block{area}(trial, :);
    end
    originalTrial = cacheData.goodTrials(trial);
    metadata.inputAdapter = "longlfps";
    metadata.inputAdapterVersion = "1.0";
    metadata.inputSource = string(source);
    metadata.dataSelector = selector;
    metadata.originalTrial = originalTrial;
    metadata.goodTrials = cacheData.goodTrials;
    metadata.electLeft = cacheData.electLeft;
    metadata.electRight = cacheData.electRight;
    session = SPARQ.createSession(lfp, cacheData.samplingRate, ...
        'ChannelLabels', cacheData.labels, ...
        'SubjectId', optionText(options, 'subjectId', "subject-" + subject), ...
        'SessionId', optionText(options, 'sessionId', ...
        lower(condition) + "-trial-" + originalTrial), ...
        'Condition', optionText(options, 'condition', condition), ...
        'SourceFile', source, ...
        'SignalUnits', optionText(options, 'signalUnits', "arbitrary"), ...
        'SignalScale', SPARQ.internal.inputOption(options, 'signalScale', 1), ...
        'Metadata', metadata);
end

function value = fieldOr(s, name, defaultValue)
    if isfield(s, name), value = s.(name); else, value = defaultValue; end
end

function value = optionText(options, name, defaultValue)
    value = string(SPARQ.internal.inputOption(options, name, defaultValue));
end
