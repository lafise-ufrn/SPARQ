function batch = runBatch(manifest, varargin)
% batch = SPARQ.runBatch(manifest, Name, Value, ...)
%
% Processa um manifest generico sem depender de hierarquia de pastas,
% especie ou condicoes predefinidas. Cada sessao sem cache valido solicita
% dois cliques para selecionar a referencia limpa; caches validos apenas
% reutilizam essa selecao manual.
%
% ENTRADAS:
%   manifest = tabela de SPARQ.createManifest/validateManifest
%
% PARES NOME-VALOR:
%   'Loader'            = [] (padrao) usa o leitor de arquivos MAT
%                         reutilizaveis; function handle preserva o contrato
%                         legado (filePath, loaderOptions) -> session
%   'Parameters'        = [] para SPARQ.processingOptions por sessao;
%                         struct completa; ou callback (session,row) -> params
%   'ResultCallback'    = callback opcional (session,result,params,row),
%                         executado apos o processamento e antes de salvar
%   'SaveResults'       = false por padrao
%   'OutputDirectory'   = destino global opcional.
%  
%   'Overwrite'         = false por padrao
%   'ContinueOnError'   = true por padrao
%   'ForceNewReferences'= false por padrao; true exige nova selecao manual
%   'MaxDisplayPoints'  = 20000 pontos por canal na figura de selecao
%   'ShowSelectionOverview' = false; mostra a selecao mesmo ao usar cache
%   'SelectionProvider' = callback opcional repassado ao seletor de referencia
%
% SAIDAS:
%   batch.report     = tabela com uma linha por entrada
%   batch.results    = cell alinhada ao manifesto ([] nas falhas)
%   batch.parameters = parametros efetivamente usados por linha
%   batch.manifest   = manifest normalizado

    manifest = SPARQ.validateManifest(manifest);

    parser = inputParser();
    parser.FunctionName = 'SPARQ.runBatch';
    addParameter(parser, 'Loader', [], ...
        @(x) isempty(x) || isa(x, 'function_handle'));
    addParameter(parser, 'Parameters', [], ...
        @(x) isempty(x) || isstruct(x) || isa(x, 'function_handle'));
    addParameter(parser, 'ResultCallback', [], ...
        @(x) isempty(x) || isa(x, 'function_handle'));
    addParameter(parser, 'SaveResults', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'OutputDirectory', "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'Overwrite', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'ContinueOnError', true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'ForceNewReferences', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'MaxDisplayPoints', 20000, ...
        @(x) isnumeric(x) && isreal(x) && isscalar(x) && isfinite(x) && ...
        x >= 100 && x == round(x));
    addParameter(parser, 'ShowSelectionOverview', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'SelectionProvider', [], ...
        @(x) isempty(x) || isa(x, 'function_handle'));
    parse(parser, varargin{:});
    options = parser.Results;

    nRows = height(manifest);
    results = cell(nRows, 1);
    parametersUsed = cell(nRows, 1);
    reportRows = repmat(emptyReportRow(), nRows, 1);
    readers = containers.Map('KeyType', 'char', 'ValueType', 'any');
    readerCleanup = onCleanup(@() closeReaders(readers));

    for rowIndex = 1:nRows
        row = manifest(rowIndex, :);
        reportRows(rowIndex).SubjectId = row.SubjectId;
        reportRows(rowIndex).SessionId = row.SessionId;
        reportRows(rowIndex).SourceFile = row.SourceFile;
        reportRows(rowIndex).InputFormat = row.InputFormat;
        reportRows(rowIndex).DataSelector = selectorText(row.DataSelector{1});

        try
            loaderOptions = row.LoaderOptions{1};
            loaderOptions.subjectId = row.SubjectId;
            loaderOptions.sessionId = row.SessionId;
            loaderOptions.condition = row.Condition;
            if isfinite(row.SamplingRateHz)
                loaderOptions.samplingRateHz = row.SamplingRateHz;
            end
            loadTimer = tic;
            if isempty(options.Loader)
                requestedFormat = row.InputFormat;
                if strlength(requestedFormat) == 0
                    requestedFormat = "auto";
                end
                loaderOptions.inputFormat = requestedFormat;
                key = char(row.SourceFile + "|" + requestedFormat);
                if ~isKey(readers, key)
                    readers(key) = SPARQ.io.SourceReader(row.SourceFile, loaderOptions);
                end
                reader = readers(key);
                session = reader.load(row.DataSelector{1}, loaderOptions);
                reportRows(rowIndex).InputFormat = reader.InputFormat;
            else
                if strlength(row.InputFormat) > 0
                    loaderOptions.inputFormat = row.InputFormat;
                end
                if ~isempty(fieldnames(row.DataSelector{1}))
                    loaderOptions.dataSelector = row.DataSelector{1};
                end
                session = options.Loader(row.SourceFile, loaderOptions);
            end
            reportRows(rowIndex).LoadSeconds = toc(loadTimer);
            reportRows(rowIndex).Channels = size(session.lfp, 1);
            reportRows(rowIndex).Samples = size(session.lfp, 2);
            reportRows(rowIndex).SamplingRateHz = session.samplingRateHz;
            reportRows(rowIndex).DurationSeconds = ...
                (size(session.lfp, 2) - 1) / session.samplingRateHz;

            params = resolveParameters(options.Parameters, session, row);
            excluded = row.ExcludedChannels{1};
            if ~isempty(excluded)
                params.channels.excluded = excluded;
            end
            parametersUsed{rowIndex} = params;

            [referenceIdx, referenceInfo] = ...
                SPARQ.reference.selectInteractive(session, ...
                'ExcludedChannels', params.channels.excluded, ...
                'CacheFile', row.ReferenceCacheFile, ...
                'ForceNew', options.ForceNewReferences, ...
                'MaxDisplayPoints', options.MaxDisplayPoints, ...
                'ShowOverview', options.ShowSelectionOverview, ...
                'SelectionProvider', options.SelectionProvider);

            processTimer = tic;
            result = SPARQ.processSession(session, referenceIdx, params);
            reportRows(rowIndex).ProcessSeconds = toc(processTimer);
            result.referenceInfo = referenceInfo;
            if ~isempty(options.ResultCallback)
                options.ResultCallback(session, result, params, row);
            end
            results{rowIndex} = result;

            outputFile = "";
            if options.SaveResults
                outputDirectory = row.OutputDirectory;
                if strlength(outputDirectory) == 0
                    outputDirectory = string(options.OutputDirectory);
                end
                if strlength(outputDirectory) == 0
                    error('SPARQ:runBatch:missingOutputDirectory', ...
                        ['SaveResults is true but neither the manifest nor ' ...
                         'OutputDirectory specifies a destination.']);
                end
                outputFile = buildOutputPath(outputDirectory, row, rowIndex);
                provenance.manifestRow = table2struct(row);
                provenance.source = SPARQ.internal.sourceIdentity(row.SourceFile);
                provenance.reference = referenceInfo;
                outputFile = string(SPARQ.io.saveResult( ...
                    result, outputFile, params, provenance, ...
                    'Overwrite', options.Overwrite));
            end

            reportRows(rowIndex).Status = "ok";
            reportRows(rowIndex).PercentSaved = result.noise.percentSaved;
            reportRows(rowIndex).PercentNoise = result.noise.percentNoise;
            reportRows(rowIndex).OutputFile = outputFile;
        catch exception
            reportRows(rowIndex).Status = "failed";
            reportRows(rowIndex).ErrorIdentifier = string(exception.identifier);
            reportRows(rowIndex).ErrorMessage = string(exception.message);
            if ~options.ContinueOnError
                rethrow(exception);
            end
        end
    end

    batch.report = struct2table(reportRows);
    batch.results = results;
    batch.parameters = parametersUsed;
    batch.manifest = manifest;
end

% ------------------------------------------------------------------------
function params = resolveParameters(parameterSource, session, row)
    if isempty(parameterSource)
        params = SPARQ.processingOptions(size(session.lfp, 1));
    elseif isa(parameterSource, 'function_handle')
        params = parameterSource(session, row);
    else
        params = parameterSource;
    end
    if ~isstruct(params) || ~isscalar(params)
        error('SPARQ:runBatch:badParameters', ...
            'Parameters must resolve to a scalar struct.');
    end
end

% ------------------------------------------------------------------------
function outputPath = buildOutputPath(outputDirectory, row, rowIndex)
    stem = row.SessionId;
    if strlength(stem) == 0
        [~, stem] = fileparts(row.SourceFile);
    end
    stem = regexprep(stem, '[^A-Za-z0-9_.-]', '_');
    if strlength(stem) == 0
        stem = "session-" + rowIndex;
    end
    outputPath = fullfile(outputDirectory, stem + "_clean.mat");
end

% ------------------------------------------------------------------------
function row = emptyReportRow()
    row.SubjectId = "";
    row.SessionId = "";
    row.SourceFile = "";
    row.InputFormat = "";
    row.DataSelector = "";
    row.Channels = NaN;
    row.Samples = NaN;
    row.SamplingRateHz = NaN;
    row.DurationSeconds = NaN;
    row.LoadSeconds = NaN;
    row.ProcessSeconds = NaN;
    row.Status = "";
    row.PercentSaved = NaN;
    row.PercentNoise = NaN;
    row.OutputFile = "";
    row.ErrorIdentifier = "";
    row.ErrorMessage = "";
end

% ------------------------------------------------------------------------
function closeReaders(readers)
    keys = readers.keys;
    for i = 1:numel(keys)
        try
            reader = readers(keys{i});
            reader.close();
        catch
        end
    end
end

% ------------------------------------------------------------------------
function value = selectorText(selector)
    if isempty(fieldnames(selector))
        value = "";
    else
        value = string(jsonencode(selector));
    end
end
