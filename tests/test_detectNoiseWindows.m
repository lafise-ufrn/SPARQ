classdef test_detectNoiseWindows < matlab.unittest.TestCase
% test_detectNoiseWindows  Testes unitarios de SPARQ.internal.detectNoiseWindows.
%
% Usa uma pequena gravacao sintetica (consulte makeSyntheticRecording) em vez
% de dados reais de laboratorio, portanto os testes sao rapidos,
% deterministas e executaveis em qualquer maquina sem os arquivos .mat originais.

    methods (Test)

        function quietRecordingProducesNoNoiseWindows(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1:2000;

            noise = SPARQ.internal.detectNoiseWindows(time, lfp, referenceIdx, params);

            testCase.verifyEmpty(noise.windows);
            testCase.verifyEqual(noise.percentNoise, 0);
            testCase.verifyEqual(noise.percentSaved, 100);
        end

        function artefactOnAllValidChannelsIsDetected(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1:2000;

            validChannels = SPARQ.internal.validChannels(params); % [1 2 3 5 6 7 8]
            artefactRange = 4001:4200;
            lfp(validChannels, artefactRange) = lfp(validChannels, artefactRange) + 20;

            noise = SPARQ.internal.detectNoiseWindows(time, lfp, referenceIdx, params);

            testCase.verifyNotEmpty(noise.windows);
            % O bloco detectado deve conter completamente o artefato injetado
            % (pode ser mais largo, pois as bordas crescem ate o sinal se estabilizar).
            testCase.verifyLessThanOrEqual(noise.windows(1, 1), artefactRange(1));
            testCase.verifyGreaterThanOrEqual(noise.windows(1, 2), artefactRange(end));
        end

        function artefactBelowMinSimultaneousChannelsIsIgnored(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1:2000;

            % Somente 2 dos 7 canais validos se desviam: o
            % minSimultaneousChannels padrao (7) exige todos eles.
            lfp([1 2], 4001:4200) = lfp([1 2], 4001:4200) + 20;

            noise = SPARQ.internal.detectNoiseWindows(time, lfp, referenceIdx, params);

            testCase.verifyEmpty(noise.windows);
        end

        function outputChannelStatsMatchDirectComputation(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1:2000;

            noise = SPARQ.internal.detectNoiseWindows(time, lfp, referenceIdx, params);

            validChannels = SPARQ.internal.validChannels(params);
            expectedMean = mean(lfp(validChannels(1), referenceIdx));
            expectedStd  = std(lfp(validChannels(1), referenceIdx));

            testCase.verifyEqual(noise.channelMean(1), expectedMean, 'AbsTol', 1e-10);
            testCase.verifyEqual(noise.channelStd(1), expectedStd, 'AbsTol', 1e-10);
        end

        function artefactAtRecordingStartClampsToFirstSample(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1000:2000;
            validChannels = SPARQ.internal.validChannels(params);
            lfp(validChannels, 1:20) = lfp(validChannels, 1:20) + 20;

            noise = SPARQ.internal.detectNoiseWindows( ...
                time, lfp, referenceIdx, params);

            testCase.verifyEqual(noise.windows(1, 1), 1);
            testCase.verifyGreaterThanOrEqual(noise.windows(1, 2), 20);
        end

        function artefactAtRecordingEndClampsToLastSample(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            referenceIdx = 1000:2000;
            validChannels = SPARQ.internal.validChannels(params);
            finalRange = numel(time) - 19:numel(time);
            lfp(validChannels, finalRange) = lfp(validChannels, finalRange) + 20;

            noise = SPARQ.internal.detectNoiseWindows( ...
                time, lfp, referenceIdx, params);

            testCase.verifyEqual(noise.windows(end, 2), numel(time));
            testCase.verifyLessThanOrEqual(noise.windows(end, 1), finalRange(1));
        end

    end
end
