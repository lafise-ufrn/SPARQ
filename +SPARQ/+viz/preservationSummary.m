function axesHandle = preservationSummary(noise, titleText, axesHandle)
% axesHandle = SPARQ.viz.preservationSummary(noise, titleText, axesHandle)
%
% Desenha em duas barras quanto da sessão foi mantido e quanto foi descartado
% como ruído. É um gráfico independente porque resume a sessão, em vez de
% representar cada amostra do sinal.
%
% ENTRADAS:
%   noise      = estrutura de SPARQ.internal.detectNoiseWindows (precisa
%                de .percentSaved, .percentNoise)
%   titleText  = char/string usada como prefixo do titulo (por exemplo,
%                "Aversive Odor")
%   axesHandle = (opcional) eixos onde desenhar. Quando omitido, uma nova
%                figura branca de 600 x 500 pixels é criada.
%
% SAIDAS:
%   axesHandle = os eixos onde o desenho foi feito

    if nargin < 3 || isempty(axesHandle)
        figureHandle = figure;
        set(figureHandle, 'Color', 'white', 'Position', [150 150 600 500]);
        axesHandle = axes(figureHandle);
    end

    barHandle = bar(axesHandle, [noise.percentSaved, noise.percentNoise], ...
        'FaceColor', 'flat');
    barHandle.CData(1, :) = [0.00 0.45 0.74];
    barHandle.CData(2, :) = [0.85 0.33 0.10];

    set(axesHandle, 'XTick', 1:2, 'XTickLabel', {'Saved Signal', 'Discarded (Noise)'}, ...
        'FontSize', 12, 'FontWeight', 'bold');
    ylabel(axesHandle, 'Percentage of Session (%)', 'FontSize', 12, 'FontWeight', 'bold');
    title(axesHandle, sprintf('%s - Signal Preservation', titleText), 'FontSize', 14);

    text(axesHandle, 1, noise.percentSaved + 3, sprintf('%.1f%%', noise.percentSaved), ...
        'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    text(axesHandle, 2, noise.percentNoise + 3, sprintf('%.1f%%', noise.percentNoise), ...
        'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');

    ylim(axesHandle, [0 110]);
    grid(axesHandle, 'on');
end

