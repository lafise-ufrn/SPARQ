classdef test_genericVisualization < matlab.unittest.TestCase
% test_genericVisualization  Contrato visual das quatro figuras genericas.

    methods (Test)

        function canonicalSessionUsesLegacyFourFigureModel(testCase)
            tags = SPARQ.internal.figureTags();
            closeTaggedFigures(tags);
            cleanupObject = onCleanup(@() closeTaggedFigures(tags));
            previousVisibility = get(groot, 'DefaultFigureVisible');
            visibilityCleanup = onCleanup(@() set( ...
                groot, 'DefaultFigureVisible', previousVisibility));
            set(groot, 'DefaultFigureVisible', 'off');

            time = 545.008 + (0:999) / 1000;
            lfp = [sin(2*pi*8*(0:999)/1000); ...
                cos(2*pi*10*(0:999)/1000); ...
                sin(2*pi*12*(0:999)/1000)];
            session = SPARQ.createSession(lfp, 1000, ...
                'Time', time, 'ChannelLabels', ["DG"; "CA3"; "CA1"], ...
                'SessionId', "RUN-1", 'Condition', "speed-30");
            params = SPARQ.processingOptions(3);
            params.plot.enabled = true;
            params.plot.channelSpacing = 4;
            cacheFile = [tempname '.mat'];
            cacheCleanup = onCleanup(@() deleteIfPresent(cacheFile));
            writeReferenceCacheFixture(cacheFile, "", 1000, ...
                session.time([1 end]), session.time([10 50]));

            SPARQ.reference.selectInteractive(session, ...
                'ShowOverview', true, 'MaxDisplayPoints', 500, ...
                'CacheFile', cacheFile);
            overviewFigure = findall(groot, ...
                'Type', 'figure', 'Tag', tags.overview);
            overviewAxes = findobj(overviewFigure, 'Type', 'axes');

            noise.windows = [200 240];
            noise.channelMean = [0; 0; 0];
            noise.channelStd = [0.25; 0.25; 0.25];
            noise.percentSaved = 95.9;
            noise.percentNoise = 4.1;
            result.noise = noise;
            SPARQ.internal.plotProcessingResult( ...
                session, result, params, 500);

            testCase.verifyEqual(numel(findall(groot, ...
                'Type', 'figure', 'Tag', tags.overview)), 1);
            testCase.verifyEqual(numel(findall(groot, ...
                'Type', 'figure', 'Tag', tags.thresholds)), 1);
            testCase.verifyEqual(numel(findall(groot, ...
                'Type', 'figure', 'Tag', tags.noiseWindows)), 1);
            testCase.verifyEqual(numel(findall(groot, ...
                'Type', 'figure', 'Tag', tags.summary)), 1);

            overviewLines = findobj(overviewAxes, 'Type', 'line');
            testCase.verifyEqual(numel(overviewLines), 3);
            colors = vertcat(overviewLines.Color);
            testCase.verifyGreaterThan(size(unique(colors, 'rows'), 1), 1);
            referenceMarkers = findobj( ...
                overviewAxes, 'Type', 'ConstantLine');
            testCase.verifyEqual(numel(referenceMarkers), 2);
            testCase.verifyTrue(all(strcmp( ...
                {referenceMarkers.LineStyle}, '--')));
            markerColors = vertcat(referenceMarkers.Color);
            testCase.verifyEqual(markerColors, ones(2, 1) * [1 0 0]);
            testCase.verifyEqual(xlim(overviewAxes), ...
                [session.time(1), session.time(end)], 'AbsTol', 1e-12);

            thresholdFigure = findall(groot, ...
                'Type', 'figure', 'Tag', tags.thresholds);
            thresholdAxes = findobj(thresholdFigure, 'Type', 'axes');
            thresholdLines = findobj(thresholdAxes, ...
                'Type', 'line', 'LineStyle', '--');
            testCase.verifyEqual(numel(thresholdLines), 6);

            noiseFigure = findall(groot, ...
                'Type', 'figure', 'Tag', tags.noiseWindows);
            testCase.verifyEqual(numel(findobj( ...
                noiseFigure, 'Type', 'patch')), 1);
            redLines = findobj(noiseFigure, 'Type', 'line', ...
                'Color', [1 0 0]);
            testCase.verifyGreaterThanOrEqual(numel(redLines), 3);

            summaryFigure = findall(groot, ...
                'Type', 'figure', 'Tag', tags.summary);
            bars = findobj(summaryFigure, 'Type', 'bar');
            testCase.verifyEqual(numel(bars), 1);
            testCase.verifyEqual(bars.YData, [95.9 4.1], 'AbsTol', 1e-12);
        end

    end
end

% ------------------------------------------------------------------------
function deleteIfPresent(filePath)
    if exist(filePath, 'file') == 2
        delete(filePath);
    end
end

% ------------------------------------------------------------------------
function closeTaggedFigures(tags)
    names = fieldnames(tags);
    for i = 1:numel(names)
        figures = findall(groot, 'Type', 'figure', 'Tag', tags.(names{i}));
        if ~isempty(figures)
            close(figures);
        end
    end
end
