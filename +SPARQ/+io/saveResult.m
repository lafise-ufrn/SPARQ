function outputPath = saveResult(result, outputPath, params, provenance, varargin)
% outputPath = SPARQ.io.saveResult(result, outputPath, params, provenance, Name, Value)
%
% Salva somente a saida necessaria para analises posteriores. Na gravacao,
% primeiro escreve um arquivo temporario no diretorio de destino e somente
% depois o move para o nome final.
%
% ENTRADAS:
%   result      = estrutura retornada por SPARQ.processSession
%   outputPath  = caminho final .mat
%   params      = parametros usados no processamento (mantido na assinatura
%                 para compatibilidade; nao e salvo)
%   provenance  = (opcional) metadados usados apenas para proteger o arquivo
%                 de origem; nao sao salvos
%
% PARES NOME-VALOR:
%   'Overwrite' = false por padrao; true permite substituir o destino
%   'SaveFormat'= "-v7.3" por padrao
%
% SAIDAS:
%   outputPath = caminho gravado
%
% O arquivo contem uma unica variavel `SPARQ_result` com:
%   .noiseMask       = mascara logica obrigatoria, uma posicao por amostra
%   .nan             = matriz opcional, somente quando solicitada
%   .concat          = matriz opcional, somente quando solicitada
%   .samplingRateHz  = frequencia necessaria para converter amostras em tempo
%   .channels        = indices das linhas de .nan/.concat, quando presentes
%   .signalUnits     = unidade de .nan/.concat, quando presentes
%   .schemaVersion   = versao do contrato minimo salvo

    if nargin < 4 || isempty(provenance)
        provenance = struct();
    end
    if ~isstruct(result) || ~isscalar(result) || ...
            ~isfield(result, 'cleanSignals') || ...
            ~isstruct(result.cleanSignals) || ...
            ~isscalar(result.cleanSignals) || ...
            ~isfield(result.cleanSignals, 'noiseMask') || ...
            ~islogical(result.cleanSignals.noiseMask) || ...
            ~isrow(result.cleanSignals.noiseMask) || ...
            ~isfield(result, 'samplingRateHz') || ...
            ~isnumeric(result.samplingRateHz) || ...
            ~isreal(result.samplingRateHz) || ...
            ~isscalar(result.samplingRateHz) || ...
            ~isfinite(result.samplingRateHz) || result.samplingRateHz <= 0
        error('SPARQ:io:saveResult:badResult', ...
            ['result must contain a logical row cleanSignals.noiseMask and ' ...
             'a positive samplingRateHz.']);
    end
    if ~isstruct(params) || ~isscalar(params) || ...
            ~isstruct(provenance) || ~isscalar(provenance)
        error('SPARQ:io:saveResult:badMetadata', ...
            'params and provenance must be scalar structs.');
    end
    if ~(ischar(outputPath) || (isstring(outputPath) && isscalar(outputPath)))
        error('SPARQ:io:saveResult:badPath', ...
            'outputPath must be a character vector or string scalar.');
    end
    outputPath = char(outputPath);

    parser = inputParser();
    parser.FunctionName = 'SPARQ.io.saveResult';
    addParameter(parser, 'Overwrite', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'SaveFormat', "-v7.3", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    parse(parser, varargin{:});
    options = parser.Results;

    [outputDir, ~, extension] = fileparts(outputPath);
    if isempty(outputDir)
        outputDir = pwd;
        outputPath = fullfile(outputDir, outputPath);
    end
    if isempty(extension)
        outputPath = [outputPath '.mat'];
    elseif ~strcmpi(extension, '.mat')
        error('SPARQ:io:saveResult:badExtension', ...
            'outputPath must use the .mat extension.');
    end
    assertDestinationIsNotSource(outputPath, result, provenance);
    if exist(outputPath, 'file') == 2
        if ~options.Overwrite
            error('SPARQ:io:saveResult:fileExists', ...
                'Output file already exists: %s', outputPath);
        end
        if ~SPARQ.internal.isVersionedResultFile(outputPath)
            error('SPARQ:io:saveResult:unsafeOverwriteRefused', ...
                ['Refusing to overwrite an existing MAT file that is not ' ...
                 'a recognized SPARQ result: %s'], outputPath);
        end
    end
    if exist(outputDir, 'dir') ~= 7
        [created, message] = mkdir(outputDir);
        if ~created
            error('SPARQ:io:saveResult:mkdirFailed', '%s', message);
        end
    end

    SPARQ_result = minimalResult(result);

    temporaryPath = [tempname(outputDir) '.mat'];
    cleanupObject = onCleanup(@() deleteIfPresent(temporaryPath));
    save(temporaryPath, 'SPARQ_result', char(options.SaveFormat));

    if exist(outputPath, 'file') == 2
        [moved, message] = movefile(temporaryPath, outputPath, 'f');
    else
        [moved, message] = movefile(temporaryPath, outputPath);
    end
    if ~moved
        error('SPARQ:io:saveResult:moveFailed', '%s', message);
    end
end

% ------------------------------------------------------------------------
function saved = minimalResult(result)
    clean = result.cleanSignals;
    hasNaN = isfield(clean, 'nan');
    hasConcat = isfield(clean, 'concat');

    saved.noiseMask = clean.noiseMask;
    if hasNaN
        saved.nan = clean.nan;
    end
    if hasConcat
        saved.concat = clean.concat;
    end
    saved.samplingRateHz = result.samplingRateHz;

    if hasNaN || hasConcat
        if ~isfield(clean, 'channels') || ~isfield(result, 'signalUnits')
            error('SPARQ:io:saveResult:badSignalMetadata', ...
                ['Optional signal matrices require cleanSignals.channels ' ...
                 'and signalUnits.']);
        end
        saved.channels = clean.channels;
        saved.signalUnits = result.signalUnits;
    end

    software = SPARQ.version();
    saved.schemaVersion = software.resultSchemaVersion;
end

% ------------------------------------------------------------------------
function assertDestinationIsNotSource(outputPath, result, provenance)
    sourcePaths = strings(0, 1);
    if isfield(result, 'sourceFile')
        sourcePaths(end + 1, 1) = string(result.sourceFile);
    end
    if isfield(provenance, 'source') && isstruct(provenance.source) && ...
            isfield(provenance.source, 'path')
        sourcePaths(end + 1, 1) = string(provenance.source.path);
    end
    if isfield(provenance, 'manifestRow') && ...
            isstruct(provenance.manifestRow) && ...
            isfield(provenance.manifestRow, 'SourceFile')
        sourcePaths(end + 1, 1) = ...
            string(provenance.manifestRow.SourceFile);
    end

    sourcePaths = sourcePaths(strlength(sourcePaths) > 0);
    for i = 1:numel(sourcePaths)
        if SPARQ.internal.pathsEqual(outputPath, sourcePaths(i))
            error('SPARQ:io:saveResult:sourceOverwriteRefused', ...
                'Refusing to overwrite the source recording: %s', outputPath);
        end
    end
end

% ------------------------------------------------------------------------
function deleteIfPresent(filePath)
    if exist(filePath, 'file') == 2
        delete(filePath);
    end
end
