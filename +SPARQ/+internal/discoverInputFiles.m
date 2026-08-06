function sourceFiles = discoverInputFiles(dataRoot, filePattern, excludedRoot)
% sourceFiles = SPARQ.internal.discoverInputFiles(dataRoot, filePattern, excludedRoot)
%
% Descobre arquivos recursivamente, em ordem deterministica, excluindo toda a
% arvore de resultados para que saidas .mat nunca voltem a ser entradas.

    dataRoot = char(string(dataRoot));
    filePattern = char(string(filePattern));
    excludedRoot = char(string(excludedRoot));

    matches = dir(fullfile(dataRoot, '**', filePattern));
    matches = matches(~[matches.isdir]);
    paths = strings(0, 1);
    for i = 1:numel(matches)
        candidate = string(fullfile(matches(i).folder, matches(i).name));
        if ~isPathInside(candidate, excludedRoot)
            paths(end + 1, 1) = candidate; %#ok<AGROW>
        end
    end
    [~, order] = sort(lower(paths));
    sourceFiles = paths(order);
end

% ------------------------------------------------------------------------
function inside = isPathInside(candidate, parent)
    candidate = char(candidate);
    parent = char(parent);
    if isempty(parent)
        inside = false;
        return;
    end
    candidate = normalizeSeparators(candidate);
    parent = normalizeSeparators(parent);
    prefix = [parent filesep];
    inside = strcmpi(candidate, parent) || ...
        (numel(candidate) >= numel(prefix) && strcmpi(candidate(1:numel(prefix)), prefix));
end

% ------------------------------------------------------------------------
function pathValue = normalizeSeparators(pathValue)
    pathValue = strrep(pathValue, '/', filesep);
    pathValue = strrep(pathValue, '\', filesep);
    while numel(pathValue) > 1 && pathValue(end) == filesep
        pathValue(end) = [];
    end
end

