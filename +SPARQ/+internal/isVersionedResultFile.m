function valid = isVersionedResultFile(filePath)
% valid = SPARQ.internal.isVersionedResultFile(filePath)
% Reconhece somente resultados produzidos por SPARQ.io.saveResult.

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
        valid = isLegacyRichResult(value) || isMinimalResult(value);
    catch
        valid = false;
    end
end

% ------------------------------------------------------------------------
function valid = isLegacyRichResult(value)
    required = {'schemaVersion', 'software', 'processedAtUtc', ...
        'result', 'parameters', 'provenance'};
    valid = isstruct(value) && isscalar(value) && ...
        all(isfield(value, required));
end

% ------------------------------------------------------------------------
function valid = isMinimalResult(value)
    required = {'schemaVersion', 'noiseMask', 'samplingRateHz'};
    valid = isstruct(value) && isscalar(value) && ...
        all(isfield(value, required));
    if ~valid
        return;
    end

    valid = string(value.schemaVersion) == "2.0" && ...
        islogical(value.noiseMask) && isrow(value.noiseMask) && ...
        isnumeric(value.samplingRateHz) && isreal(value.samplingRateHz) && ...
        isscalar(value.samplingRateHz) && isfinite(value.samplingRateHz) && ...
        value.samplingRateHz > 0;
    if ~valid
        return;
    end

    hasNaN = isfield(value, 'nan');
    hasConcat = isfield(value, 'concat');
    if ~(hasNaN || hasConcat)
        return;
    end
    if ~isfield(value, 'channels') || ~isfield(value, 'signalUnits') || ...
            ~isnumeric(value.channels) || ~isvector(value.channels)
        valid = false;
        return;
    end

    rowCount = numel(value.channels);
    if hasNaN
        valid = isnumeric(value.nan) && ismatrix(value.nan) && ...
            size(value.nan, 1) == rowCount && ...
            size(value.nan, 2) == numel(value.noiseMask);
    end
    if valid && hasConcat
        valid = isnumeric(value.concat) && ismatrix(value.concat) && ...
            size(value.concat, 1) == rowCount && ...
            size(value.concat, 2) == nnz(~value.noiseMask);
    end
end
