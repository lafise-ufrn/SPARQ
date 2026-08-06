function layout = plotLayout(session, params)
% layout = SPARQ.internal.plotLayout(session, params)
%
% Calcula a geometria compartilhada de empilhamento vertical usada por todo
% gráfico multicanal: deslocamentos por canal, limites do eixo y e rótulos das
% marcações. A geometria centralizada mantém o gráfico base e suas
% sobreposições consistentes quando a montagem ou a ordem dos canais muda.
%
% ENTRADAS:
%   session = estrutura de SPARQ.loadSession (somente .areas é lido)
%   params  = estrutura de parâmetros (consulte defaultNoiseParameters).
%             Campos lidos:
%       .channels.count / .channels.excluded = definição da montagem
%       .plot.channelSpacing                 = espaçamento vertical entre
%                                               canais empilhados (k_plot)
%
% SAÍDAS:
%   layout = estrutura com os campos:
%       .channels = índices de canais válidos 1xM (consulte validChannels)
%       .areas    = rótulos de área Mx1 desses canais
%       .offsets  = deslocamento vertical 1xM aplicado ao traço de cada canal
%       .yBottom  = limite inferior do eixo y (margem abaixo do canal 1)
%       .yTop     = limite superior do eixo y (margem acima do último canal)
%       .yTicks   = posições das marcações 1xM, iguais a .offsets

    channels = SPARQ.internal.validChannels(params);
    nChannels = numel(channels);
    spacing = params.plot.channelSpacing;

    layout.channels = channels;
    layout.areas    = session.areas(channels);
    layout.offsets  = (0:nChannels - 1) * spacing;
    layout.yBottom  = -spacing;
    layout.yTop     = layout.offsets(end) + spacing;
    layout.yTicks   = layout.offsets;
end
