classdef test_buildCleanSignals < matlab.unittest.TestCase
% test_buildCleanSignals  Testes unitarios de SPARQ.internal.buildCleanSignals.
%
% Verifica a mascara logica obrigatoria de ruido e as duas representacoes
% opcionais de sinal (.concat e .nan) contra as janelas de ruido de entrada,
% usando uma pequena gravacao sintetica (consulte makeSyntheticRecording).

    methods (Test)

        function defaultOutputIsOnlyTheFullLengthNoiseMask(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            areas = repmat("area", params.channels.count, 1);
            noiseWindows = [100 200; 500 550];

            clean = SPARQ.internal.buildCleanSignals( ...
                time, lfp, noiseWindows, areas, params);

            fields = fieldnames(clean);
            testCase.verifyEqual(fields{1}, 'noiseMask');
            testCase.verifyClass(clean.noiseMask, 'logical');
            testCase.verifySize(clean.noiseMask, size(time));
            testCase.verifyTrue(all(clean.noiseMask(100:200)));
            testCase.verifyTrue(all(clean.noiseMask(500:550)));
            testCase.verifyFalse(any(clean.noiseMask(1:99)));
            testCase.verifyFalse(any(clean.noiseMask(201:499)));
            testCase.verifyFalse(isfield(clean, 'concat'));
            testCase.verifyFalse(isfield(clean, 'nan'));
        end

        function optionalSignalFieldsFollowTheRequiredOrder(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            params.output.includeConcat = true;
            params.output.includeNaN = true;
            areas = repmat("area", params.channels.count, 1);

            clean = SPARQ.internal.buildCleanSignals( ...
                time, lfp, [100 200], areas, params);

            fields = fieldnames(clean);
            testCase.verifyEqual(fields(1:3), {'noiseMask'; 'concat'; 'nan'});
        end

        function nanVersionMasksExactlyTheNoiseWindows(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            params.output.includeNaN = true;
            areas = repmat("area", params.channels.count, 1);
            noiseWindows = [100 200; 500 550];

            clean = SPARQ.internal.buildCleanSignals(time, lfp, noiseWindows, areas, params);

            testCase.verifyTrue(all(isnan(clean.nan(:, 100:200)), 'all'));
            testCase.verifyTrue(all(isnan(clean.nan(:, 500:550)), 'all'));
            testCase.verifyFalse(any(isnan(clean.nan(:, 1:99)), 'all'));
            testCase.verifyFalse(any(isnan(clean.nan(:, 201:499)), 'all'));
        end

        function concatVersionLengthMatchesKeptSamples(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            params.output.includeConcat = true;
            areas = repmat("area", params.channels.count, 1);
            noiseWindows = [100 200; 500 550];

            clean = SPARQ.internal.buildCleanSignals(time, lfp, noiseWindows, areas, params);

            nRemoved = (200 - 100 + 1) + (550 - 500 + 1);
            expectedLength = numel(time) - nRemoved;

            testCase.verifySize(clean.concat, [numel(clean.channels), expectedLength]);
            testCase.verifySize(clean.timeConcat, [1, expectedLength]);
        end

        function concatEdgesMarkEverySeam(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            params.output.includeConcat = true;
            areas = repmat("area", params.channels.count, 1);
            noiseWindows = [100 200; 500 550];

            clean = SPARQ.internal.buildCleanSignals(time, lfp, noiseWindows, areas, params);

            % Dois blocos de ruido foram removidos -> duas emendas na serie concatenada.
            testCase.verifyNumElements(clean.concatEdges, 2);
        end

        function noNoiseWindowsLeavesSignalUntouched(testCase)
            [time, lfp, params] = makeSyntheticRecording();
            params.output.includeConcat = true;
            params.output.includeNaN = true;
            areas = repmat("area", params.channels.count, 1);
            noiseWindows = zeros(0, 2);

            clean = SPARQ.internal.buildCleanSignals(time, lfp, noiseWindows, areas, params);

            validChannels = SPARQ.internal.validChannels(params);
            testCase.verifyFalse(any(clean.noiseMask));
            testCase.verifyEqual(clean.concat, lfp(validChannels, :));
            testCase.verifyFalse(any(isnan(clean.nan), 'all'));
            testCase.verifyEmpty(clean.concatEdges);
        end

    end
end
