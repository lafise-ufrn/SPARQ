function valid = isReferenceCacheFile(filePath)
% valid = SPARQ.internal.isReferenceCacheFile(filePath)
% Retorna true apenas para um arquivo MAT com o contrato de cache SPARQ.

    valid = false;
    if exist(filePath, 'file') ~= 2
        return;
    end
    try
        variables = whos('-file', filePath);
        names = string({variables.name});
        allowed = ["referenceSeconds", "cacheMetadata"];
        if ~ismember("referenceSeconds", names) || any(~ismember(names, allowed))
            return;
        end
        cached = load(filePath, 'referenceSeconds');
        interval = cached.referenceSeconds;
        valid = isnumeric(interval) && isreal(interval) && ...
            numel(interval) == 2 && all(isfinite(interval)) && ...
            interval(2) > interval(1);
    catch
        valid = false;
    end
end
