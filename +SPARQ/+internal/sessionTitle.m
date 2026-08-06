function titleText = sessionTitle(session, params)
% titleText = SPARQ.internal.sessionTitle(session, params)
%
% Constrói o título legível usado em todos os gráficos de uma sessão,
% combinando a identidade do sujeito com o nome de exibição da condição (por
% exemplo, "rato4 - Aversive Odor"). Centralizado aqui, garante que todo
% mostra A QUAL SUJEITO uma figura pertence, e nao apenas a condicao; isso e necessario
% quando as figuras sao recicladas durante uma execucao em lote (consulte
% SPARQ.internal.getOrCreateFigure).
%
% ENTRADAS:
%   session = estrutura canonica (le .subjectId; aceita .ratId como alias)
%   params  = estrutura de parâmetros (consulte defaultNoiseParameters);
%             repassada a SPARQ.internal.conditionDisplayName
%
% SAÍDAS:
%   titleText = char, "<subjectId> - <nome de exibicao da condicao>"

    displayName = string( ...
        SPARQ.internal.conditionDisplayName(session, params));
    identity = "";
    if isfield(session, 'subjectId') && ...
            strlength(string(session.subjectId)) > 0
        identity = string(session.subjectId);
    elseif isfield(session, 'ratId') && strlength(string(session.ratId)) > 0
        identity = string(session.ratId);
    elseif isfield(session, 'sessionId') && ...
            strlength(string(session.sessionId)) > 0 && ...
            string(session.sessionId) ~= displayName
        identity = string(session.sessionId);
    end
    if strlength(identity) > 0
        titleText = char(identity + " - " + displayName);
    else
        titleText = char(displayName);
    end
end

