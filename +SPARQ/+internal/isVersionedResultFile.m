function valid = isVersionedResultFile(filePath)
% valid = SPARQ.internal.isVersionedResultFile(filePath)
% Reconhece resultados atuais e resultados SPARQ anteriores a versao 2.0.

    valid = false;
    if exist(filePath, 'file') ~= 2
        return;
    end
    try
        variables = whos('-file', filePath);
        if ~isequal(string({variables.name}), "SPARQ_result")
            return;
        end
        saved = load(filePath, 'SPARQ_result');
        value = saved.SPARQ_result;
        if ~isstruct(value) || ~isscalar(value)
            return;
        end

        legacyFields = {'schemaVersion', 'software', 'processedAtUtc', ...
            'result', 'parameters', 'provenance'};
        if all(isfield(value, legacyFields))
            valid = true;
            return;
        end

        valid = isMinimalResult(value);
    catch
        valid = false;
    end
end

% ------------------------------------------------------------------------
function valid = isMinimalResult(value)
    hasNaN = isfield(value, 'nan');
    hasConcat = isfield(value, 'concat');
    expected = {'noiseMask'; 'samplingRateHz'; 'schemaVersion'};
    if hasNaN
        expected{end + 1, 1} = 'nan';
    end
    if hasConcat
        expected{end + 1, 1} = 'concat';
    end
    if hasNaN || hasConcat
        expected(end + 1:end + 2, 1) = {'channels'; 'signalUnits'};
    end

    actual = fieldnames(value);
    if ~isequal(sort(actual), sort(expected)) || ...
            ~islogical(value.noiseMask) || ~isrow(value.noiseMask) || ...
            ~isnumeric(value.samplingRateHz) || ...
            ~isreal(value.samplingRateHz) || ...
            ~isscalar(value.samplingRateHz) || ...
            ~isfinite(value.samplingRateHz) || value.samplingRateHz <= 0 || ...
            strlength(string(value.schemaVersion)) == 0
        valid = false;
        return;
    end

    if ~(hasNaN || hasConcat)
        valid = true;
        return;
    end

    channels = value.channels;
    if ~isnumeric(channels) || ~isreal(channels) || ~isvector(channels) || ...
            isempty(channels) || any(~isfinite(channels)) || ...
            any(channels ~= round(channels)) || any(channels < 1) || ...
            numel(unique(channels)) ~= numel(channels) || ...
            ~(ischar(value.signalUnits) || ...
              (isstring(value.signalUnits) && isscalar(value.signalUnits)))
        valid = false;
        return;
    end

    nChannels = numel(channels);
    nSamples = numel(value.noiseMask);
    valid = true;
    if hasNaN
        valid = valid && isnumeric(value.nan) && ismatrix(value.nan) && ...
            isequal(size(value.nan), [nChannels nSamples]);
    end
    if hasConcat
        valid = valid && isnumeric(value.concat) && ismatrix(value.concat) && ...
            isequal(size(value.concat), [nChannels nnz(~value.noiseMask)]);
    end
end
