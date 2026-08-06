function displayName = conditionDisplayName(session, params)
% displayName = SPARQ.internal.conditionDisplayName(session, params)
%
% Resolve o rotulo legivel da condicao de uma sessao (por exemplo, "neutro"
% -> "Neutral Odor"), usado nos titulos dos graficos. Centraliza o mapeamento
% em um unico lugar (params.conditions.displayNames), em vez de deixar uma
% string literal embutida em cada funcao de plotagem.
%
% ENTRADAS:
%   session = estrutura de SPARQ.loadSession (le .conditionIndex)
%   params  = estrutura de parametros (consulte defaultNoiseParameters)
%
% SAIDAS:
%   displayName = string, params.conditions.displayNames(session.conditionIndex)

    if isfield(session, 'conditionIndex') && ...
            isnumeric(session.conditionIndex) && isscalar(session.conditionIndex) && ...
            session.conditionIndex >= 1 && ...
            session.conditionIndex <= numel(params.conditions.displayNames)
        displayName = string( ...
            params.conditions.displayNames(session.conditionIndex));
    elseif isfield(session, 'condition') && ...
            strlength(string(session.condition)) > 0
        displayName = string(session.condition);
    elseif isfield(session, 'sessionId') && ...
            strlength(string(session.sessionId)) > 0
        displayName = string(session.sessionId);
    else
        displayName = "Session";
    end
end
