function [time, lfp, params] = makeSyntheticRecording()
% [time, lfp, params] = makeSyntheticRecording()
%
% Constroi uma pequena gravacao de linha de base SILENCIOSA e totalmente
% deterministica, usada pelos testes unitarios desta pasta. Mantida separada
% do conjunto de dados real para que os testes nunca dependam da presenca de
% dados de laboratorio e sejam executados em milissegundos. Os testes injetam
% seus proprios artefatos sobre esta linha de base, mantendo cada teste
% autocontido quanto ao que verifica.
%
% Layout: 8 canais, canal 4 excluido (imita a exclusao do canal de respiracao
% da montagem real em escala muito menor), resultando em 7 canais validos:
% [1 2 3 5 6 7 8].
%
% SAIDAS:
%   time   = vetor 1x10000, 1 unidade por amostra (o algoritmo e
%            independente de unidade, portanto uma escala inteira arbitraria
%            serve para os testes)
%   lfp    = matriz 8x10000 de ruido gaussiano silencioso (desvio 1), sem artefatos
%   params = defaultNoiseParameters() com channels.count/excluded ajustados
%            para corresponder a esta montagem sintetica

    rng(42); % deterministico: gravacao sintetica identica em toda execucao

    nSamples = 10000;
    nChannels = 8;
    time = 1:nSamples;
    lfp = randn(nChannels, nSamples);

    params = defaultNoiseParameters();
    params.channels.count = nChannels;
    params.channels.excluded = 4;
end
