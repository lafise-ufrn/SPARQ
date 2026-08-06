function points = collectAxesClicks(axesHandle, numPoints)
% points = SPARQ.internal.collectAxesClicks(axesHandle, numPoints)
%
% Mantem bloqueado ate que o usuario clique NUMPOINTS vezes diretamente em AXESHANDLE,
% retornando as coordenadas x clicadas (unidades de dados) na ordem dos cliques.
%
% ENTRADAS:
%   axesHandle = eixos a observar; somente cliques NESTES eixos contam
%   numPoints  = quantidade de cliques a coletar
%
% SAIDAS:
%   points = vetor numPoints x 1 de coordenadas x (unidades de dados), na
%            ordem em que foram clicadas
%

    figureHandle = ancestor(axesHandle, 'figure');

    points = zeros(numPoints, 1);
    collected = 0;

    previousCallback = get(figureHandle, 'WindowButtonDownFcn');
    cleanupObj = onCleanup(@() restoreCallback(figureHandle, previousCallback));

    set(figureHandle, 'WindowButtonDownFcn', @onClick);

    while collected < numPoints
        if ~isvalid(figureHandle)
            error('SPARQ:collectAxesClicks:figureClosed', ...
                'The reference-selection figure was closed before %d point(s) were clicked.', ...
                numPoints);
        end
        drawnow limitrate;
        pause(0.02);
    end

    function onClick(src, ~)
        if get(src, 'CurrentAxes') ~= axesHandle
            return;  % clique caiu em outros eixos desta figura; ignora
        end
        currentPoint = get(axesHandle, 'CurrentPoint');
        collected = collected + 1;
        points(collected) = currentPoint(1, 1);
        SPARQ.internal.drawReferenceMarker( ...
            axesHandle, points(collected));
        drawnow;
    end
end

function restoreCallback(figureHandle, previousCallback)
    if isvalid(figureHandle)
        set(figureHandle, 'WindowButtonDownFcn', previousCallback);
    end
end
