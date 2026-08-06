function batch = runMain(config)
% batch = SPARQ.internal.runMain(config)
%
% Implementacao testavel do script main.m: escolhe a pasta quando necessario,
% descobre entradas e sessoes logicas, espelha subpastas e executa runBatch.

    config = normalizeConfig(config);
    dataRoot = char(config.dataFolder);
    if isempty(dataRoot)
        selected = uigetdir(pwd, 'Selecione a pasta que contem os arquivos .mat');
        if isequal(selected, 0)
            fprintf('Execucao cancelada: nenhuma pasta foi selecionada.\n');
            batch = [];
            return;
        end
        dataRoot = selected;
    end
    if exist(dataRoot, 'dir') ~= 7
        error('SPARQ:main:dataFolderNotFound', ...
            'A pasta de dados nao existe: %s', dataRoot);
    end

    dataRoot = absolutePath(dataRoot);
    outputRoot = fullfile(dataRoot, char(config.outputFolderName));
    sourceFiles = SPARQ.internal.discoverInputFiles( ...
        dataRoot, config.filePattern, outputRoot);
    if isempty(sourceFiles)
        error('SPARQ:main:noInputFiles', ...
            ['Nenhum arquivo correspondente a "%s" foi encontrado em %s. ' ...
             'Revise config.filePattern e o mapa das pastas.'], ...
            config.filePattern, dataRoot);
    end

    nFiles = numel(sourceFiles);
    manifestParts = cell(nFiles, 1);
    for i = 1:nFiles
        try
            manifestParts{i} = SPARQ.discoverSessions(sourceFiles(i), ...
                'InputFormat', config.inputFormat, ...
                'LoaderOptions', config.loader);
        catch
            % Preserve o isolamento por entrada: runBatch repetira a leitura
            % desta fonte e registrara o erro sem impedir as demais sessoes.
            [~, stem] = fileparts(sourceFiles(i));
            manifestParts{i} = SPARQ.createManifest(sourceFiles(i), ...
                'SessionId', string(stem), ...
                'InputFormat', config.inputFormat, ...
                'LoaderOptions', config.loader);
        end
    end
    manifest = vertcat(manifestParts{:});
    manifest = configureMainRows( ...
        manifest, dataRoot, outputRoot, config.excludedChannels);

    parameterProvider = @(session, row) ...
        SPARQ.internal.mainParameters(session, config);
    resultCallback = @(session, result, params, row) ...
        plotResult(session, result, params, row, config);

    fprintf(['Processando %d sessao(oes) logica(s) descoberta(s) em ' ...
        '%d fonte(s). Os resultados serao salvos em:\n%s\n\n'], ...
        height(manifest), nFiles, outputRoot);
    batch = SPARQ.runBatch(manifest, ...
        'Parameters', parameterProvider, ...
        'ResultCallback', resultCallback, ...
        'ForceNewReferences', config.forceNewReferences, ...
        'MaxDisplayPoints', config.maxDisplayPointsPerChannel, ...
        'ShowSelectionOverview', config.plot.enabled, ...
        'SaveResults', true, ...
        'Overwrite', config.overwriteResults, ...
        'ContinueOnError', true);

    disp(batch.report);
    nSucceeded = nnz(batch.report.Status == "ok");
    fprintf('\n%d/%d sessao(oes) processada(s) com sucesso; %d falha(s).\n', ...
        nSucceeded, height(manifest), height(manifest) - nSucceeded);
    fprintf('Pasta de resultados: %s\n', outputRoot);
end

% ------------------------------------------------------------------------
function config = normalizeConfig(config)
    if ~isstruct(config) || ~isscalar(config)
        error('SPARQ:main:badConfig', 'config deve ser uma struct escalar.');
    end
    defaults.dataFolder = "";
    defaults.filePattern = "*.mat";
    defaults.inputFormat = "auto";
    defaults.loader.lfpVariable = "LFP";
    defaults.loader.samplingRateVariable = "fs";
    defaults.loader.samplingRateHz = [];
    defaults.loader.timeVariable = "";
    defaults.loader.channelLabelsVariable = "";
    defaults.loader.dataOrientation = "channels-by-samples";
    defaults.loader.signalUnits = "arbitrary";
    defaults.loader.signalScale = 1;
    defaults.excludedChannels = [];
    defaults.detection.thresholdStd = [];
    defaults.detection.minSimultaneousChannels = [];
    defaults.detection.mergeGapSamples = [];
    defaults.detection.settleWindowSamples = [];
    defaults.detection.settleToleranceStd = [];
    defaults.output.includeConcat = false;
    defaults.output.includeNaN = false;
    defaults.outputFolderName = "SPARQ_results";
    defaults.overwriteResults = false;
    defaults.forceNewReferences = false;
    defaults.maxDisplayPointsPerChannel = 20000;
    defaults.plot.enabled = true;
    config = SPARQ.internal.mergeOptions(defaults, config, 'config');

    validateTextScalar(config.dataFolder, 'dataFolder', true);
    validateTextScalar(config.filePattern, 'filePattern', false);
    validateTextScalar(config.inputFormat, 'inputFormat', false);
    validateTextScalar(config.outputFolderName, 'outputFolderName', false);
    outputFolderName = char(string(config.outputFolderName));
    if any(contains(outputFolderName, {'/', '\'})) || ...
            ismember(outputFolderName, {'.', '..'})
        error('SPARQ:main:badOutputFolderName', ...
            'outputFolderName deve ser somente o nome de uma subpasta.');
    end
    if ~(islogical(config.overwriteResults) && isscalar(config.overwriteResults)) || ...
            ~(islogical(config.forceNewReferences) && isscalar(config.forceNewReferences)) || ...
            ~(islogical(config.plot.enabled) && isscalar(config.plot.enabled))
        error('SPARQ:main:badLogicalOption', ...
            ['overwriteResults, forceNewReferences e ' ...
             'plot.enabled devem ser true ou false.']);
    end
    if ~isnumeric(config.maxDisplayPointsPerChannel) || ...
            ~isscalar(config.maxDisplayPointsPerChannel) || ...
            config.maxDisplayPointsPerChannel < 100 || ...
            config.maxDisplayPointsPerChannel ~= round(config.maxDisplayPointsPerChannel)
        error('SPARQ:main:badMaxDisplayPoints', ...
            'maxDisplayPointsPerChannel deve ser um inteiro maior ou igual a 100.');
    end
    config.dataFolder = string(config.dataFolder);
    config.filePattern = string(config.filePattern);
    config.inputFormat = string(config.inputFormat);
    config.outputFolderName = string(config.outputFolderName);
end

% ------------------------------------------------------------------------
function plotResult(session, result, params, ~, config)
    SPARQ.internal.plotProcessingResult( ...
        session, result, params, config.maxDisplayPointsPerChannel);
end

% ------------------------------------------------------------------------
function manifest = configureMainRows( ...
        manifest, dataRoot, outputRoot, excludedChannels)
    nRows = height(manifest);
    outputDirectories = strings(nRows, 1);
    for i = 1:nRows
        sourceFile = manifest.SourceFile(i);
        [sourceFolder, sourceStem] = fileparts(sourceFile);
        relativeFolder = relativeToRoot(sourceFolder, dataRoot);
        if nnz(manifest.SourceFile == sourceFile) > 1
            outputDirectories(i) = string(fullfile( ...
                outputRoot, relativeFolder, safePathSegment(sourceStem)));
        else
            outputDirectories(i) = string(fullfile(outputRoot, relativeFolder));
        end
    end
    manifest.OutputDirectory = outputDirectories;
    referenceCacheFiles = strings(nRows, 1);
    for i = 1:nRows
        referenceCacheFiles(i) = mainCacheFile( ...
            manifest(i, :), manifest, dataRoot, outputRoot);
    end
    manifest.ReferenceCacheFile = referenceCacheFiles;
    manifest.ExcludedChannels = repmat({excludedChannels(:).'}, nRows, 1);
    manifest = SPARQ.validateManifest(manifest);
end

% ------------------------------------------------------------------------
function cacheFile = mainCacheFile(row, manifest, dataRoot, outputRoot)
    sourceFile = row.SourceFile;
    [sourceFolder, sourceStem] = fileparts(sourceFile);
    relativeFolder = relativeToRoot(sourceFolder, dataRoot);
    isMultiSession = nnz(manifest.SourceFile == sourceFile) > 1;
    if isMultiSession
        cacheFolder = fullfile(outputRoot, '.reference_cache', ...
            relativeFolder, safePathSegment(sourceStem));
        sessionStem = safePathSegment(row.SessionId);
        if strlength(sessionStem) == 0
            sessionStem = "session";
        end
        cacheName = sessionStem + "_reference.mat";
    else
        cacheFolder = fullfile( ...
            outputRoot, '.reference_cache', relativeFolder);
        cacheName = safePathSegment(sourceStem) + "_reference.mat";
    end
    cacheFile = string(fullfile(cacheFolder, cacheName));
end

% ------------------------------------------------------------------------
function value = safePathSegment(value)
    value = regexprep(string(value), '[^A-Za-z0-9_.-]', '_');
end

% ------------------------------------------------------------------------
function validateTextScalar(value, name, allowEmpty)
    valid = ischar(value) || (isstring(value) && isscalar(value));
    if valid && ~allowEmpty
        valid = strlength(string(value)) > 0;
    end
    if ~valid
        error('SPARQ:main:badTextOption', ...
            'config.%s deve ser um texto escalar%s.', name, ...
            ternary(allowEmpty, '', ' nao vazio'));
    end
end

% ------------------------------------------------------------------------
function value = ternary(condition, ifTrue, ifFalse)
    if condition
        value = ifTrue;
    else
        value = ifFalse;
    end
end

% ------------------------------------------------------------------------
function pathValue = absolutePath(pathValue)
    [success, attributes] = fileattrib(pathValue);
    if ~success
        error('SPARQ:main:dataFolderNotFound', ...
            'Nao foi possivel resolver a pasta de dados: %s', pathValue);
    end
    pathValue = attributes.Name;
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
            'Arquivo descoberto fora da pasta de dados: %s', folder);
    end
    relative = folder(numel(prefix) + 1:end);
end
