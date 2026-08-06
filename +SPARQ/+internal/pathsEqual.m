function equal = pathsEqual(firstPath, secondPath)
% equal = SPARQ.internal.pathsEqual(firstPath, secondPath)
%
% Compara dois caminhos depois de resolve-los para formas absolutas. Caminhos
% existentes sao resolvidos pelo sistema de arquivos, reduzindo o risco de um
% arquivo de origem ser confundido com um destino escrito por outro nome.

    if strlength(string(firstPath)) == 0 || strlength(string(secondPath)) == 0
        equal = false;
        return;
    end

    firstPath = normalizedAbsolutePath(firstPath);
    secondPath = normalizedAbsolutePath(secondPath);
    if ispc
        equal = strcmpi(firstPath, secondPath);
    else
        equal = strcmp(firstPath, secondPath);
    end
end

% ------------------------------------------------------------------------
function value = normalizedAbsolutePath(value)
    value = char(string(value));
    [resolved, attributes] = fileattrib(value);
    if resolved
        value = attributes.Name;
    else
        [folder, name, extension] = fileparts(value);
        if isempty(folder)
            folder = pwd;
        end
        [folderResolved, folderAttributes] = fileattrib(folder);
        if folderResolved
            folder = folderAttributes.Name;
        elseif ~isAbsolutePath(folder)
            folder = fullfile(pwd, folder);
        end
        value = fullfile(folder, [name extension]);
    end
    value = strrep(value, '/', filesep);
    value = strrep(value, '\', filesep);
end

% ------------------------------------------------------------------------
function result = isAbsolutePath(value)
    if ispc
        result = ~isempty(regexp(value, '^[A-Za-z]:[\\/]|^\\\\', 'once'));
    else
        result = startsWith(value, filesep);
    end
end
