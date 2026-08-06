function [referenceIdx, referenceSeconds, wasCached] = selectCleanReference(session, params, cacheDir, axesHandle)
% [referenceIdx, referenceSeconds, wasCached] = SPARQ.selectCleanReference(session, params, cacheDir, axesHandle)
%
% Obtém os dois timestamps que delimitam um trecho da gravação escolhido
% manualmente e livre de artefatos, usado em outros pontos como referência de
% linha de base para a detecção de ruído (consulte
% SPARQ.internal.detectNoiseWindows). Este é o ÚNICO lugar da biblioteca
% que exige uma pessoa no circuito.
%
% A função abre uma interação de clique sobre a visão geral dos canais e mantém
% os dois timestamps na ordem temporal dos cliques. A coleta é vinculada aos
% eixos-alvo por SPARQ.internal.collectAxesClicks. A seleção pode ser armazenada
% em disco por sujeito/condição, de modo que:
%   - uma falha ou interrupção posterior na execução em lote nunca obriga o
%     usuário a clicar novamente em sessões já selecionadas;
%   - reexecutar a MESMA sessão com parâmetros de detecção diferentes ignora
%     completamente a etapa interativa.
%
% ENTRADAS:
%   session    = estrutura canonica (precisa de .subjectId, .condition,
%                .time e .events). .ratId ainda e aceito como alias legado.
%   params     = estrutura de parâmetros (consulte defaultNoiseParameters).
%                Campos lidos:
%       .channels.referenceEventStart / .referenceEventEnd = índices de eventos
%                   que delimitam o intervalo x oferecido para seleção
%       .io.cacheReferences     = se o arquivo de cache deve ser lido/gravado
%       .io.referenceCacheName  = nome-base usado para o arquivo de cache
%   cacheDir   = caminho absoluto para a pasta onde o cache de referência desta
%                sessão é armazenado (tipicamente a própria pasta de dados da
%                sessão). Obrigatório quando params.io.cacheReferences é true.
%   axesHandle = (opcional) eixos onde selecionar. Quando omitido, os eixos
%                atuais (gca) são usados.
%
% SAÍDAS:
%   referenceIdx     = índices de amostra em session.time / session.lfp cujos
%                      timestamps caem estritamente entre os dois pontos
%                      selecionados
%   referenceSeconds = 1x2 [startTime endTime], na mesma ordem em que o usuário
%                      clicou (ou na ordem armazenada em cache)
%   wasCached        = true quando a seleção foi carregada do disco, em vez de
%                      coletada interativamente
%
% OBSERVAÇÕES:
%   - O trecho de referência ancora toda média/desvio-padrão de linha de base
%     usada pela detecção. Selecionar um segmento que contenha artefatos
%     introduz silenciosamente viés em todos os limiares posteriores. Ao
%     reutilizar uma seleção em cache, confirme visualmente que ela ainda é
%     adequada se a gravação tiver sido reprocessada ou realinhada.
%   - Excluir o arquivo de cache de uma sessão força uma nova seleção
%     interativa na próxima execução.
%   - Antes de aguardar cliques, a figura-alvo é explicitamente trazida para
%     frente por meio de figure(fig) e atualizada com drawnow. Apenas chamar
%     axes(axesHandle) torna os eixos "atuais" internamente no MATLAB, mas não
%     toma de forma confiável o foco de mouse/teclado no nível do sistema
%     operacional (nem muda para a aba ativa, no modo acoplado) de uma
%     janela/figura criada
%     programaticamente; sem isso, a primeira sessao interativa de um lote
%     pode parecer aceitar nenhum clique (o grafico e desenhado, mas a janela/aba
%     nunca se torna ativa) ate que o usuario
%     O usuário clicar manualmente em alguma janela do MATLAB. Forçar o foco
%     remove essa dependência de intervenção manual.
%   - A coleta dos pontos é feita por
%     SPARQ.internal.collectAxesClicks, e não por um `ginput` simples,
%     porque a captura de cliques do ginput não é vinculada de forma confiável
%     a uma figura: se o figure() acima ainda não tiver concluído visualmente
%     a elevação quando o usuário clicar (por exemplo, uma troca de aba de
%     figura acoplada atrasada em uma atualização de tela), um ginput simples
%     pode registrar silenciosamente o clique em qualquer OUTRA figura
%     identificada (thresholds/noiseWindows/summary) ainda visível da sessão
%     anterior, em vez da nova visão geral. collectAxesClicks só conta cliques
%     cujo CurrentAxes é exatamente este handle de eixos; assim, um clique
%     perdido em outra aba é simplesmente ignorado, e não interpretado de
%     forma errada.

    if nargin < 3
        cacheDir = '';
    end
    if nargin < 4
        axesHandle = [];
    end

    cachePath = '';
    if params.io.cacheReferences
        if isempty(cacheDir)
            error('SPARQ:selectCleanReference:missingCacheDir', ...
                ['params.io.cacheReferences is true but no cacheDir was given. ' ...
                 'Pass an absolute folder path, or set params.io.cacheReferences = false.']);
        end
        subjectId = sessionSubjectId(session);
        cacheFile = sprintf('%s_%s_%s', subjectId, session.condition, ...
            params.io.referenceCacheName);
        cachePath = fullfile(cacheDir, cacheFile);
        if isfield(session, 'sourceFile') && ...
                SPARQ.internal.pathsEqual(cachePath, session.sourceFile)
            error('SPARQ:selectCleanReference:sourceOverwriteRefused', ...
                'Refusing to use the source recording as a reference cache: %s', ...
                cachePath);
        end
    end

    wasCached = false;
    referenceSeconds = [];
    if params.io.cacheReferences && exist(cachePath, 'file') == 2
        try
            cached = load(cachePath, 'referenceSeconds', 'cacheMetadata');
            if isValidCache(cached, session)
                referenceSeconds = double(cached.referenceSeconds(:).');
                wasCached = true;
            end
        catch
            % Cache truncado ou incompatível: trate como ausente. O arquivo
            % será substituído atomicamente após uma nova seleção válida.
        end
    end

    if ~wasCached
        if ~params.plot.enabled && isempty(axesHandle)
            error('SPARQ:selectCleanReference:manualReferenceMissing', ...
                ['No valid reference cache exists and plotting is disabled. ' ...
                 'Enable plotting and select the reference with two clicks.']);
        end
        referenceSeconds = pickReferenceInteractively( ...
            session, params, axesHandle);

        if params.io.cacheReferences
            if exist(cacheDir, 'dir') ~= 7
                mkdir(cacheDir);
            end
            cacheMetadata = buildCacheMetadata(session);
            saveCacheAtomically(cachePath, referenceSeconds, cacheMetadata);
        end
    end

    referenceIdx = find(session.time > referenceSeconds(1) & ...
                         session.time < referenceSeconds(2));
    if numel(referenceIdx) < 2
        error('SPARQ:selectCleanReference:referenceTooShort', ...
            'The selected reference interval contains fewer than two samples.');
    end
end

% ------------------------------------------------------------------------
function subjectId = sessionSubjectId(session)
    if isfield(session, 'subjectId') && strlength(string(session.subjectId)) > 0
        subjectId = string(session.subjectId);
    elseif isfield(session, 'ratId') && strlength(string(session.ratId)) > 0
        subjectId = string(session.ratId);
    else
        error('SPARQ:selectCleanReference:missingSubjectId', ...
            'session.subjectId is required to name the reference cache.');
    end
end

% ------------------------------------------------------------------------
function referenceSeconds = pickReferenceInteractively(session, params, axesHandle)
    if isempty(axesHandle)
        axesHandle = gca;
    end

    % Traz e foca a janela/aba real antes de bloquear aguardando cliques:
    % apenas axes() atualiza os ponteiros internos de "eixos/figura atuais"
    % do MATLAB; não fornece de modo confiável o foco de entrada da janela no
    % nível do sistema operacional nem muda para a aba acoplada ativa.
    figureHandle = ancestor(axesHandle, 'figure');
    figure(figureHandle);
    axes(axesHandle);
    drawnow;

    startEvent = params.channels.referenceEventStart;
    endEvent   = params.channels.referenceEventEnd;
    xlim(axesHandle, [session.events(startEvent), session.events(endEvent)]);

    clickedSeconds = SPARQ.internal.collectAxesClicks(axesHandle, 2);
    referenceSeconds = sort(double(clickedSeconds(:).'));
end

% ------------------------------------------------------------------------
function valid = isValidCache(cached, session)
    valid = isfield(cached, 'referenceSeconds');
    if ~valid
        return;
    end
    interval = cached.referenceSeconds;
    valid = isnumeric(interval) && isreal(interval) && numel(interval) == 2 && ...
        all(isfinite(interval)) && interval(2) > interval(1) && ...
        nnz(session.time > interval(1) & session.time < interval(2)) >= 2;
    if ~valid || ~isfield(cached, 'cacheMetadata')
        return; % caches legados continuam aceitos se o intervalo ainda for válido
    end

    expected = buildCacheMetadata(session);
    actual = cached.cacheMetadata;
    required = {'schemaVersion', 'nSamples', 'timeBounds', 'sourceToken'};
    if ~isstruct(actual) || ~all(isfield(actual, required))
        valid = false;
        return;
    end
    valid = string(actual.schemaVersion) == expected.schemaVersion && ...
        isequal(actual.nSamples, expected.nSamples) && ...
        isequaln(double(actual.timeBounds), expected.timeBounds) && ...
        string(actual.sourceToken) == expected.sourceToken;
end

% ------------------------------------------------------------------------
function metadata = buildCacheMetadata(session)
    metadata.schemaVersion = "1.0";
    metadata.nSamples = size(session.lfp, 2);
    metadata.timeBounds = double([session.time(1), session.time(end)]);
    if isfield(session, 'sourceFile') && strlength(string(session.sourceFile)) > 0
        source = SPARQ.internal.sourceIdentity(session.sourceFile);
        metadata.sourceToken = source.token;
    else
        metadata.sourceToken = "in-memory";
    end
end

% ------------------------------------------------------------------------
function saveCacheAtomically(cachePath, referenceSeconds, cacheMetadata)
    if exist(cachePath, 'file') == 2 && ...
            ~SPARQ.internal.isReferenceCacheFile(cachePath)
        error('SPARQ:selectCleanReference:unsafeCacheOverwriteRefused', ...
            ['Refusing to overwrite an existing MAT file that is not a ' ...
             'recognized SPARQ reference cache: %s'], cachePath);
    end
    cacheDir = fileparts(cachePath);
    temporaryPath = [tempname(cacheDir) '.mat'];
    cleanupObject = onCleanup(@() deleteIfPresent(temporaryPath));
    save(temporaryPath, 'referenceSeconds', 'cacheMetadata');
    [moved, message] = movefile(temporaryPath, cachePath, 'f');
    if ~moved
        error('SPARQ:selectCleanReference:cacheWriteFailed', '%s', message);
    end
end

% ------------------------------------------------------------------------
function deleteIfPresent(filePath)
    if exist(filePath, 'file') == 2
        delete(filePath);
    end
end
