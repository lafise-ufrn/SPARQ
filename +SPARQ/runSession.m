function result = runSession(matFilePath, outputDir, params)
% result = SPARQ.runSession(matFilePath, outputDir, params)
%
% Executa o pipeline completo para UM arquivo de sessão: carrega, seleciona a
% referência limpa (interativamente ou do cache), detecta o ruído, constrói os
% sinais limpos, plota opcionalmente cada etapa e salva opcionalmente o
% resultado. Este é o bloco de construção de sessão única que
% SPARQ.cleanExperiment chama uma vez por sujeito/condição durante uma
% execução em lote; também é a função a chamar diretamente quando o usuário
% quer processar apenas uma gravação (consulte demo/demo_singleSession.m).
%
% Esta função DETÉM a ordem das etapas interativas/visuais, mas delega todo o
% cálculo efetivo a SPARQ.processSession e todo o desenho efetivo a
% SPARQ.viz.*, permanecendo um orquestrador simples.
%
% ENTRADAS:
%   matFilePath = caminho absoluto para um único arquivo .mat de sessão
%   outputDir   = caminho absoluto para a pasta onde o cache de referência
%                 limpa e o .mat do sinal limpo são gravados. Também é usada
%                 como a pasta exibida quando a referência interativa precisa
%                 ser escolhida.
%   params      = estrutura de parâmetros (consulte defaultNoiseParameters).
%                 Campos lidos além dos usados por loadSession/processSession:
%       .plot.enabled = true  -> abre as figuras de visão geral/limiares/
%                       janelas de ruído/resumo e exige uma sessão gráfica
%                       (ou uma referência em cache) para selecionar o trecho
%                       de referência limpa
%                     = false -> não abre as figuras de processamento; uma
%                       referência manual em cache DEVE existir, pois não há
%                       figura para clicar
%
% SAÍDAS:
%   result = estrutura de SPARQ.processSession, isto é:
%       .subjectId, .condition, .sourceFile, .referenceIdx, .noise, .cleanSignals
%       .ratId permanece como alias legado de .subjectId.
%       O primeiro campo de cleanSignals é sempre `.noiseMask`; `.concat` e
%       `.nan` são incluídos apenas quando habilitados por params.output.
%
% NOTAS SOBRE A ORDEM DA PLOTAGEM:
%   Os limiares são desenhados depois da detecção porque
%   SPARQ.viz.withThresholds reutiliza noise.channelMean e noise.channelStd.
%   Assim, a visualização usa exatamente as estatísticas calculadas pelo
%   detector, sem recalculá-las por outro caminho.
%
% NOTAS SOBRE A REUTILIZACAO DE FIGURAS:
%   Cada FUNCAO de grafico (visao geral, limiares, janelas de ruido, resumo)
%   reutiliza uma unica figura identificada em cada chamada a runSession
%   (consulte SPARQ.internal.getOrCreateFigure / figureTags), em vez de
%   abrir uma nova janela toda vez. Assim, uma execucao em lote com muitos
%   sujeitos/condicoes nunca deixa mais de 4 figuras abertas; cada uma é limpa e
%   redesenhada para a sessão seguinte.

    if nargin < 3 || isempty(params)
        params = SPARQ.defaultOptions();
    end

    session = SPARQ.loadSession(matFilePath, params);
    tags = SPARQ.internal.figureTags();

    overviewAxes = [];
    if params.plot.enabled
        overviewFig = SPARQ.internal.getOrCreateFigure(tags.overview);
        overviewAxes = axes('Parent', overviewFig);
        SPARQ.viz.channels(session, params, overviewAxes);
    end

    [referenceIdx, ~, ~] = SPARQ.selectCleanReference( ...
        session, params, outputDir, overviewAxes);

    result = SPARQ.processSession(session, referenceIdx, params);

    if params.plot.enabled
        thresholdFig = SPARQ.internal.getOrCreateFigure(tags.thresholds);
        thresholdAxes = axes('Parent', thresholdFig);
        SPARQ.viz.channels(session, params, thresholdAxes);
        SPARQ.viz.withThresholds(thresholdAxes, session, result.noise, params);

        noiseFig = SPARQ.internal.getOrCreateFigure(tags.noiseWindows);
        noiseAxes = axes('Parent', noiseFig);
        SPARQ.viz.channels(session, params, noiseAxes);
        SPARQ.viz.withThresholds(noiseAxes, session, result.noise, params);
        SPARQ.viz.withNoiseWindows(noiseAxes, session, result.noise, params);

        summaryFig = SPARQ.internal.getOrCreateFigure(tags.summary);
        summaryAxes = axes('Parent', summaryFig);
        SPARQ.viz.preservationSummary(result.noise, ...
            SPARQ.internal.sessionTitle(session, params), summaryAxes);
    end

    SPARQ.saveCleanSignals(result, outputDir, params);
end

