function results = benchmark_detector(sampleCounts)
% results = benchmark_detector(sampleCounts)
%
% Mede o tempo do nucleo numerico em gravacoes sinteticas de
% diferentes comprimentos. O benchmark nao e um teste de aceitacao e nao
% define metas universais; serve para detectar regressoes grandes antes de uma
% release e para planejar memoria em dados longos.
%
% ENTRADAS:
%   sampleCounts = (opcional) vetor de comprimentos; padrao [1e4 1e5]
%
% SAIDAS:
%   results = tabela com Samples, Channels, InputMiB, Seconds e
%             MegaSamplesPerSecond

    if nargin < 1 || isempty(sampleCounts)
        sampleCounts = [1e4 1e5];
    end
    if ~isnumeric(sampleCounts) || ~isvector(sampleCounts) || ...
            any(~isfinite(sampleCounts)) || any(sampleCounts < 1000) || ...
            any(sampleCounts ~= round(sampleCounts))
        error('SPARQ:benchmark:badSampleCounts', ...
            'sampleCounts must contain integer values of at least 1000.');
    end

    libraryRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(libraryRoot);
    nChannels = 16;
    results = table('Size', [numel(sampleCounts), 5], ...
        'VariableTypes', {'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Samples', 'Channels', 'InputMiB', 'Seconds', ...
        'MegaSamplesPerSecond'});

    for i = 1:numel(sampleCounts)
        nSamples = sampleCounts(i);
        rng(42);
        lfp = randn(nChannels, nSamples);
        artifactStart = max(501, floor(0.6 * nSamples));
        artifactEnd = min(nSamples - 100, artifactStart + 100);
        lfp([1:11 13:16], artifactStart:artifactEnd) = ...
            lfp([1:11 13:16], artifactStart:artifactEnd) + 20;
        time = (0:nSamples - 1) / 1000;
        referenceIdx = 1:min(500, floor(nSamples / 4));
        params = SPARQ.profiles.esteiraOdor();

        elapsed = timeit(@() SPARQ.internal.detectNoiseWindows( ...
            time, lfp, referenceIdx, params));
        variableInfo = whos('lfp', 'time');
        inputMiB = sum([variableInfo.bytes]) / 1024^2;

        results.Samples(i) = nSamples;
        results.Channels(i) = nChannels;
        results.InputMiB(i) = inputMiB;
        results.Seconds(i) = elapsed;
        results.MegaSamplesPerSecond(i) = (nSamples / 1e6) / elapsed;
    end

    disp(results);
end
