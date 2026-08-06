function manifest = createManifest(sourceFiles, varargin)
% manifest = SPARQ.createManifest(sourceFiles, Name, Value, ...)
%
% Cria um manifesto tabular explicito para processamento em lote, sem inferir
% sujeitos, condicoes ou sessoes a partir de uma hierarquia de pastas.
%
% ENTRADAS:
%   sourceFiles = vetor string, char ou cellstr com um arquivo por sessao
%
% PARES NOME-VALOR:
%   SubjectId, SessionId, Condition, SamplingRateHz, InputFormat,
%   DataSelector, ReferenceCacheFile, OutputDirectory,
%   LoaderOptions e ExcludedChannels. Valores escalares sao replicados para
%   todas as linhas; valores vetoriais devem ter uma entrada por arquivo.
%
% SAIDAS:
%   manifest = tabela canonica aceita por SPARQ.runBatch

    sourceFiles = normalizeSourceFiles(sourceFiles);
    nRows = numel(sourceFiles);
    defaultSessionIds = strings(nRows, 1);
    for i = 1:nRows
        [~, baseName] = fileparts(sourceFiles(i));
        defaultSessionIds(i) = string(baseName);
    end

    parser = inputParser();
    parser.FunctionName = 'SPARQ.createManifest';
    addParameter(parser, 'SubjectId', "");
    addParameter(parser, 'SessionId', defaultSessionIds);
    addParameter(parser, 'Condition', "");
    addParameter(parser, 'SamplingRateHz', NaN);
    addParameter(parser, 'ReferenceCacheFile', "");
    addParameter(parser, 'OutputDirectory', "");
    addParameter(parser, 'InputFormat', "");
    addParameter(parser, 'DataSelector', struct());
    addParameter(parser, 'LoaderOptions', struct());
    addParameter(parser, 'ExcludedChannels', []);
    parse(parser, varargin{:});
    values = parser.Results;

    manifest = table(sourceFiles, ...
        expandText(values.SubjectId, nRows, 'SubjectId'), ...
        expandText(values.SessionId, nRows, 'SessionId'), ...
        expandText(values.Condition, nRows, 'Condition'), ...
        expandNumeric(values.SamplingRateHz, nRows, 'SamplingRateHz'), ...
        expandText(values.ReferenceCacheFile, nRows, 'ReferenceCacheFile'), ...
        expandText(values.OutputDirectory, nRows, 'OutputDirectory'), ...
        expandText(values.InputFormat, nRows, 'InputFormat'), ...
        expandStructCells(values.DataSelector, nRows, 'DataSelector'), ...
        expandStructCells(values.LoaderOptions, nRows), ...
        expandNumericCells(values.ExcludedChannels, nRows), ...
        'VariableNames', {'SourceFile', 'SubjectId', 'SessionId', 'Condition', ...
        'SamplingRateHz', 'ReferenceCacheFile', ...
        'OutputDirectory', 'InputFormat', 'DataSelector', ...
        'LoaderOptions', 'ExcludedChannels'});

    manifest = SPARQ.validateManifest(manifest);
end

% ------------------------------------------------------------------------
function files = normalizeSourceFiles(files)
    if ischar(files)
        files = string({files});
    elseif iscellstr(files)
        files = string(files);
    elseif ~isstring(files)
        error('SPARQ:createManifest:badSourceFiles', ...
            'sourceFiles must be text.');
    end
    files = files(:);
    if isempty(files) || any(ismissing(files)) || any(strlength(files) == 0)
        error('SPARQ:createManifest:badSourceFiles', ...
            'sourceFiles must contain at least one nonempty path.');
    end
end

% ------------------------------------------------------------------------
function values = expandText(values, nRows, name)
    if ~(ischar(values) || iscellstr(values) || isstring(values))
        error('SPARQ:createManifest:badTextColumn', ...
            '%s must contain text.', name);
    end
    values = string(values);
    values = values(:);
    if isscalar(values)
        values = repmat(values, nRows, 1);
    elseif numel(values) ~= nRows
        error('SPARQ:createManifest:columnLengthMismatch', ...
            '%s must be scalar or have %d entries.', name, nRows);
    end
end

% ------------------------------------------------------------------------
function values = expandNumeric(values, nRows, name)
    if ~isnumeric(values) || ~isreal(values)
        error('SPARQ:createManifest:badNumericColumn', ...
            '%s must be real numeric.', name);
    end
    values = double(values(:));
    if isscalar(values)
        values = repmat(values, nRows, 1);
    elseif numel(values) ~= nRows
        error('SPARQ:createManifest:columnLengthMismatch', ...
            '%s must be scalar or have %d entries.', name, nRows);
    end
end

% ------------------------------------------------------------------------
function values = expandStructCells(values, nRows, name)
    if nargin < 3
        name = 'LoaderOptions';
    end
    if isstruct(values) && isscalar(values)
        values = repmat({values}, nRows, 1);
    elseif iscell(values) && numel(values) == nRows && ...
            all(cellfun(@(x) isstruct(x) && isscalar(x), values))
        values = values(:);
    else
        error('SPARQ:createManifest:badStructColumn', ...
            '%s must be a scalar struct or one scalar struct per row.', name);
    end
end

% ------------------------------------------------------------------------
function values = expandNumericCells(values, nRows)
    if isnumeric(values) && isreal(values)
        values = repmat({values(:).'}, nRows, 1);
    elseif iscell(values) && numel(values) == nRows && ...
            all(cellfun(@(x) isnumeric(x) && isreal(x), values))
        values = cellfun(@(x) x(:).', values(:), 'UniformOutput', false);
    else
        error('SPARQ:createManifest:badExcludedChannels', ...
            'ExcludedChannels must be numeric or one numeric vector per row.');
    end
end
