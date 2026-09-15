function tags = figureTags()
% tags = SPARQ.internal.figureTags()
%
% Registro central das tags de figura usadas para reciclar janelas de gráficos
% entre chamadas a SPARQ.runSession (consulte
% SPARQ.internal.getOrCreateFigure). Manter as strings das tags em um único
% lugar evita que strings literais fiquem dessincronizadas.
%
% SAIDAS:
%   tags = estrutura com uma string unica por funcao de grafico para que a
%          mesma janela seja reutilizada entre sessoes.

    tags.overview     = 'SPARQ:overview';
    tags.thresholds   = 'SPARQ:thresholds';
    tags.noiseWindows = 'SPARQ:noiseWindows';
    tags.summary      = 'SPARQ:summary';
    tags.concat       = 'SPARQ:concat';
    tags.nan          = 'SPARQ:nan';
end
