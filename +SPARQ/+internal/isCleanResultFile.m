function valid = isCleanResultFile(filePath)
% valid = SPARQ.internal.isCleanResultFile(filePath)
% Reconhece somente resultados produzidos por SPARQ.saveCleanSignals.

    valid = false;
    if exist(filePath, 'file') ~= 2
        return;
    end
    try
        variables = whos('-file', filePath);
        if ~isequal(string({variables.name}), "clean_data")
            return;
        end
        saved = load(filePath, 'clean_data');
        value = saved.clean_data;
        valid = isstruct(value) && isscalar(value) && ...
            isfield(value, 'noiseMask') && islogical(value.noiseMask);
    catch
        valid = false;
    end
end
