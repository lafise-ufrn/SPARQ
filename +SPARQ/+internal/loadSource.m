function session = loadSource(source, format, selector, options)
% session = SPARQ.internal.loadSource(source, format, selector, options)

    switch string(format)
        case "realdata"
            session = loadRealData(source, selector, options);
        case "mat"
            session = loadMappedMat(source, selector, options);
        otherwise
            error('SPARQ:io:load:unsupportedFormat', ...
                'No MAT loader is registered for format "%s".', format);
    end
end

function session = loadRealData(source, selector, options)
    requireSelector(selector, 'cellIndex', 'realdata');
    raw = load(source, 'RUN');
    index = selector.cellIndex;
    if index < 1 || index > numel(raw.RUN.signal)
        error('SPARQ:io:realdata:badSelector', ...
            'RUN cellIndex is outside the available range.');
    end
    speed = NaN;
    if isfield(raw.RUN, 'speed') && numel(raw.RUN.speed) >= index
        speed = raw.RUN.speed(index);
    end
    metadata = provenance("realdata", source, selector, options);
    metadata.speed = speed;
    metadata.sourceCellIndex = index;
    defaultCondition = "session-" + index;
    if isfinite(speed), defaultCondition = "speed-" + speed; end
    condition = optionText(options, 'condition', defaultCondition);
    session = SPARQ.createSession(raw.RUN.signal{index}, raw.RUN.srate, ...
        'Time', raw.RUN.time{index}, 'ChannelLabels', raw.RUN.channels, ...
        'SubjectId', optionText(options, 'subjectId', ""), ...
        'SessionId', optionText(options, 'sessionId', "RUN-" + index), ...
        'Condition', condition, 'SourceFile', source, ...
        'SignalUnits', optionText(options, 'signalUnits', "arbitrary"), ...
        'SignalScale', optionNumeric(options, 'signalScale', 1), ...
        'Metadata', metadata);
end

function session = loadMappedMat(source, selector, options)
    if isempty(fieldnames(selector)) && ~isfield(options, 'lfpPath')
        legacyOptions = removeFields(options, {'inputFormat', 'dataSelector'});
        session = SPARQ.io.loadMat(source, legacyOptions);
        return;
    end
    path = string(fieldOr(selector, 'lfpPath', ...
        SPARQ.internal.inputOption(options, 'lfpPath', ...
        SPARQ.internal.inputOption(options, 'lfpVariable', "LFP"))));
    value = SPARQ.internal.readMatPath(source, path);
    kind = string(fieldOr(selector, 'kind', "matrix"));
    switch kind
        case "matrix"
            lfp = value;
        case "mat3d"
            dim = selector.trialDimension;
            subs = repmat({':'}, 1, 3);
            subs{dim} = selector.trialIndex;
            lfp = squeeze(value(subs{:}));
        case "matcell"
            lfp = value{selector.linearIndex};
        otherwise
            error('SPARQ:io:mat:badSelector', ...
                'Unknown MAT selector kind "%s".', kind);
    end
    fs = resolveMappedValue(source, options, selector, ...
        'samplingRateHz', 'samplingRatePath', 'samplingRateVariable', NaN);
    if ~isnumeric(fs) || ~isscalar(fs) || ~isfinite(fs) || fs <= 0
        error('SPARQ:io:mat:missingSamplingRate', ...
            'Provide samplingRateHz or a valid sampling-rate path.');
    end
    time = resolveMappedValue(source, options, selector, ...
        '', 'timePath', 'timeVariable', []);
    labels = resolveMappedValue(source, options, selector, ...
        '', 'channelLabelsPath', 'channelLabelsVariable', []);
    events = resolveMappedValue(source, options, selector, ...
        '', 'eventsPath', 'eventsVariable', []);
    metadata = provenance("mat", source, selector, options);
    metadata.mappedLfpPath = path;
    session = createCanonical(lfp, fs, time, labels, events, source, options, metadata);
end

function session = createCanonical(lfp, fs, time, labels, events, source, options, metadata)
    session = SPARQ.createSession(lfp, fs, ...
        'DataOrientation', optionText(options, 'dataOrientation', "channels-by-samples"), ...
        'Time', time, 'ChannelLabels', labels, ...
        'SubjectId', optionText(options, 'subjectId', ""), ...
        'SessionId', optionText(options, 'sessionId', ""), ...
        'Condition', optionText(options, 'condition', ""), ...
        'Events', events, 'SourceFile', source, ...
        'SignalUnits', optionText(options, 'signalUnits', "arbitrary"), ...
        'SignalScale', optionNumeric(options, 'signalScale', 1), ...
        'Metadata', metadata);
end

function value = resolveMappedValue(source, options, selector, numericName, pathName, legacyName, defaultValue)
    if strlength(string(numericName)) > 0 && isfield(options, numericName) && ...
            ~isempty(options.(numericName))
        value = options.(numericName);
        return;
    end
    path = string(SPARQ.internal.inputOption(options, pathName, ...
        SPARQ.internal.inputOption(options, legacyName, "")));
    if strlength(path) == 0
        value = defaultValue;
        return;
    end
    value = SPARQ.internal.readMatPath(source, path);
    if iscell(value) && isfield(selector, 'linearIndex') && numel(value) >= selector.linearIndex
        value = value{selector.linearIndex};
    elseif isnumeric(value) && ndims(value) == 3 && isfield(selector, 'trialIndex')
        dim = selector.trialDimension;
        subs = repmat({':'}, 1, 3);
        subs{dim} = selector.trialIndex;
        value = squeeze(value(subs{:}));
    end
end

function metadata = provenance(adapter, source, selector, options)
    metadata.inputAdapter = string(adapter);
    metadata.inputAdapterVersion = "1.0";
    metadata.inputSource = string(source);
    metadata.dataSelector = selector;
    metadata.loaderOptions = options;
end

function value = fieldOr(s, name, defaultValue)
    if isfield(s, name), value = s.(name); else, value = defaultValue; end
end

function value = optionText(options, name, defaultValue)
    value = string(SPARQ.internal.inputOption(options, name, defaultValue));
end

function value = optionNumeric(options, name, defaultValue)
    value = SPARQ.internal.inputOption(options, name, defaultValue);
end

function requireSelector(selector, field, format)
    if ~isstruct(selector) || ~isscalar(selector) || ~isfield(selector, field)
        error('SPARQ:io:badSelector', ...
            '%s MAT input requires selector.%s. Use discoverSessions.', format, field);
    end
end

function output = removeFields(input, names)
    output = input;
    for i = 1:numel(names)
        if isfield(output, names{i})
            output = rmfield(output, names{i});
        end
    end
end
