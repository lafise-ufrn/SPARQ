function inventory = inspectSource(source, format, options)
% inventory = SPARQ.internal.inspectSource(source, format, options)

    switch string(format)
        case "realdata"
            inventory = inspectRealData(source);
        case "longlfps"
            inventory = inspectLongLfps(source);
        case "mat"
            inventory = inspectMat(source, options);
        otherwise
            error('SPARQ:io:inspect:unsupportedFormat', ...
                'No MAT inspector is registered for format "%s".', format);
    end
end

function inventory = inspectRealData(source)
    raw = load(source, 'RUN');
    required = {'signal', 'time', 'srate', 'channels'};
    if ~isstruct(raw.RUN) || ~isscalar(raw.RUN) || ...
            ~all(isfield(raw.RUN, required)) || ~iscell(raw.RUN.signal)
        error('SPARQ:io:realdata:badSchema', ...
            'RUN must contain signal, time, srate and channels.');
    end
    n = numel(raw.RUN.signal);
    inventory = repmat(blankInventory(), n, 1);
    for i = 1:n
        speed = NaN;
        if isfield(raw.RUN, 'speed') && numel(raw.RUN.speed) >= i
            speed = raw.RUN.speed(i);
        end
        condition = "session-" + i;
        if isfinite(speed)
            condition = "speed-" + string(speed);
        end
        inventory(i) = makeInventory("", "RUN-" + i, condition, ...
            raw.RUN.srate, struct('kind', "realdata", 'cellIndex', i));
    end
end

function inventory = inspectLongLfps(source)
    raw = load(source, 'srate', 'GOODTRIALS_A', 'GOODTRIALS_V');
    conditions = ["A", "V"];
    goodNames = {'GOODTRIALS_A', 'GOODTRIALS_V'};
    rows = sum(cellfun(@numel, raw.GOODTRIALS_A)) + ...
        sum(cellfun(@numel, raw.GOODTRIALS_V));
    inventory = repmat(blankInventory(), rows, 1);
    out = 0;
    for c = 1:2
        good = raw.(goodNames{c});
        for subject = 1:numel(good)
            trialIds = double(good{subject}(:));
            for trial = 1:numel(trialIds)
                out = out + 1;
                selector = struct('kind', "longlfps", ...
                    'condition', conditions(c), 'subjectIndex', subject, ...
                    'trialIndex', trial, 'originalTrial', trialIds(trial));
                inventory(out) = makeInventory("subject-" + subject, ...
                    lower(conditions(c)) + "-trial-" + trialIds(trial), ...
                    conditions(c), raw.srate, selector);
            end
        end
    end
end

function inventory = inspectMat(source, options)
    path = string(SPARQ.internal.inputOption(options, 'lfpPath', ...
        SPARQ.internal.inputOption(options, 'lfpVariable', "LFP")));
    value = SPARQ.internal.readMatPath(source, path);
    fs = resolveMatSamplingRate(source, options);
    if isnumeric(value) && ismatrix(value)
        inventory = defaultInventory(source, fs, ...
            struct('kind', "matrix", 'lfpPath', path));
    elseif isnumeric(value) && ndims(value) == 3
        trialDimension = SPARQ.internal.inputOption(options, 'trialDimension', 3);
        if ~isscalar(trialDimension) || ~ismember(trialDimension, 1:3)
            error('SPARQ:io:mat:badTrialDimension', ...
                'trialDimension must be 1, 2 or 3.');
        end
        n = size(value, trialDimension);
        inventory = repmat(blankInventory(), n, 1);
        for i = 1:n
            inventory(i) = makeInventory("", "trial-" + i, "", fs, ...
                struct('kind', "mat3d", 'lfpPath', path, ...
                'trialDimension', trialDimension, 'trialIndex', i));
        end
    elseif iscell(value)
        valid = find(cellfun(@(x) isnumeric(x) && ismatrix(x) && ~isempty(x), value));
        inventory = repmat(blankInventory(), numel(valid), 1);
        for i = 1:numel(valid)
            subs = cell(1, ndims(value));
            [subs{:}] = ind2sub(size(value), valid(i));
            inventory(i) = makeInventory("", "cell-" + valid(i), "", fs, ...
                struct('kind', "matcell", 'lfpPath', path, ...
                'linearIndex', valid(i), 'subscripts', [subs{:}]));
        end
    else
        error('SPARQ:io:mat:unsupportedLayout', ...
            'Mapped LFP data must be a numeric 2-D/3-D array or a cell array of matrices.');
    end
end

function fs = resolveMatSamplingRate(source, options)
    fs = SPARQ.internal.inputOption(options, 'samplingRateHz', NaN);
    path = string(SPARQ.internal.inputOption(options, 'samplingRatePath', ...
        SPARQ.internal.inputOption(options, 'samplingRateVariable', "")));
    if ~isempty(fs) && isscalar(fs) && isfinite(fs)
        return;
    end
    if strlength(path) > 0
        fs = SPARQ.internal.readMatPath(source, path);
    else
        fs = NaN;
    end
end

function inventory = defaultInventory(source, fs, selector)
    [~, stem] = fileparts(source);
    inventory = makeInventory("", string(stem), "", fs, selector);
end

function row = makeInventory(subject, session, condition, fs, selector)
    row = blankInventory();
    row.SubjectId = char(subject);
    row.SessionId = char(session);
    row.Condition = char(condition);
    row.SamplingRateHz = double(fs);
    row.DataSelector = selector;
end

function row = blankInventory()
    row.SubjectId = '';
    row.SessionId = '';
    row.Condition = '';
    row.SamplingRateHz = NaN;
    row.DataSelector = struct();
end
