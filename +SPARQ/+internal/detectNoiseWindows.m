function noise = detectNoiseWindows(time, lfp, referenceIdx, params)
% noise = SPARQ.internal.detectNoiseWindows(time, lfp, referenceIdx, params)
%
% Detecta segmentos ruidosos em uma gravação LFP multicanal. Uma amostra é
% candidata a ruído quando canais suficientes se desviam simultaneamente de
% sua linha de base em mais de <thresholdStd> desvios-padrão. Candidatas
% próximas são mescladas em blocos, e cada bloco é então expandido para fora,
% canal por canal, até que o sinal "se estabilize" novamente dentro de uma
% faixa de tolerância. A união dos blocos expandidos é a máscara de ruído final.
%
% A aritmética, os limiares e o fluxo de controle deste detector são um
% algoritmo numérico estável. Mudanças exigem verificação.
%
% ENTRADAS:
%   time         = vetor de tempo 1xN (amostras nas colunas de `lfp`)
%   lfp          = matriz LFP bruta CxN (C = total de canais adquiridos)
%   referenceIdx = índices (nas colunas de `lfp`) de um trecho limpo escolhido
%                  manualmente, usado para estimar a média e o desvio-padrão
%                  da linha de base de cada canal
%   params       = estrutura de parâmetros (consulte defaultNoiseParameters).
%                  Campos lidos:
%       .detection.thresholdStd            (k_std)      = desvios para o
%                   limiar de candidata por canal
%       .detection.minSimultaneousChannels (n_threshold)= quantos canais devem
%                   exceder o limiar na mesma amostra
%       .detection.mergeGapSamples         (gap_limit)  = lacuna máxima
%                   (amostras) entre candidatas que ainda são fundidas em um
%                   único bloco
%       .detection.settleWindowSamples     (buffer)     = janela de observação
%                   à frente/atrás usada ao expandir um bloco
%       .detection.settleToleranceStd                   = desvios que definem
%                   a faixa "estabilizada" durante a expansão do bloco
%       .channels.count / .channels.excluded            = definição da montagem
%
% SAÍDAS:
%   noise = estrutura que descreve o ruído detectado, com os campos:
%       .windows      = blocos Kx2 [startSample endSample], em ÍNDICES DE
%                       AMOSTRA (colunas de time/lfp), já mesclados entre
%                       canais. Para recortar do LFP:
%                           lfp(:, noise.windows(i,1):noise.windows(i,2))
%                       Para converter em segundos: time(noise.windows(i,:))
%       .mask         = lógico 1xN, true onde a amostra é ruído
%       .percentSaved = porcentagem da sessão mantida (fora do ruído)
%       .percentNoise = porcentagem da sessão descartada (dentro do ruído)
%       .channelMean  = média de linha de base 1xM por canal válido (ordem de
%                       SPARQ.internal.validChannels)
%       .channelStd   = desvio-padrão de linha de base 1xM por canal válido,
%                       na mesma ordem
%
% OBSERVAÇÕES:
%   - As estatísticas da linha de base vêm INTEIRAMENTE de `referenceIdx`.
%     Um trecho de referência mal escolhido desloca todos os limiares e,
%     portanto, todas as janelas detectadas. Escolha um intervalo realmente
%     silencioso e livre de artefatos.
%   - A expansão do bloco percorre amostra por amostra e para nas bordas da
%     gravação. Se um canal nunca se estabilizar (o ruído alcançar exatamente
%     o início/fim da sessão), o bloco se expande até essa borda. Isso é
%     intencional, mas pode ocultar silenciosamente uma gravação de baixa
%     qualidade; inspecione o resumo de preservação quando uma sessão
%     reportar porcentagens descartadas muito altas.

    validCh = SPARQ.internal.validChannels(params);
    nValid  = numel(validCh);
    nSamples = numel(time);

    kStd            = params.detection.thresholdStd;
    minChannels     = params.detection.minSimultaneousChannels;
    mergeGap        = params.detection.mergeGapSamples;
    settleWindow    = params.detection.settleWindowSamples;
    settleTolStd    = params.detection.settleToleranceStd;

    % --- Estatísticas da linha de base por canal válido, da referência limpa ---
    channelMean = zeros(1, nValid);
    channelStd  = zeros(1, nValid);
    for ch = 1:nValid
        channel = validCh(ch);
        channelMean(ch) = mean(lfp(channel, referenceIdx));
        channelStd(ch)  = std(lfp(channel, referenceIdx));
    end

    % Conta os canais candidatos incrementalmente, sem materializar a matriz
    % lógica CxN. No mesmo passe, prepara os intervalos usados pela expansão.
    % Isso reduz o pico de memória e evita recalcular abs(lfp - baseline).
    candidateState = [];
    unstableLeft = cell(1, nValid);
    unstableRight = cell(1, nValid);
    for ch = 1:nValid
        channel = validCh(ch);
        deviation = abs(lfp(channel, :) - channelMean(ch));
        exceedsThreshold = deviation > kStd * channelStd(ch);
        if ch == 1
            if minChannels == 1 || minChannels == nValid
                candidateState = exceedsThreshold;
            else
                candidateState = uint16(exceedsThreshold);
            end
        elseif minChannels == 1
            candidateState = candidateState | exceedsThreshold;
        elseif minChannels == nValid
            candidateState = candidateState & exceedsThreshold;
        else
            candidateState = candidateState + uint16(exceedsThreshold);
        end

        candidateThreshold = kStd * channelStd(ch);
        settleTol = settleTolStd * channelStd(ch);
        if isequal(settleTol, candidateThreshold)
            bad = find(exceedsThreshold);
        else
            bad = find(deviation > settleTol);
        end
        [unstableLeft{ch}, unstableRight{ch}] = ...
            pointInfluenceIntervals(bad, settleWindow, nSamples);
        if any(isnan(deviation))
            valid = find(~isnan(deviation));
            unstableLeft{ch} = mergeIntervals([unstableLeft{ch}; ...
                allNaNIntervals(valid, settleWindow, nSamples, "left")]);
            unstableRight{ch} = mergeIntervals([unstableRight{ch}; ...
                allNaNIntervals(valid, settleWindow, nSamples, "right")]);
        end
    end
    if minChannels == 1 || minChannels == nValid
        candidateSamples = find(candidateState);
    else
        candidateSamples = find(candidateState >= minChannels);
    end

    isNoise = false(1, nSamples);

    if ~isempty(candidateSamples)
        % --- Funde candidatas que estejam a até `mergeGap` umas das outras ---
        segmentBreaks = find(diff(candidateSamples) > mergeGap);
        blockStarts = candidateSamples([1, segmentBreaks + 1]);
        blockEnds   = candidateSamples([segmentBreaks, end]);

        for b = 1:numel(blockStarts)
            expandedLeft  = blockStarts(b);
            expandedRight = blockEnds(b);

            % Cada consulta salta diretamente sobre a amostra que impede a
            % janela de ser estável. O resultado é o mesmo primeiro endpoint
            % encontrado pelos while-loops originais.
            for ch = 1:nValid
                idxLeft = stableLeftBound( ...
                    unstableLeft{ch}, blockStarts(b));
                idxRight = stableRightBound( ...
                    unstableRight{ch}, blockEnds(b), nSamples);

                if idxLeft < expandedLeft
                    expandedLeft = idxLeft;
                end
                if idxRight > expandedRight
                    expandedRight = idxRight;
                end
            end

            isNoise(expandedLeft:expandedRight) = true;
        end
    end

    % --- Converte a máscara lógica em pares de índices de amostra [start end] ---
    maskEdges   = diff([0, isNoise, 0]);
    windowStarts = find(maskEdges == 1);
    windowEnds   = find(maskEdges == -1) - 1;
    windows = [windowStarts(:), windowEnds(:)];

    noiseSamples = sum(isNoise);
    savedSamples = nSamples - noiseSamples;

    noise.windows      = windows;
    noise.mask         = isNoise;
    noise.percentNoise = (noiseSamples / nSamples) * 100;
    noise.percentSaved = (savedSamples / nSamples) * 100;
    noise.channelMean  = channelMean;
    noise.channelStd   = channelStd;
end

% -------------------------------------------------------------------------
function index = stableLeftBound(intervals, blockStart)
% Localiza diretamente o primeiro endpoint estável visitado à esquerda.
    containing = find(intervals(:, 1) <= blockStart & ...
        intervals(:, 2) >= blockStart, 1, 'last');
    if isempty(containing)
        index = blockStart;
    else
        index = max(1, intervals(containing, 1) - 1);
    end
end

% -------------------------------------------------------------------------
function index = stableRightBound(intervals, blockEnd, nSamples)
% Localiza diretamente o primeiro endpoint estável visitado à direita.
    containing = find(intervals(:, 1) <= blockEnd & ...
        intervals(:, 2) >= blockEnd, 1, 'last');
    if isempty(containing)
        index = blockEnd;
    else
        index = min(nSamples, intervals(containing, 2) + 1);
    end
end

% -------------------------------------------------------------------------
function [leftIntervals, rightIntervals] = pointInfluenceIntervals( ...
        points, window, nSamples)
% Une os endpoints cujas janelas contêm ao menos uma amostra instável.
    if isempty(points)
        leftIntervals = zeros(0, 2);
        rightIntervals = zeros(0, 2);
        return;
    end
    breaks = find(diff(points) > window + 1);
    first = points([1, breaks + 1]);
    last = points([breaks, end]);
    leftIntervals = [first(:), min(nSamples, last(:) + window)];
    rightIntervals = [max(1, first(:) - window), last(:)];
end

% -------------------------------------------------------------------------
function intervals = allNaNIntervals(valid, window, nSamples, direction)
% Endpoints cujas janelas são integralmente NaN (max devolve NaN).
    padded = [0, valid, nSamples + 1];
    gaps = find(diff(padded) > 1);
    runStarts = padded(gaps) + 1;
    runEnds = padded(gaps + 1) - 1;
    if direction == "left"
        starts = runStarts + window;
        starts(runStarts == 1) = 1;
        keep = starts <= runEnds;
        intervals = [starts(keep).', runEnds(keep).'];
    else
        ends = runEnds - window;
        ends(runEnds == nSamples) = nSamples;
        keep = runStarts <= ends;
        intervals = [runStarts(keep).', ends(keep).'];
    end
end

% -------------------------------------------------------------------------
function merged = mergeIntervals(intervals)
    if isempty(intervals)
        merged = zeros(0, 2);
        return;
    end
    intervals = sortrows(intervals, [1 2]);
    startsNew = [true; intervals(2:end, 1) > ...
        cummax(intervals(1:end-1, 2)) + 1];
    groups = cumsum(startsNew);
    merged = [accumarray(groups, intervals(:, 1), [], @min), ...
        accumarray(groups, intervals(:, 2), [], @max)];
end
