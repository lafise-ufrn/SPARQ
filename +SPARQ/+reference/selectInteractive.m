function [referenceIdx, referenceInfo] = selectInteractive(session, varargin)
% [referenceIdx, referenceInfo] = SPARQ.reference.selectInteractive(session, Name, Value)
%
% Permite escolher visualmente um trecho limpo de uma sessao generica. Os
% canais sao mostrados em eixos empilhados, todos com o mesmo eixo temporal e
% cada um em sua escala original. Dois cliques definem o inicio e o fim.
%
% PARES NOME-VALOR:
%   'ExcludedChannels' = indices de canais que nao serao exibidos; padrao []
%   'CacheFile'        = arquivo .mat opcional para reutilizar a selecao
%   'ForceNew'         = true ignora um cache valido; padrao false
%   'MaxDisplayPoints' = limite aproximado por canal; padrao 20000. Quando a
%                        gravacao excede esse limite, um envelope minimo/
%                        maximo reduz somente o desenho, nunca os dados
%   'ShowOverview'    = mostra a figura mesmo quando a referencia vem do
%                       cache; padrao false
%   'SelectionProvider' = callback opcional (session -> [inicio fim]) para
%                         execucao deterministica sem cliques
%
% SAIDAS:
%   referenceIdx  = indices inclusivos do intervalo em session.time
%   referenceInfo = metodo, intervalo, indices, cache e identidade da fonte
%
% OBSERVAÇÕES:
%   - O cache e aceito somente quando a fonte, o numero de amostras e os
%     limites temporais continuam identicos.
%   - Esta funcao e independente de eventos, ratos/subjects e condicoes do fluxo
%     esteira/odor. SPARQ.selectCleanReference permanece inalterada.

    validateSession(session);
    parser = inputParser();
    parser.FunctionName = 'SPARQ.reference.selectInteractive';
    addParameter(parser, 'ExcludedChannels', []);
    addParameter(parser, 'CacheFile', "");
    addParameter(parser, 'ForceNew', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'MaxDisplayPoints', 20000, ...
        @(x) isnumeric(x) && isreal(x) && isscalar(x) && isfinite(x) && ...
        x >= 100 && x == round(x));
    addParameter(parser, 'ShowOverview', false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'SelectionProvider', [], ...
        @(x) isempty(x) || isa(x, 'function_handle'));
    parse(parser, varargin{:});
    options = parser.Results;

    channels = validateExcludedChannels( ...
        options.ExcludedChannels, size(session.lfp, 1));
    cacheFile = normalizeCacheFile(options.CacheFile);
    cacheMetadata = buildCacheMetadata(session);
    if strlength(cacheFile) > 0 && isfield(session, 'sourceFile') && ...
            SPARQ.internal.pathsEqual(cacheFile, session.sourceFile)
        error('SPARQ:reference:selectInteractive:sourceOverwriteRefused', ...
            'Refusing to use the source recording as a reference cache: %s', ...
            cacheFile);
    end

    wasCached = false;
    referenceSeconds = [];
    if ~options.ForceNew && strlength(cacheFile) > 0 && isfile(cacheFile)
        try
            cached = load(cacheFile, 'referenceSeconds', 'cacheMetadata');
            if isValidCache(cached, session, cacheMetadata)
                referenceSeconds = double(cached.referenceSeconds(:).');
                wasCached = true;
            end
        catch
            % Cache incompleto ou corrompido: uma nova selecao o substituira.
        end
    end

    axesHandles = gobjects(0);
    clickBoundsDrawn = false;
    if options.ShowOverview
        axesHandles = drawSelectionFigure( ...
            session, channels, options.MaxDisplayPoints);
    end

    if ~wasCached
        if isempty(axesHandles) && isempty(options.SelectionProvider)
            axesHandles = drawSelectionFigure( ...
                session, channels, options.MaxDisplayPoints);
        end
        if isempty(options.SelectionProvider)
            clickedSeconds = collectClicks(axesHandles, 2);
            clickBoundsDrawn = true;
        else
            clickedSeconds = options.SelectionProvider(session);
        end
        referenceSeconds = validateAndSortInterval(clickedSeconds, session.time);
        if strlength(cacheFile) > 0
            saveCacheAtomically(cacheFile, referenceSeconds, cacheMetadata);
        end
    end
    if ~isempty(axesHandles) && ~clickBoundsDrawn
        drawReferenceBounds(axesHandles, referenceSeconds);
    end

    referenceIdx = find(session.time >= referenceSeconds(1) & ...
        session.time <= referenceSeconds(2));
    referenceIdx = referenceIdx(:).';
    if numel(referenceIdx) < 2
        error('SPARQ:reference:selectInteractive:tooShort', ...
            'A referencia selecionada deve conter ao menos duas amostras.');
    end
    referenceInfo.units = "seconds";
    referenceInfo.interval = referenceSeconds;
    referenceInfo.indices = [referenceIdx(1), referenceIdx(end)];
    referenceInfo.sampleCount = numel(referenceIdx);
    referenceInfo.method = "interactive-selection";
    referenceInfo.wasCached = wasCached;
    referenceInfo.cacheFile = cacheFile;
    referenceInfo.sourceIdentity = cacheMetadata.sourceIdentity;
end

% ------------------------------------------------------------------------
function drawReferenceBounds(axesHandles, referenceSeconds)
    for pointIndex = 1:numel(referenceSeconds)
        SPARQ.internal.drawReferenceMarker( ...
            axesHandles, referenceSeconds(pointIndex));
    end
    drawnow;
end

% ------------------------------------------------------------------------
function validateSession(session)
    valid = isstruct(session) && isscalar(session) && ...
        isfield(session, 'lfp') && isfield(session, 'time') && ...
        isnumeric(session.lfp) && ismatrix(session.lfp) && ...
        isnumeric(session.time) && isvector(session.time) && ...
        size(session.lfp, 2) == numel(session.time) && ...
        size(session.lfp, 1) >= 1 && size(session.lfp, 2) >= 2;
    if ~valid
        error('SPARQ:reference:selectInteractive:badSession', ...
            'session deve conter lfp e time consistentes.');
    end
end

% ------------------------------------------------------------------------
function channels = validateExcludedChannels(excluded, nChannels)
    if ~isnumeric(excluded) || ~isreal(excluded) || ...
            (~isempty(excluded) && ~isvector(excluded)) || ...
            any(~isfinite(excluded)) || any(excluded ~= round(excluded)) || ...
            any(excluded < 1) || any(excluded > nChannels) || ...
            numel(unique(excluded)) ~= numel(excluded)
        error('SPARQ:reference:selectInteractive:badExcludedChannels', ...
            'ExcludedChannels deve conter indices unicos entre 1 e %d.', nChannels);
    end
    channels = setdiff(1:nChannels, excluded(:).');
    if isempty(channels)
        error('SPARQ:reference:selectInteractive:noChannels', ...
            'Ao menos um canal deve permanecer visivel.');
    end
end

% ------------------------------------------------------------------------
function cacheFile = normalizeCacheFile(value)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('SPARQ:reference:selectInteractive:badCacheFile', ...
            'CacheFile deve ser um texto escalar.');
    end
    cacheFile = string(value);
    if strlength(cacheFile) > 0
        [~, ~, extension] = fileparts(cacheFile);
        if ~strcmpi(extension, '.mat')
            error('SPARQ:reference:selectInteractive:badCacheFile', ...
                'CacheFile deve usar a extensao .mat.');
        end
    end
end

% ------------------------------------------------------------------------
function metadata = buildCacheMetadata(session)
    metadata.schemaVersion = "1.0";
    metadata.nSamples = size(session.lfp, 2);
    metadata.timeBounds = double([session.time(1), session.time(end)]);
    if isfield(session, 'sourceFile') && strlength(string(session.sourceFile)) > 0
        metadata.sourceIdentity = ...
            SPARQ.internal.sourceIdentity(session.sourceFile);
    else
        metadata.sourceIdentity.path = "";
        metadata.sourceIdentity.exists = false;
        metadata.sourceIdentity.bytes = NaN;
        metadata.sourceIdentity.modifiedDatenum = NaN;
        metadata.sourceIdentity.token = "in-memory";
    end
end

% ------------------------------------------------------------------------
function valid = isValidCache(cached, session, expectedMetadata)
    valid = isfield(cached, 'referenceSeconds') && ...
        isfield(cached, 'cacheMetadata');
    if ~valid
        return;
    end
    actual = cached.cacheMetadata;
    required = {'schemaVersion', 'nSamples', 'timeBounds', 'sourceIdentity'};
    valid = isstruct(actual) && isscalar(actual) && all(isfield(actual, required));
    if ~valid || ~all(isfield(actual.sourceIdentity, {'path', 'token'}))
        return;
    end
    valid = string(actual.schemaVersion) == expectedMetadata.schemaVersion && ...
        isequal(actual.nSamples, expectedMetadata.nSamples) && ...
        isequaln(double(actual.timeBounds), expectedMetadata.timeBounds) && ...
        string(actual.sourceIdentity.path) == expectedMetadata.sourceIdentity.path && ...
        string(actual.sourceIdentity.token) == expectedMetadata.sourceIdentity.token;
    if valid
        try
            validateAndSortInterval(cached.referenceSeconds, session.time);
        catch
            valid = false;
        end
    end
end

% ------------------------------------------------------------------------
function axesHandles = drawSelectionFigure(session, channels, maxDisplayPoints)
    tags = SPARQ.internal.figureTags();
    figureHandle = SPARQ.internal.getOrCreateFigure(tags.overview);
    set(figureHandle, 'Name', 'SPARQ - selecao de referencia limpa', ...
        'NumberTitle', 'off');
    axesHandles = axes('Parent', figureHandle);
    params = SPARQ.processingOptions(size(session.lfp, 1));
    params.channels.excluded = setdiff(1:size(session.lfp, 1), channels);
    SPARQ.viz.channels(session, params, axesHandles, ...
        'MaxDisplayPoints', maxDisplayPoints);
    sessionTitle = SPARQ.internal.sessionTitle(session, params);
    title(axesHandles, {sessionTitle, ...
        'Escolha um trecho sem ruido para a referencia', ...
        'Clique no INICIO e depois no FIM do trecho'}, ...
        'FontWeight', 'bold');
    figure(figureHandle);
    drawnow;
end

% ------------------------------------------------------------------------
function points = collectClicks(axesHandles, numPoints)
    figureHandle = ancestor(axesHandles(1), 'figure');
    points = zeros(numPoints, 1);
    collected = 0;
    previousCallback = get(figureHandle, 'WindowButtonDownFcn');
    cleanupObject = onCleanup(@() restoreCallback( ...
        figureHandle, previousCallback));
    set(figureHandle, 'WindowButtonDownFcn', @onClick);

    while collected < numPoints
        if ~isvalid(figureHandle)
            error('SPARQ:reference:selectInteractive:figureClosed', ...
                'A figura foi fechada antes dos dois cliques.');
        end
        drawnow limitrate;
        pause(0.02);
    end

    function onClick(source, ~)
        clickedAxes = get(source, 'CurrentAxes');
        if isempty(clickedAxes) || ~any(clickedAxes == axesHandles)
            return;
        end
        currentPoint = get(clickedAxes, 'CurrentPoint');
        collected = collected + 1;
        points(collected) = currentPoint(1, 1);
        SPARQ.internal.drawReferenceMarker( ...
            axesHandles, points(collected));
        drawnow;
    end
end

% ------------------------------------------------------------------------
function restoreCallback(figureHandle, callback)
    if isvalid(figureHandle)
        set(figureHandle, 'WindowButtonDownFcn', callback);
    end
end

% ------------------------------------------------------------------------
function interval = validateAndSortInterval(value, time)
    if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 2 || ...
            any(~isfinite(value))
        error('SPARQ:reference:selectInteractive:badSelection', ...
            'A selecao deve conter exatamente dois tempos finitos.');
    end
    interval = sort(double(value(:).'));
    if interval(2) <= interval(1) || interval(1) < time(1) || ...
            interval(2) > time(end)
        error('SPARQ:reference:selectInteractive:badSelection', ...
            'Os cliques devem definir um intervalo dentro da gravacao.');
    end
end

% ------------------------------------------------------------------------
function saveCacheAtomically(cacheFile, referenceSeconds, cacheMetadata)
    cacheFile = char(cacheFile);
    if exist(cacheFile, 'file') == 2 && ...
            ~SPARQ.internal.isReferenceCacheFile(cacheFile)
        error('SPARQ:reference:selectInteractive:unsafeCacheOverwriteRefused', ...
            ['Refusing to overwrite an existing MAT file that is not a ' ...
             'recognized SPARQ reference cache: %s'], cacheFile);
    end
    cacheDirectory = fileparts(cacheFile);
    if exist(cacheDirectory, 'dir') ~= 7
        [created, message] = mkdir(cacheDirectory);
        if ~created
            error('SPARQ:reference:selectInteractive:cacheMkdirFailed', ...
                '%s', message);
        end
    end
    temporaryFile = [tempname(cacheDirectory) '.mat'];
    cleanupObject = onCleanup(@() deleteIfPresent(temporaryFile));
    save(temporaryFile, 'referenceSeconds', 'cacheMetadata');
    [moved, message] = movefile(temporaryFile, cacheFile, 'f');
    if ~moved
        error('SPARQ:reference:selectInteractive:cacheWriteFailed', ...
            '%s', message);
    end
end

% ------------------------------------------------------------------------
function deleteIfPresent(filePath)
    if exist(filePath, 'file') == 2
        delete(filePath);
    end
end
