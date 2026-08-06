function clean = buildCleanSignals(time, lfp, noiseWindows, areas, params)
% clean = SPARQ.internal.buildCleanSignals(time, lfp, noiseWindows, areas, params)
%
% Constrói as saídas do processamento a partir dos blocos de ruído detectados.
% A única e incondicional saída é uma máscara lógica de
% ruído com o comprimento total do sinal. O LFP restrito aos canais válidos
% também pode ser retornado de forma concatenada e/ou mascarada com NaN.
%
%
% ENTRADAS:
%   time         = vetor de tempo original 1xN
%   lfp          = matriz LFP bruta CxN
%   noiseWindows = blocos de ruído Kx2 [startSample endSample] (índices de
%                  amostra)
%   areas        = rótulos de área Cx1 (ou 1xC), um por canal adquirido
%   params       = estrutura de parâmetros (consulte defaultNoiseParameters).
%                  Campos:
%       .channels.*              = resolve o conjunto de canais válidos
%       .output.includeConcat    = inclui a matriz opcional `.concat`
%       .output.includeNaN       = inclui a matriz opcional `.nan`
%
% SAÍDAS:
%   clean = estrutura com os campos:
%       .noiseMask    = lógico 1xN, SEMPRE presente e sempre o PRIMEIRO
%                       campo. false (0) marca amostras não identificadas
%                       como ruído; true (1) marca amostras identificadas
%                       como ruído.
%       .concat       = matriz MxP contendo SOMENTE as amostras saudáveis,
%                       concatenadas em ordem temporal (menor, sem lacunas);
%                       presente apenas quando output.includeConcat é true.
%                       CUIDADO: toda junção entre trechos mantidos é uma
%                       descontinuidade / salto de fase; nunca filtre atraves dela.
%       .nan          = matriz MxN, com o MESMO comprimento da sessão, com as
%                       amostras ruidosas substituídas por NaN; presente
%                       apenas quando output.includeNaN é true. O eixo de
%                       tempo é preservado, portanto esta versão é a escolha
%                       correta quando o tempo absoluto importa.
%       .timeFull     = vetor de tempo original 1xN
%       .timeConcat   = timestamps originais 1xP das amostras mantidas. Como
%                       é descontínuo, é uma marca por amostra, não uma base
%                       temporal uniforme. Presente apenas com `.concat`.
%       .concatEdges  = índices (na série concatenada) da última amostra de
%                       cada trecho contínuo, isto é, posições imediatamente
%                       antes de uma junção. Use-os para segmentar por trecho
%                       e evitar filtrar através das emendas. Presente apenas
%                       com `.concat`.
%       .channels     = índices dos canais válidos usados (ordem das linhas
%                       de .nan / .concat)
%       .areas        = rótulos de área Mx1 desses canais
%       .noiseWindows = blocos de ruído Kx2 removidos
%
% OBSERVAÇÕES:
%   - `.noiseMask` retém todas as amostras originais e é a saída canônica.
%   - `.concat` troca um eixo de tempo correto por continuidade. Não trate seu
%     índice de coluna como tempo; use `.timeConcat` / `.concatEdges`.
%   - A ordem das linhas em `.nan` / `.concat` segue validChannels, NÃO a
%     ordem de aquisição bruta. Sempre indexe os resultados por meio de
%     `.channels` / `.areas`.

    validCh  = SPARQ.internal.validChannels(params);
    nSamples = numel(time);

    % --- Reconstrói a máscara lógica de ruído a partir dos pares [start end] ---
    isNoise = false(1, nSamples);
    for i = 1:size(noiseWindows, 1)
        isNoise(noiseWindows(i, 1):noiseWindows(i, 2)) = true;
    end
    cleanMask = ~isNoise;

    % Os campos de sinal são atribuídos deliberadamente na ordem pública de
    % saída: máscara obrigatória, sinal concatenado opcional, sinal com NaN
    % opcional.
    clean.noiseMask = isNoise;

    if params.output.includeConcat || params.output.includeNaN
        validLfp = lfp(validCh, :);
    end

    if params.output.includeConcat
        % --- Versão concatenada: somente amostras saudáveis ---
        clean.concat = validLfp(:, cleanMask);

        % Junções dentro da série concatenada: sempre que duas amostras
        % consecutivas mantidas NÃO eram adjacentes na gravação original, um
        % bloco de ruído foi removido entre elas.
        keptIdx = find(cleanMask);
        if isempty(keptIdx)
            concatEdges = [];
        else
            jumpAfter   = find(diff(keptIdx) > 1);
            concatEdges = jumpAfter(:).';
        end
    end

    if params.output.includeNaN
        % --- Versão com NaN: mesmo comprimento, tempo preservado ---
        nanVersion = validLfp;
        nanVersion(:, isNoise) = NaN;
        clean.nan = nanVersion;
    end

    clean.timeFull     = time;
    if params.output.includeConcat
        clean.timeConcat  = time(cleanMask);
        clean.concatEdges = concatEdges;
    end
    clean.channels     = validCh;
    clean.areas        = areas(validCh);
    clean.noiseWindows = noiseWindows;
end

