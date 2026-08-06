classdef test_esteiraOdorGolden < matlab.unittest.TestCase
% test_esteiraOdorGolden  Testes golden do perfil legado esteira/odor.
%
% Congela separadamente (1) os parametros historicos expostos pelo perfil e
% (2) os resultados numericos do pipeline em uma gravacao deterministica com
% fronteiras conhecidas. Os valores esperados sao declarados neste arquivo e
% nao calculados chamando uma segunda implementacao do detector.
%
% Estes testes nao autorizam mudancas em detectNoiseWindows ou
% buildCleanSignals. Uma alteracao deliberada de qualquer resultado exige a
% verificacao de equivalencia em dados reais descrita no README antes que os
% valores golden sejam atualizados.

    methods (Test)

        function profileContainsFrozenLegacyDefaults(testCase)
            testCase.verifyEqual( ...
                SPARQ.profiles.esteiraOdor(), frozenProfile());
        end

        function legacyEntryPointsUseTheFrozenProfile(testCase)
            expected = frozenProfile();

            testCase.verifyEqual(defaultNoiseParameters(), expected);
            testCase.verifyEqual(SPARQ.defaultOptions(), expected);
        end

        function deprecatedLegacyRatIdsIsStillAccepted(testCase)
            params = SPARQ.profiles.esteiraOdor();
            params.acquisition.legacyRatIds = ...
                params.acquisition.legacySubjectIds;
            params.acquisition = rmfield( ...
                params.acquisition, 'legacySubjectIds');

            testCase.verifyWarningFree( ...
                @() SPARQ.internal.validateParameters(params));
            [samplingRate, ~] = SPARQ.internal.resolveSamplingRate( ...
                "rato2", 0:2, params);
            testCase.verifyEqual(samplingRate, 1);
        end

        function deterministicRecordingMatchesGoldenOutputs(testCase)
            [session, params, expected] = goldenRecording();

            result = SPARQ.processSession(session, 1:100, params);

            testCase.verifyEqual(result.noise.windows, expected.windows);
            testCase.verifyEqual(result.noise.mask, expected.mask);
            testCase.verifyEqual(result.cleanSignals.noiseMask, expected.mask);
            testCase.verifyEqual(result.noise.percentNoise, expected.percentNoise, ...
                'AbsTol', 10 * eps(expected.percentNoise));
            testCase.verifyEqual(result.noise.percentSaved, expected.percentSaved, ...
                'AbsTol', 10 * eps(expected.percentSaved));
            testCase.verifyEqual(result.noise.channelMean, zeros(1, 15));
            testCase.verifyEqual(result.noise.channelStd, ...
                repmat(sqrt(100 / 99), 1, 15), 'AbsTol', 10 * eps);

            validChannels = [1:11, 13:16];
            testCase.verifyEqual(result.cleanSignals.channels, validChannels);
            testCase.verifyEqual(result.cleanSignals.concat, ...
                session.lfp(validChannels, ~expected.mask));
            testCase.verifyEqual(result.cleanSignals.timeConcat, ...
                session.time(~expected.mask));
            testCase.verifyEqual(result.cleanSignals.concatEdges, [248 405]);

            expectedNaN = session.lfp(validChannels, :);
            expectedNaN(:, expected.mask) = NaN;
            testCase.verifyEqual(result.cleanSignals.nan, expectedNaN);
        end

    end
end

% ------------------------------------------------------------------------
function params = frozenProfile()
    params.detection.thresholdStd            = 4;
    params.detection.minSimultaneousChannels = 7;
    params.detection.mergeGapSamples         = 100;
    params.detection.settleWindowSamples     = 50;
    params.detection.settleToleranceStd      = 2;

    params.channels.count               = 16;
    params.channels.excluded            = 12;
    params.channels.referenceEventStart = 11;
    params.channels.referenceEventEnd   = 16;

    params.acquisition.legacySubjectIds   = ["rato2", "rato3"];
    params.acquisition.legacySamplingRate = 1;
    params.acquisition.samplingRate       = 30000;

    params.conditions.names        = ["neutro", "aversivo"];
    params.conditions.displayNames = ["Neutral Odor", "Aversive Odor"];
    params.conditions.process      = [1 2];

    params.spectral.samplingRate = 1000;
    params.spectral.window       = 2000;
    params.spectral.noverlap     = 1000;
    params.spectral.nfft         = 2048;

    params.plot.enabled        = true;
    params.plot.channelSpacing = 1500;
    params.plot.thresholdStd   = 4;
    params.plot.eventColor     = [0.35 0.35 0.35];

    params.output.includeConcat = false;
    params.output.includeNaN    = false;

    params.io.cleanSuffix          = "_clean";
    params.io.saveFormat           = "-v7.3";
    params.io.cacheReferences      = true;
    params.io.referenceCacheName   = "clean_reference.mat";
    params.io.sessionFolderPattern = "rato*";
end

% ------------------------------------------------------------------------
function [session, params, expected] = goldenRecording()
    params = SPARQ.profiles.esteiraOdor();
    params.output.includeConcat = true;
    params.output.includeNaN = true;

    nSamples = 700;
    baseline = repmat([-1 1], 1, nSamples / 2);
    lfp = repmat(baseline, params.channels.count, 1);
    validChannels = [1:11, 13:16];

    lfp(validChannels, 250:260) = lfp(validChannels, 250:260) + 10;
    lfp(validChannels, 330:340) = lfp(validChannels, 330:340) + 10;
    lfp(validChannels, 500:510) = lfp(validChannels, 500:510) + 10;

    session.subjectId = "golden-subject";
    session.condition = "golden-condition";
    session.sourceFile = "golden-recording.mat";
    session.time = 1:nSamples;
    session.lfp = lfp;
    session.events = 1:params.channels.count;
    session.areas = compose("area%02d", (1:params.channels.count).');

    expected.windows = [249 341; 499 511];
    expected.mask = false(1, nSamples);
    expected.mask(249:341) = true;
    expected.mask(499:511) = true;
    expected.percentNoise = (106 / nSamples) * 100;
    expected.percentSaved = (594 / nSamples) * 100;
end
