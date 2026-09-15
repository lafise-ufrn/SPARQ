classdef test_detectorEquivalence < matlab.unittest.TestCase
% Frozen differential and performance tests for detectNoiseWindows.

    methods (Test)

        function matchesFrozenOracleForDoubleAndSingleInputs(testCase)
            cases = makeEquivalenceCases();
            for i = 1:numel(cases)
                expected = frozenDetector(cases(i).time, cases(i).lfp, ...
                    cases(i).referenceIdx, cases(i).params);
                actual = SPARQ.internal.detectNoiseWindows( ...
                    cases(i).time, cases(i).lfp, cases(i).referenceIdx, ...
                    cases(i).params);

                testCase.verifyTrue(isequaln(actual.windows, expected.windows), ...
                    sprintf('windows differ in case %d', i));
                testCase.verifyTrue(isequaln(actual.mask, expected.mask), ...
                    sprintf('mask differs in case %d', i));
                testCase.verifyTrue(isequaln(actual.channelMean, expected.channelMean), ...
                    sprintf('channelMean differs in case %d', i));
                testCase.verifyTrue(isequaln(actual.channelStd, expected.channelStd), ...
                    sprintf('channelStd differs in case %d', i));
                testCase.verifyTrue(isequaln(actual.percentNoise, expected.percentNoise), ...
                    sprintf('percentNoise differs in case %d', i));
                testCase.verifyTrue(isequaln(actual.percentSaved, expected.percentSaved), ...
                    sprintf('percentSaved differs in case %d', i));
            end
        end

        function meetsStressPerformanceBudget(testCase)
            % Three long blocks force the old overlapping max scans to repeat
            % large windows. The budget is intentionally above the optimized
            % path and below the measured original implementation.
            nSamples = 600000;
            lfp = zeros(8, nSamples);
            lfp(:, 60001:120000) = 20;
            lfp(:, 240001:300000) = 20;
            lfp(:, 420001:480000) = 20;
            time = 1:nSamples;
            referenceIdx = 1:1000;

            params = SPARQ.profiles.esteiraOdor();
            params.channels.count = 8;
            params.channels.excluded = [];
            params.detection.minSimultaneousChannels = 8;
            params.detection.settleWindowSamples = 50000;

            elapsed = timeit(@() SPARQ.internal.detectNoiseWindows( ...
                time, lfp, referenceIdx, params));
            testCase.verifyLessThan(elapsed, 0.03, ...
                'Stress workload exceeds the detector performance budget.');
        end
    end
end

% -------------------------------------------------------------------------
function cases = makeEquivalenceCases()
    cases = struct('time', {}, 'lfp', {}, 'referenceIdx', {}, 'params', {});

    rng(7);
    cases(1).time = (0:239) / 1000;
    cases(1).lfp = randn(6, 240);
    cases(1).referenceIdx = 1:30;
    cases(1).params = SPARQ.profiles.esteiraOdor();
    cases(1).params.channels.count = 6;
    cases(1).params.channels.excluded = [2 5];
    cases(1).params.detection.thresholdStd = 3;
    cases(1).params.detection.minSimultaneousChannels = 2;
    cases(1).params.detection.mergeGapSamples = 3;
    cases(1).params.detection.settleWindowSamples = 4;
    cases(1).params.detection.settleToleranceStd = 1.5;
    valid = SPARQ.internal.validChannels(cases(1).params);
    cases(1).lfp(valid, 70:75) = cases(1).lfp(valid, 70:75) + 20;
    cases(1).lfp(valid, 77:83) = cases(1).lfp(valid, 77:83) + 20;
    cases(1).lfp(valid(1), 150:160) = cases(1).lfp(valid(1), 150:160) + 20;

    rng(11);
    cases(2).time = single(1:180);
    cases(2).lfp = single(randn(5, 180));
    cases(2).referenceIdx = 1:25;
    cases(2).params = SPARQ.profiles.esteiraOdor();
    cases(2).params.channels.count = 5;
    cases(2).params.channels.excluded = 3;
    cases(2).params.detection.thresholdStd = 2.5;
    cases(2).params.detection.minSimultaneousChannels = 2;
    cases(2).params.detection.mergeGapSamples = 2;
    cases(2).params.detection.settleWindowSamples = 5;
    cases(2).params.detection.settleToleranceStd = 1.25;
    valid = SPARQ.internal.validChannels(cases(2).params);
    cases(2).lfp(valid, 1:8) = cases(2).lfp(valid, 1:8) + 15;
    cases(2).lfp(valid, 90:95) = cases(2).lfp(valid, 90:95) + 15;
    cases(2).lfp(valid, 174:180) = cases(2).lfp(valid, 174:180) + 15;
    cases(2).lfp(1, 50) = NaN;
    cases(2).lfp(2, 120) = NaN;
    cases(2).lfp(3, 100) = NaN; % excluded channel must not affect detection

    cases(3).time = 1:80;
    cases(3).lfp = zeros(4, 80);
    cases(3).lfp(1, 1:20) = -1:0.1:0.9;
    cases(3).lfp(2, 1:20) = 1:0.1:2.9;
    cases(3).referenceIdx = 1:20;
    cases(3).params = SPARQ.profiles.esteiraOdor();
    cases(3).params.channels.count = 4;
    cases(3).params.channels.excluded = 4;
    cases(3).params.detection.thresholdStd = 1;
    cases(3).params.detection.minSimultaneousChannels = 2;
    cases(3).params.detection.mergeGapSamples = 1;
    cases(3).params.detection.settleWindowSamples = 6;
    cases(3).params.detection.settleToleranceStd = 1;
    valid = SPARQ.internal.validChannels(cases(3).params);
    cases(3).lfp(valid, 30:35) = cases(3).lfp(valid, 30:35) + 100;
    cases(3).lfp(valid, 78:80) = cases(3).lfp(valid, 78:80) - 100;
    cases(3).lfp(4, :) = NaN; % excluded NaNs are irrelevant
end

% This is deliberately a self-contained copy of the pre-optimization
% algorithm. It is the behavior oracle and must not call production code.
function noise = frozenDetector(time, lfp, referenceIdx, params)
    validCh = SPARQ.internal.validChannels(params);
    nValid = numel(validCh);
    nSamples = numel(time);

    kStd = params.detection.thresholdStd;
    minChannels = params.detection.minSimultaneousChannels;
    mergeGap = params.detection.mergeGapSamples;
    settleWindow = params.detection.settleWindowSamples;
    settleTolStd = params.detection.settleToleranceStd;

    channelMean = zeros(1, nValid);
    channelStd = zeros(1, nValid);
    for ch = 1:nValid
        channel = validCh(ch);
        channelMean(ch) = mean(lfp(channel, referenceIdx));
        channelStd(ch) = std(lfp(channel, referenceIdx));
    end

    validLfp = lfp(validCh, :);
    exceedsBaseline = abs(validLfp - channelMean') > kStd * channelStd';
    candidateSamples = find(sum(exceedsBaseline) >= minChannels);

    isNoise = false(1, nSamples);
    if ~isempty(candidateSamples)
        segmentBreaks = find(diff(candidateSamples) > mergeGap);
        blockStarts = candidateSamples([1, segmentBreaks + 1]);
        blockEnds = candidateSamples([segmentBreaks, end]);

        for b = 1:numel(blockStarts)
            expandedLeft = blockStarts(b);
            expandedRight = blockEnds(b);
            for ch = 1:nValid
                channel = validCh(ch);
                baseline = channelMean(ch);
                settleTol = settleTolStd * channelStd(ch);

                idxLeft = blockStarts(b);
                while idxLeft > 1
                    searchStart = max(1, idxLeft - settleWindow);
                    windowPeak = max(abs(lfp(channel, searchStart:idxLeft) - baseline));
                    if windowPeak <= settleTol
                        break
                    end
                    idxLeft = idxLeft - 1;
                end

                idxRight = blockEnds(b);
                while idxRight < nSamples
                    searchEnd = min(nSamples, idxRight + settleWindow);
                    windowPeak = max(abs(lfp(channel, idxRight:searchEnd) - baseline));
                    if windowPeak <= settleTol
                        break
                    end
                    idxRight = idxRight + 1;
                end

                if idxLeft < expandedLeft
                    expandedLeft = idxLeft;
                end
                if idxRight > expandedRight
                    expandedRight = idxRight;
                end
            end
            isNoise(expandedLeft:expandedRight) = true;
        end
    end

    maskEdges = diff([0, isNoise, 0]);
    windowStarts = find(maskEdges == 1);
    windowEnds = find(maskEdges == -1) - 1;
    windows = [windowStarts(:), windowEnds(:)];
    noiseSamples = sum(isNoise);
    savedSamples = nSamples - noiseSamples;

    noise.windows = windows;
    noise.mask = isNoise;
    noise.percentNoise = (noiseSamples / nSamples) * 100;
    noise.percentSaved = (savedSamples / nSamples) * 100;
    noise.channelMean = channelMean;
    noise.channelStd = channelStd;
end
