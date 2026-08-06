function channels = validChannels(params)
% channels = SPARQ.internal.validChannels(params)
%
% Retorna a lista de canais LFP que participam da análise, isto é, todos os
% canais adquiridos, exceto aqueles marcados para exclusão.
%
%
% ENTRADAS:
%   params = estrutura de parâmetros (consulte defaultNoiseParameters).
%            Somente a subestrutura `channels` é lida:
%       .channels.count    = total de canais adquiridos (por exemplo, 16)
%       .channels.excluded = índices de canais a remover (por exemplo, 12)
%
% SAÍDAS:
%   channels = vetor linha 1xM de índices de canais a analisar, em ordem
%              crescente. ex: Com os padrões (count=16, excluded=12), retorna
%              [1:11, 13:16].
%
% NOTAS:
%   - `excluded` pode ser um escalar ou um vetor de índices de canais.
%   - A ordem de `channels` define a ordem das linhas de toda saída por canal
%     (vetores de média/desvio-padrão, matrizes de sinais limpos); mantenha-a
%     estável.

    channels = setdiff(1:params.channels.count, params.channels.excluded);
    channels = channels(:).';   % garante um vetor linha
end
