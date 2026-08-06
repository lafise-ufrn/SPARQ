function lineHandles = drawReferenceMarker(axesHandles, timePoint)
% lineHandles = SPARQ.internal.drawReferenceMarker(axesHandles, timePoint)
%
% Desenha uma linha vertical vermelha tracejada no instante selecionado em
% cada eixo fornecido. Esta funcao e exclusivamente visual: nao arredonda nem
% modifica o timestamp usado para construir a referencia do detector.
%
% ENTRADAS:
%   axesHandles = um ou mais handles de eixos validos
%   timePoint   = coordenada x real, finita e escalar
%
% SAIDA:
%   lineHandles = handles das linhas ConstantLine criadas

    if isempty(axesHandles) || any(~isgraphics(axesHandles, 'axes'))
        error('SPARQ:drawReferenceMarker:badAxes', ...
            'axesHandles must contain at least one valid axes handle.');
    end
    if ~isnumeric(timePoint) || ~isreal(timePoint) || ...
            ~isscalar(timePoint) || ~isfinite(timePoint)
        error('SPARQ:drawReferenceMarker:badTime', ...
            'timePoint must be a finite real numeric scalar.');
    end

    axesHandles = axesHandles(:);
    lineHandles = gobjects(numel(axesHandles), 1);
    for axisIndex = 1:numel(axesHandles)
        lineHandles(axisIndex) = xline( ...
            axesHandles(axisIndex), timePoint, '--r', 'LineWidth', 1);
    end
end
