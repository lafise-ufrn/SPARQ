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

    % --- Amostras candidatas: canais suficientes desviando ao mesmo tempo ---
    % As transposições em vetores-coluna transmitem a linha de base de cada
    % canal para todas as amostras.
    validLfp        = lfp(validCh, :);
    exceedsBaseline = abs(validLfp - channelMean') > kStd * channelStd';
    candidateSamples = find(sum(exceedsBaseline) >= minChannels);

    isNoise = false(1, nSamples);

    if ~isempty(candidateSamples)
        % --- Funde candidatas que estejam a até `mergeGap` umas das outras ---
        segmentBreaks = find(diff(candidateSamples) > mergeGap);
        blockStarts = candidateSamples([1, segmentBreaks + 1]);
        blockEnds   = candidateSamples([segmentBreaks, end]);

        for b = 1:numel(blockStarts)
            expandedLeft  = blockStarts(b);
            expandedRight = blockEnds(b);

            % Expande o bloco por canal até que o sinal volte a se estabilizar
            % dentro de sua faixa de tolerância em ambos os lados.
            for ch = 1:nValid
                channel      = validCh(ch);
                baseline     = channelMean(ch);
                settleTol    = settleTolStd * channelStd(ch);

                idxLeft = blockStarts(b);
                while idxLeft > 1
                    searchStart = max(1, idxLeft - settleWindow);
                    windowPeak = max(abs(lfp(channel, searchStart:idxLeft) - baseline));
                    if windowPeak <= settleTol
                        break;
                    end
                    idxLeft = idxLeft - 1;
                end

                idxRight = blockEnds(b);
                while idxRight < nSamples
                    searchEnd = min(nSamples, idxRight + settleWindow);
                    windowPeak = max(abs(lfp(channel, idxRight:searchEnd) - baseline));
                    if windowPeak <= settleTol
                        break;
                    end
                    idxRight = idxRight + 1;
                end

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
