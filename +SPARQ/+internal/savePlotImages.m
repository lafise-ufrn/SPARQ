function imageFiles = savePlotImages(row, outputRoot, overwriteImages)
% imageFiles = SPARQ.internal.savePlotImages(row, outputRoot, overwriteImages)
%
% Exporta as quatro figuras padrao e as figuras opcionais presentes para
% outputRoot/imagens, preservando a estrutura relativa dos resultados MAT.

    relativeFolder = relativeToRoot(row.OutputDirectory, outputRoot);
    imageFolder = fullfile(outputRoot, 'imagens', relativeFolder);
    if exist(imageFolder, 'dir') ~= 7
        mkdir(imageFolder);
    end

    imageStem = safePathSegment(row.SessionId);
    if strlength(imageStem) == 0
        [~, sourceStem] = fileparts(row.SourceFile);
        imageStem = safePathSegment(sourceStem);
    end

    tags = SPARQ.internal.figureTags();
    tagFields = {'overview', 'thresholds', 'noiseWindows', 'summary', ...
        'concat', 'nan'};
    fileSuffixes = {'raw', 'thresholds', 'noise_windows', ...
        'saved_percentage', 'concat', 'nan'};
    drawnow;

    figureHandles = cell(1, numel(tagFields));
    imageFiles = strings(0, 1);
    candidateFiles = cell(1, numel(tagFields));
    for i = 1:numel(tagFields)
        figureHandles{i} = findall(groot, 'Type', 'figure', ...
            'Tag', tags.(tagFields{i}));
        if isempty(figureHandles{i})
            continue;
        end
        candidateFiles{i} = fullfile(imageFolder, sprintf('%s_%s.png', ...
            imageStem, fileSuffixes{i}));
    end

    if ~overwriteImages
        existingIndex = find(cellfun( ...
            @(path) ~isempty(path) && exist(path, 'file') == 2, ...
            candidateFiles), 1);
        if ~isempty(existingIndex)
            error('SPARQ:main:imageExists', ...
                ['A imagem de resultado ja existe e nao sera substituida: %s. ' ...
                 'Habilite a substituicao de resultados para sobrescreve-la.'], ...
                candidateFiles{existingIndex});
        end
    end

    for i = 1:numel(tagFields)
        if isempty(figureHandles{i})
            continue;
        end
        exportgraphics(figureHandles{i}(1), candidateFiles{i});
        imageFiles(end + 1, 1) = string(candidateFiles{i}); %#ok<AGROW>
    end
end

% ------------------------------------------------------------------------
function relative = relativeToRoot(folder, root)
    folder = char(folder);
    root = char(root);
    if strcmpi(folder, root)
        relative = '';
        return;
    end
    prefix = [root filesep];
    if numel(folder) < numel(prefix) || ~strcmpi(folder(1:numel(prefix)), prefix)
        error('SPARQ:main:pathOutsideRoot', ...
            'Pasta de resultado fora da raiz esperada: %s', folder);
    end
    relative = folder(numel(prefix) + 1:end);
end

% ------------------------------------------------------------------------
function value = safePathSegment(value)
    value = regexprep(string(value), '[^A-Za-z0-9_.-]', '_');
end
