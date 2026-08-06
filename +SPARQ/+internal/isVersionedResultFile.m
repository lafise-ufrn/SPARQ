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
        required = {'schemaVersion', 'software', 'processedAtUtc', ...
            'result', 'parameters', 'provenance'};
        valid = isstruct(value) && isscalar(value) && ...
            all(isfield(value, required));
    catch
        valid = false;
    end
end
