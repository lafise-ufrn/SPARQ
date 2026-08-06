function axesHandle = withNoiseWindows(axesHandle, session, noise, params)
% axesHandle = SPARQ.viz.withNoiseWindows(axesHandle, session, noise, params)
%
% Sobrepõe, a um gráfico existente de SPARQ.viz.channels, os blocos de
% ruído detectados como linhas de limite vermelhas de altura total com um
% preenchimento vermelho translúcido e atualiza o título para indicar que as
% janelas de ruído estão visíveis.
%
% A detecção já ocorreu em SPARQ.internal.detectNoiseWindows; esta função
% apenas desenha seu resultado.
%
% ENTRADAS:
%   axesHandle = eixos retornados anteriormente por SPARQ.viz.channels
%   session    = estrutura de SPARQ.loadSession
%   noise      = estrutura de SPARQ.internal.detectNoiseWindows (precisa
%                de .windows, pares Kx2 de índices de amostra)
%   params     = estrutura de parâmetros (consulte defaultNoiseParameters)
%
% SAÍDAS:
%   axesHandle = os mesmos eixos, para encadeamento

    layout = SPARQ.internal.plotLayout(session, params);

    hold(axesHandle, 'on');
    for i = 1:size(noise.windows, 1)
        blockStart = session.time(noise.windows(i, 1));
        blockEnd   = session.time(noise.windows(i, 2));

        plot(axesHandle, [blockStart blockStart], [layout.yBottom layout.yTop], ...
            'r', 'LineWidth', 1);
        plot(axesHandle, [blockEnd blockEnd], [layout.yBottom layout.yTop], ...
            'r', 'LineWidth', 1);

        patch(axesHandle, ...
            [blockStart blockEnd blockEnd blockStart], ...
            [layout.yBottom layout.yBottom layout.yTop layout.yTop], ...
            'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end

    baseTitle = SPARQ.internal.sessionTitle(session, params);
    title(axesHandle, sprintf('%s - Max Single-Channel Noise Window', baseTitle));
end
