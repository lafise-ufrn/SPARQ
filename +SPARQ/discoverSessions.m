function manifest = discoverSessions(sources, varargin)
% manifest = SPARQ.discoverSessions(sources, Name, Value, ...)
%
% Inspeciona arquivos MAT e cria uma linha de metadados para
% cada sessao encontrada, sem processar ou salvar os sinais.
%
% PARES NOME-VALOR:
%   'InputFormat'   = "auto" (padrao)
%   'LoaderOptions' = struct escalar ou uma struct unica para cada fonte

    sources = normalizeSources(sources);
    parser = inputParser();
    parser.FunctionName = 'SPARQ.discoverSessions';
    addParameter(parser, 'InputFormat', "auto");
    addParameter(parser, 'LoaderOptions', struct());
    parse(parser, varargin{:});

    formats = expandText(parser.Results.InputFormat, numel(sources));
    loaderOptions = expandStructs(parser.Results.LoaderOptions, numel(sources));

    manifests = cell(numel(sources), 1);
    for i = 1:numel(sources)
        options = loaderOptions{i};
        options.inputFormat = formats(i);
        reader = SPARQ.io.SourceReader(sources(i), options);
        cleanupObject = onCleanup(@() reader.close());
        inventory = reader.inspect();
        n = numel(inventory);
        selectors = arrayfun(@(x) x.DataSelector, inventory, ...
            'UniformOutput', false).';
        rowOptions = repmat(loaderOptions(i), n, 1);
        manifests{i} = SPARQ.createManifest(repmat(sources(i), n, 1), ...
            'SubjectId', string({inventory.SubjectId}).', ...
            'SessionId', string({inventory.SessionId}).', ...
            'Condition', string({inventory.Condition}).', ...
            'SamplingRateHz', [inventory.SamplingRateHz].', ...
            'InputFormat', repmat(reader.InputFormat, n, 1), ...
            'DataSelector', selectors, ...
            'LoaderOptions', rowOptions);
        clear cleanupObject;
    end
    manifest = vertcat(manifests{:});
    manifest = SPARQ.validateManifest(manifest);
end

function sources = normalizeSources(sources)
    if ischar(sources) || (isstring(sources) && isscalar(sources))
        sources = string(sources);
    elseif iscellstr(sources) || isstring(sources)
        sources = string(sources(:));
    else
        error('SPARQ:discoverSessions:badSources', ...
            'sources must contain text paths.');
    end
    sources = sources(:);
    if isempty(sources) || any(ismissing(sources)) || any(strlength(sources) == 0)
        error('SPARQ:discoverSessions:badSources', ...
            'sources must contain at least one nonempty path.');
    end
end

function values = expandText(values, n)
    if ~(ischar(values) || iscellstr(values) || isstring(values))
        error('SPARQ:discoverSessions:badInputFormat', ...
            'InputFormat must contain text.');
    end
    if ischar(values)
        values = string({values});
    else
        values = string(values(:));
    end
    if isscalar(values)
        values = repmat(values, n, 1);
    elseif numel(values) ~= n
        error('SPARQ:discoverSessions:formatCountMismatch', ...
            'InputFormat must be scalar or have one value per source.');
    end
end

function values = expandStructs(values, n)
    if isstruct(values) && isscalar(values)
        values = repmat({values}, n, 1);
    elseif iscell(values) && numel(values) == n && ...
            all(cellfun(@(x) isstruct(x) && isscalar(x), values))
        values = values(:);
    else
        error('SPARQ:discoverSessions:badLoaderOptions', ...
            'LoaderOptions must be scalar or contain one scalar struct per source.');
    end
end
