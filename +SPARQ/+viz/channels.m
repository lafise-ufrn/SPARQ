function axesHandle = channels(session, params, axesHandle, varargin)
% axesHandle = SPARQ.viz.channels(session, params, axesHandle)
%
% Desenha a visão geral base do LFP multicanal empilhado: cada canal válido
% plotado com um deslocamento vertical, seu marcador de evento por canal 
% como uma linha branca tracejada e os rótulos de área no eixo y.
%
% Desenha nos eixos fornecidos e nunca cria uma figura nem força um número de
% figura por conta própria, permitindo que os callers controlem o layout
% (subplots, posicionamento de figuras, várias sessões lado a lado etc.).
% SPARQ.viz.withThresholds e SPARQ.viz.withNoiseWindows foram projetadas
% para ser sobrepostas aos eixos retornados por esta função.
%
% ENTRADAS:
%   session    = estrutura de SPARQ.loadSession
%   params     = estrutura de parâmetros (consulte defaultNoiseParameters)
%   axesHandle = (opcional) eixos onde desenhar. O padrão é gca, isto é, os
%                eixos atuais, criando primeiro uma figura se necessário.
%
% SAÍDAS:
%   axesHandle = os eixos onde o desenho foi feito (o mesmo handle fornecido,
%                se houver)
%
% OBSERVAÇÕES:
%   - Quando a sessão contém eventos, o eixo x é limitado à janela
%     [events(referenceEventStart), events(referenceEventEnd)], normalmente
%     usada para inspecionar a gravação antes de escolher a referência limpa.
%   - O titulo inclui o subjectId (consulte SPARQ.internal.sessionTitle),
%     nao apenas a condicao, pois as figuras sao recicladas durante uma
%     (SPARQ.internal.getOrCreateFigure).


    if nargin < 3 || isempty(axesHandle)
        axesHandle = gca;
    end

    parser = inputParser();
    parser.FunctionName = 'SPARQ.viz.channels';
    addParameter(parser, 'MaxDisplayPoints', Inf, ...
        @(x) isnumeric(x) && isreal(x) && isscalar(x) && ...
        ((isfinite(x) && x >= 100 && x == round(x)) || ...
         (isinf(x) && x > 0)));
    parse(parser, varargin{:});

    layout = SPARQ.internal.plotLayout(session, params);

    hold(axesHandle, 'on');
    for i = 1:numel(layout.channels)
        channel = layout.channels(i);
        trace = session.lfp(channel, :) + layout.offsets(i);
        [timeToPlot, traceToPlot] = SPARQ.internal.reduceTraceForDisplay( ...
            session.time, trace, parser.Results.MaxDisplayPoints);
        plot(axesHandle, timeToPlot, traceToPlot);

        if isfield(session, 'events') && numel(session.events) >= channel
            eventTime = session.events(channel);
            plot(axesHandle, [eventTime eventTime], ...
                [layout.yBottom layout.yTop], '--', ...
                'Color', params.plot.eventColor, 'LineWidth', 1);
        end
    end

    xlabel(axesHandle, 'Time (s)');
    ylabel(axesHandle, 'Channel');
    set(axesHandle, 'YTick', layout.yTicks, 'YTickLabel', cellstr(layout.areas));
    set(axesHandle, 'YDir', 'reverse');
    axis(axesHandle, 'tight');
    title(axesHandle, SPARQ.internal.sessionTitle(session, params));

    xlim(axesHandle, SPARQ.internal.plotTimeLimits(session, params));
    ylim(axesHandle, [layout.yBottom, layout.yTop]);
end
