% demo_genericSynthetic.m
%
% Demonstracao autocontida do fluxo visual completo. Nao le dados de
% laboratorio, nao usa convencoes de pastas e nao grava arquivos. O sinal
% sintetico combina oscilacoes, ruido de fundo e dois artefatos multicanal.
%
% A execucao reproduz a mesma sequencia visual do processamento completo:
%   1. selecao manual de uma referencia limpa;
%   2. sinal com os limiares calculados a partir da referencia;
%   3. janelas de ruido detectadas e trechos destacados;
%   4. resumo percentual de sinal preservado e descartado.
%
% Na primeira figura, clique no INICIO e depois no FIM de qualquer trecho
% sem os artefatos de grande amplitude.

libraryRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(libraryRoot);

rng(42);
samplingRateHz = 1000;
nChannels = 8;
nSamples = 6000;
timeSeconds = (0:nSamples - 1) / samplingRateHz;
lfp = zeros(nChannels, nSamples);

% Cada canal recebe atividade oscilatoria propria, deriva lenta e ruido
% gaussiano. As amplitudes estao na mesma ordem do espacamento vertical usado
% pelas figuras, de modo que a variacao do LFP permanece visivel.
for channel = 1:nChannels
    phase = 2 * pi * rand();
    lfp(channel, :) = ...
        260 * sin(2 * pi * (5 + 0.35 * channel) * timeSeconds + phase) + ...
        110 * sin(2 * pi * (35 + channel) * timeSeconds + phase / 2) + ...
         80 * sin(2 * pi * 0.4 * timeSeconds + channel / 3) + ...
         55 * randn(1, nSamples);
end

% Dois artefatos sincronizados, conhecidos e visualmente evidentes. Eles
% atravessam canais suficientes para exercitar a mesma deteccao cross-channel
% usada no processamento de dados reais.
firstArtifact = timeSeconds >= 3.20 & timeSeconds <= 3.35;
firstEnvelope = sin(linspace(0, pi, nnz(firstArtifact))).^2;
lfp(:, firstArtifact) = lfp(:, firstArtifact) + 2600 * firstEnvelope;

secondArtifact = timeSeconds >= 4.65 & timeSeconds <= 4.90;
secondEnvelope = sin(linspace(0, pi, nnz(secondArtifact))).^2;
lfp(:, secondArtifact) = lfp(:, secondArtifact) - 2200 * secondEnvelope;
channelLabels = compose("channel-%02d", (1:nChannels).');

session = SPARQ.createSession(lfp, samplingRateHz, ...
    'SubjectId', "synthetic-subject", ...
    'SessionId', "synthetic-session", ...
    'ChannelLabels', channelLabels, ...
    'SignalUnits', "uV");

params = SPARQ.processingOptions(nChannels);
params.detection.minSimultaneousChannels = 4;
params.output.includeNaN = true;
params.plot.enabled = true;

[referenceIdx, referenceInfo] = SPARQ.reference.selectInteractive( ...
    session, 'ShowOverview', true);
result = SPARQ.processSession(session, referenceIdx, params);
result.referenceInfo = referenceInfo;

% Gera as outras tres figuras do fluxo visual, usando exatamente o mesmo
% orquestrador empregado pelo processamento generico completo.
SPARQ.internal.plotProcessingResult(session, result, params);

fprintf('%d janela(s) de ruido detectada(s); %.2f%% do sinal marcado como ruido.\n', ...
    size(result.noise.windows, 1), result.noise.percentNoise);
disp(result.noise.windows);
