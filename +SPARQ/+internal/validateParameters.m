function validateParameters(params)
% SPARQ.internal.validateParameters(params)
%
% Valida integralmente a estrutura de parametros antes do processamento:
% esquema de campos, tipos, dimensoes, faixas e consistencia entre grupos.
% Campos ausentes, desconhecidos ou digitados incorretamente falham aqui com
% um identificador.

    if ~isstruct(params) || ~isscalar(params)
        error('SPARQ:validateParameters:notStruct', ...
            'params must be a scalar struct.');
    end
    expectedSchema = SPARQ.profiles.esteiraOdor();
    hasAcquisition = isfield(params, 'acquisition') && ...
        isstruct(params.acquisition) && isscalar(params.acquisition);
    usesDeprecatedSubjectField = hasAcquisition && ...
        isfield(params.acquisition, 'legacyRatIds') && ...
        ~isfield(params.acquisition, 'legacySubjectIds');
    if usesDeprecatedSubjectField
        expectedSchema.acquisition.legacyRatIds = ...
            expectedSchema.acquisition.legacySubjectIds;
        expectedSchema.acquisition = rmfield( ...
            expectedSchema.acquisition, 'legacySubjectIds');
    end
    validateSchema(params, expectedSchema, 'params');

    mustBePositiveScalar(params.detection.thresholdStd, 'detection.thresholdStd');
    mustBePositiveScalar(params.detection.settleToleranceStd, ...
        'detection.settleToleranceStd');
    mustBePositiveIntScalar(params.detection.minSimultaneousChannels, ...
        'detection.minSimultaneousChannels');
    mustBePositiveIntScalar(params.detection.mergeGapSamples, ...
        'detection.mergeGapSamples');
    mustBePositiveIntScalar(params.detection.settleWindowSamples, ...
        'detection.settleWindowSamples');

    mustBePositiveIntScalar(params.channels.count, 'channels.count');
    excluded = params.channels.excluded;
    if ~isnumeric(excluded) || ~isreal(excluded) || ...
            (~isempty(excluded) && (~isvector(excluded) || ...
            any(~isfinite(excluded)) || any(excluded ~= round(excluded)) || ...
            any(excluded < 1) || any(excluded > params.channels.count) || ...
            numel(unique(excluded)) ~= numel(excluded)))
        error('SPARQ:validateParameters:badExcluded', ...
            ['channels.excluded must contain unique integer indices in the ' ...
             'range 1..channels.count (%d).'], params.channels.count);
    end
    validCount = params.channels.count - numel(excluded);
    if validCount < 1
        error('SPARQ:validateParameters:noValidChannels', ...
            'channels.excluded removes every acquired channel.');
    end
    if params.detection.minSimultaneousChannels > validCount
        error('SPARQ:validateParameters:tooManyChannels', ...
            ['detection.minSimultaneousChannels (%d) exceeds the number of ' ...
             'valid channels (%d). No sample could ever be flagged as noise.'], ...
            params.detection.minSimultaneousChannels, validCount);
    end

    checkEventIndex(params.channels.referenceEventStart, ...
        'channels.referenceEventStart');
    checkEventIndex(params.channels.referenceEventEnd, ...
        'channels.referenceEventEnd');
    if params.channels.referenceEventEnd < params.channels.referenceEventStart
        error('SPARQ:validateParameters:reversedEventRange', ...
            'channels.referenceEventEnd must not precede referenceEventStart.');
    end

    if usesDeprecatedSubjectField
        legacySubjectIds = params.acquisition.legacyRatIds;
        legacySubjectField = 'acquisition.legacyRatIds';
    else
        legacySubjectIds = params.acquisition.legacySubjectIds;
        legacySubjectField = 'acquisition.legacySubjectIds';
    end
    validateTextVector(legacySubjectIds, legacySubjectField, true);
    mustBePositiveScalar(params.acquisition.legacySamplingRate, ...
        'acquisition.legacySamplingRate');
    mustBePositiveScalar(params.acquisition.samplingRate, ...
        'acquisition.samplingRate');

    names = validateTextVector(params.conditions.names, 'conditions.names', false);
    displayNames = validateTextVector(params.conditions.displayNames, ...
        'conditions.displayNames', false);
    if numel(displayNames) ~= numel(names)
        error('SPARQ:validateParameters:displayNameMismatch', ...
            'conditions.displayNames must have the same length as conditions.names.');
    end
    if numel(unique(names)) ~= numel(names)
        error('SPARQ:validateParameters:duplicateConditions', ...
            'conditions.names must contain unique values.');
    end
    process = params.conditions.process;
    if ~isnumeric(process) || ~isreal(process) || ~isvector(process) || ...
            isempty(process) || any(~isfinite(process)) || ...
            any(process ~= round(process)) || any(process < 1) || ...
            any(process > numel(names)) || numel(unique(process)) ~= numel(process)
        error('SPARQ:validateParameters:badConditionIndex', ...
            ['conditions.process must contain unique integer indices into ' ...
             'conditions.names (1..%d).'], numel(names));
    end

    mustBePositiveScalar(params.spectral.samplingRate, 'spectral.samplingRate');
    mustBePositiveIntScalar(params.spectral.window, 'spectral.window');
    mustBeNonnegativeIntScalar(params.spectral.noverlap, 'spectral.noverlap');
    mustBePositiveIntScalar(params.spectral.nfft, 'spectral.nfft');
    if params.spectral.noverlap >= params.spectral.window
        error('SPARQ:validateParameters:badSpectralOverlap', ...
            'spectral.noverlap must be smaller than spectral.window.');
    end

    mustBeLogicalScalar(params.plot.enabled, 'plot.enabled');
    mustBePositiveScalar(params.plot.channelSpacing, 'plot.channelSpacing');
    mustBePositiveScalar(params.plot.thresholdStd, 'plot.thresholdStd');
    eventColor = params.plot.eventColor;
    if ~isnumeric(eventColor) || ~isreal(eventColor) || ...
            ~isequal(size(eventColor), [1 3]) || any(~isfinite(eventColor)) || ...
            any(eventColor < 0) || any(eventColor > 1)
        error('SPARQ:validateParameters:badEventColor', ...
            'plot.eventColor must be a finite RGB row vector in the range 0..1.');
    end
    mustBeLogicalScalar(params.output.includeConcat, 'output.includeConcat');
    mustBeLogicalScalar(params.output.includeNaN, 'output.includeNaN');

    validateTextScalar(params.io.cleanSuffix, 'io.cleanSuffix', true);
    saveFormat = validateTextScalar(params.io.saveFormat, 'io.saveFormat', false);
    if ~ismember(saveFormat, ["-v6", "-v7", "-v7.3"])
        error('SPARQ:validateParameters:badSaveFormat', ...
            'io.saveFormat must be "-v6", "-v7" or "-v7.3".');
    end
    mustBeLogicalScalar(params.io.cacheReferences, 'io.cacheReferences');
    validateTextScalar(params.io.referenceCacheName, 'io.referenceCacheName', false);
    validateTextScalar(params.io.sessionFolderPattern, ...
        'io.sessionFolderPattern', false);
end

% ------------------------------------------------------------------------
function validateSchema(actual, expected, path)
    actualFields = fieldnames(actual);
    expectedFields = fieldnames(expected);
    unknown = setdiff(actualFields, expectedFields);
    missing = setdiff(expectedFields, actualFields);
    if ~isempty(unknown)
        error('SPARQ:validateParameters:unknownField', ...
            'Unknown parameter "%s.%s".', path, unknown{1});
    end
    if ~isempty(missing)
        error('SPARQ:validateParameters:missingField', ...
            'Required parameter "%s.%s" is missing.', path, missing{1});
    end
    for i = 1:numel(expectedFields)
        field = expectedFields{i};
        if isstruct(expected.(field))
            if ~isstruct(actual.(field)) || ~isscalar(actual.(field))
                error('SPARQ:validateParameters:badGroup', ...
                    'params group "%s.%s" must be a scalar struct.', path, field);
            end
            validateSchema(actual.(field), expected.(field), ...
                sprintf('%s.%s', path, field));
        end
    end
end

% ------------------------------------------------------------------------
function mustBePositiveScalar(value, name)
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
            ~isfinite(value) || value <= 0
        error('SPARQ:validateParameters:notPositiveScalar', ...
            'params.%s must be a positive finite real scalar.', name);
    end
end

% ------------------------------------------------------------------------
function mustBePositiveIntScalar(value, name)
    mustBePositiveScalar(value, name);
    if value ~= round(value)
        error('SPARQ:validateParameters:notInteger', ...
            'params.%s must be a positive integer.', name);
    end
end

% ------------------------------------------------------------------------
function mustBeNonnegativeIntScalar(value, name)
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
            ~isfinite(value) || value < 0 || value ~= round(value)
        error('SPARQ:validateParameters:notNonnegativeInteger', ...
            'params.%s must be a nonnegative integer.', name);
    end
end

% ------------------------------------------------------------------------
function mustBeLogicalScalar(value, name)
    if ~islogical(value) || ~isscalar(value)
        error('SPARQ:validateParameters:notLogicalScalar', ...
            'params.%s must be a logical scalar (true or false).', name);
    end
end

% ------------------------------------------------------------------------
function checkEventIndex(value, name)
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
            ~isfinite(value) || value < 1 || value ~= round(value)
        error('SPARQ:validateParameters:badEventIndex', ...
            'params.%s must be a positive integer event index.', name);
    end
end

% ------------------------------------------------------------------------
function values = validateTextVector(values, name, allowEmpty)
    if ~(ischar(values) || iscellstr(values) || isstring(values))
        error('SPARQ:validateParameters:badTextVector', ...
            'params.%s must contain text.', name);
    end
    values = string(values);
    values = values(:);
    if (~allowEmpty && isempty(values)) || any(ismissing(values)) || ...
            any(strlength(values) == 0)
        error('SPARQ:validateParameters:emptyText', ...
            'params.%s contains missing or empty text.', name);
    end
end

% ------------------------------------------------------------------------
function value = validateTextScalar(value, name, allowEmpty)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('SPARQ:validateParameters:badTextScalar', ...
            'params.%s must be a text scalar.', name);
    end
    value = string(value);
    if ismissing(value) || (~allowEmpty && strlength(value) == 0)
        error('SPARQ:validateParameters:emptyText', ...
            'params.%s must not be empty.', name);
    end
end
