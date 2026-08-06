function axesHandle = withThresholds(axesHandle, session, noise, params)
% axesHandle = SPARQ.viz.withThresholds(axesHandle, session, noise, params)
%
% Sobrepõe, a um gráfico existente de SPARQ.viz.channels, as linhas de
% limiar superior/inferior tracejadas em vermelho contra as quais a amplitude
% de cada canal é comparada durante a detecção de ruído (média +
% thresholdStd * desvio-padrão, a partir das mesmas estatísticas de linha de
% base usadas por detectNoiseWindows).
%
% Reutiliza noise.channelMean / noise.channelStd calculados pelo detector, para
% que a visualização e a detecção usem as mesmas estatísticas de referência.
%
% ENTRADAS:
%   axesHandle = eixos retornados anteriormente por SPARQ.viz.channels
%   session    = estrutura de SPARQ.loadSession
%   noise      = estrutura de SPARQ.internal.detectNoiseWindows (precisa
%                de .channelMean, .channelStd, na ordem de validChannels)
%   params     = estrutura de parâmetros (consulte defaultNoiseParameters).
%                Campos lidos:
%       .plot.thresholdStd = multiplicador do desvio-padrão para as linhas de
%                            limiar (mantido separado de
%                            detection.thresholdStd para que a faixa exibida
%                            possa diferir da faixa de detecção, se o usuário
%                            quiser; os padrões são iguais)
%
% SAÍDAS:
%   axesHandle = os mesmos eixos, para encadeamento

    layout = SPARQ.internal.plotLayout(session, params);
    kStd = params.plot.thresholdStd;

    timeLimits = SPARQ.internal.plotTimeLimits(session, params);
    xStart = timeLimits(1);
    xEnd = timeLimits(2);

    hold(axesHandle, 'on');
    for i = 1:numel(layout.channels)
        upperLimit = (noise.channelMean(i) + kStd * noise.channelStd(i)) + layout.offsets(i);
        lowerLimit = (noise.channelMean(i) - kStd * noise.channelStd(i)) + layout.offsets(i);

        plot(axesHandle, [xStart xEnd], [upperLimit upperLimit], 'r--');
        plot(axesHandle, [xStart xEnd], [lowerLimit lowerLimit], 'r--');
    end
end
