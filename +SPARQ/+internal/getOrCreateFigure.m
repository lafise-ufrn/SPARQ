function fig = getOrCreateFigure(tag)
% fig = SPARQ.internal.getOrCreateFigure(tag)
%
% Retorna uma figura identificada por uma tag de string persistente: reutiliza
% uma figura existente com essa tag (limpando-a e colocando-a em foco) se uma
% já estiver aberta; caso contrário, cria uma nova e atribui a tag.
%
% SPARQ.runSession usa uma tag por função de gráfico. Assim, uma execução em
% lote mantém no máximo quatro figuras abertas, cada uma limpa e redesenhada
% para a sessão seguinte.
%
% ENTRADAS:
%   tag = char/string que identifica exclusivamente a FUNÇÃO do gráfico (por
%         exemplo, "SPARQ:overview"), não a sessão plotada. A mesma tag
%         usada em sessões diferentes reutiliza intencionalmente a mesma
%         janela; consulte SPARQ.internal.figureTags para o registro de
%         tags usado pela própria biblioteca.
%
% SAÍDAS:
%   fig = handle da figura, limpa e definida como figura atual
%
% OBSERVAÇÕES:
%   - Procurar por 'Tag', em vez de usar um número fixo, evita colisões com
%     figuras que o usuário ou outro código já tenham aberto.

    fig = findobj('Type', 'figure', 'Tag', tag);
    if isempty(fig)
        fig = figure('Tag', tag);
    else
        fig = fig(1);
        clf(fig);
        figure(fig);
    end
end

