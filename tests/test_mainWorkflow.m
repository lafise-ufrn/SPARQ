classdef test_mainWorkflow < matlab.unittest.TestCase
% test_mainWorkflow  Fluxo do main generico e referencia visual/cacheavel.

    methods (Test)

        function recursiveDiscoveryExcludesResultsAndSorts(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            mkdir(fullfile(folder, 'b'));
            mkdir(fullfile(folder, 'a'));
            outputRoot = fullfile(folder, 'SPARQ_results');
            mkdir(outputRoot);
            writeRecording(fullfile(folder, 'b', 'recording.mat'));
            writeRecording(fullfile(folder, 'a', 'recording.mat'));
            writeRecording(fullfile(outputRoot, 'ignored.mat'));

            files = SPARQ.internal.discoverInputFiles( ...
                folder, '*.mat', outputRoot);

            testCase.verifyNumElements(files, 2);
            testCase.verifyTrue(contains(files(1), [filesep 'a' filesep]));
            testCase.verifyTrue(contains(files(2), [filesep 'b' filesep]));
            testCase.verifyFalse(any(contains(files, 'SPARQ_results')));
        end

        function mainParametersApplyOnlyFilledOverrides(testCase)
            session = SPARQ.createSession(zeros(5, 100), 1000);
            config = baseConfig("");
            config.excludedChannels = [4 5];
            config.detection.thresholdStd = 6;
            config.output.includeNaN = true;

            params = SPARQ.internal.mainParameters(session, config);

            testCase.verifyEqual(params.detection.thresholdStd, 6);
            testCase.verifyEqual(params.detection.mergeGapSamples, 100);
            testCase.verifyEqual(params.detection.minSimultaneousChannels, 3);
            testCase.verifyEqual(params.channels.excluded, [4 5]);
            testCase.verifyTrue(params.output.includeNaN);
            testCase.verifyFalse(params.output.includeConcat);
        end

        function interactiveReferenceReusesValidatedManualCache(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourceFile = fullfile(folder, 'recording.mat');
            marker = 1;
            save(sourceFile, 'marker');
            session = SPARQ.createSession(zeros(2, 401), 1000, ...
                'SourceFile', sourceFile);
            cacheFile = fullfile(folder, 'cache', 'reference.mat');

            writeReferenceCacheFixture( ...
                cacheFile, sourceFile, 401, [0 0.4], [0.1 0.2]);
            [cachedIdx, cachedInfo] = SPARQ.reference.selectInteractive( ...
                session, 'CacheFile', cacheFile);
            testCase.verifyTrue(cachedInfo.wasCached);
            testCase.verifyEqual(cachedInfo.interval, [0.1 0.2]);
            testCase.verifyEqual(cachedIdx([1 end]), [101 201]);
        end

        function genericMainMirrorsFoldersAndSavesCanonicalResults(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            mkdir(fullfile(folder, 'subject-a'));
            mkdir(fullfile(folder, 'subject-b'));
            writeRecording(fullfile(folder, 'subject-a', 'recording.mat'));
            writeRecording(fullfile(folder, 'subject-b', 'recording.mat'));
            outputRoot = fullfile(folder, 'SPARQ_results');
            mkdir(outputRoot);
            writeRecording(fullfile(outputRoot, 'must-not-be-input.mat'));
            writeReferenceCacheFixture(fullfile(outputRoot, ...
                '.reference_cache', 'subject-a', 'recording_reference.mat'), ...
                fullfile(folder, 'subject-a', 'recording.mat'), ...
                400, [0 0.399], [0 0.099]);
            writeReferenceCacheFixture(fullfile(outputRoot, ...
                '.reference_cache', 'subject-b', 'recording_reference.mat'), ...
                fullfile(folder, 'subject-b', 'recording.mat'), ...
                400, [0 0.399], [0 0.099]);

            config = baseConfig(folder);
            batch = SPARQ.internal.runMain(config);

            testCase.verifyEqual(height(batch.report), 2);
            testCase.verifyEqual(batch.report.Status, repmat("ok", 2, 1));
            testCase.verifyEqual(numel(unique(batch.report.OutputFile)), 2);
            testCase.verifyTrue(all(isfile(batch.report.OutputFile)));
            testCase.verifyTrue(any(contains( ...
                batch.report.OutputFile, [filesep 'subject-a' filesep])));
            testCase.verifyTrue(any(contains( ...
                batch.report.OutputFile, [filesep 'subject-b' filesep])));
            testCase.verifyTrue(all(endsWith( ...
                batch.report.OutputFile, "_clean.mat")));

            saved = load(batch.report.OutputFile(1), 'SPARQ_result');
            cleanSignals = saved.SPARQ_result.result.cleanSignals;
            testCase.verifyClass(cleanSignals.noiseMask, 'logical');
            testCase.verifySize(cleanSignals.noiseMask, [1 400]);
            testCase.verifyFalse(isfield(cleanSignals, 'concat'));
            testCase.verifyFalse(isfield(cleanSignals, 'nan'));
            testCase.verifyEqual( ...
                saved.SPARQ_result.provenance.reference.method, ...
                "interactive-selection");
        end

        function genericMainSavesAllPlotImages(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourceFile = fullfile(folder, 'recording.mat');
            writeRecording(sourceFile);
            outputRoot = fullfile(folder, 'SPARQ_results');
            writeReferenceCacheFixture(fullfile(outputRoot, ...
                '.reference_cache', 'recording_reference.mat'), ...
                sourceFile, 400, [0 0.399], [0 0.099]);

            previousVisibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off');
            figureCleanup = onCleanup(@() cleanUpPlotFigures( ...
                previousVisibility));

            config = baseConfig(folder);
            config.plot.enabled = true;
            batch = SPARQ.internal.runMain(config);

            testCase.verifyEqual(batch.report.Status, "ok");
            imageFiles = dir(fullfile( ...
                outputRoot, 'imagens', 'recording_*.png'));
            testCase.verifyNumElements(imageFiles, 4);
            testCase.verifyTrue(all([imageFiles.bytes] > 0));
            testCase.verifyEqual(sort(string({imageFiles.name})), sort([ ...
                "recording_raw.png", ...
                "recording_thresholds.png", ...
                "recording_noise_windows.png", ...
                "recording_saved_percentage.png"]));
        end

        function genericMainExpandsRealDataIntoIndependentSessions(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourceFile = fullfile(folder, 'RealData.mat');
            writeRealData(sourceFile);
            cacheRoot = fullfile(folder, 'SPARQ_results', ...
                '.reference_cache', 'RealData');
            writeReferenceCacheFixture(fullfile( ...
                cacheRoot, 'RUN-1_reference.mat'), sourceFile, 400, ...
                [545.008, 545.008 + 399/1000], ...
                [545.008, 545.008 + 99/1000]);
            writeReferenceCacheFixture(fullfile( ...
                cacheRoot, 'RUN-2_reference.mat'), sourceFile, 400, ...
                [1086.053, 1086.053 + 399/1000], ...
                [1086.053, 1086.053 + 99/1000]);

            config = baseConfig(folder);
            config.filePattern = "RealData.mat";
            batch = SPARQ.internal.runMain(config);

            testCase.verifyEqual(height(batch.report), 2);
            testCase.verifyEqual(batch.report.Status, ["ok"; "ok"]);
            testCase.verifyEqual(batch.report.InputFormat, ...
                ["realdata"; "realdata"]);
            testCase.verifyEqual(batch.report.SessionId, ["RUN-1"; "RUN-2"]);
            testCase.verifyEqual(batch.manifest.Condition, ...
                ["speed-30"; "speed-45"]);
            testCase.verifyEqual(batch.report.Channels, [14; 14]);
            testCase.verifyEqual(batch.report.Samples, [400; 400]);
            testCase.verifyEqual(numel(unique(batch.report.OutputFile)), 2);
            testCase.verifyTrue(all(isfile(batch.report.OutputFile)));
            testCase.verifyTrue(all(contains(batch.report.OutputFile, ...
                [filesep 'RealData' filesep])));

            testCase.verifyTrue(isfile(fullfile( ...
                cacheRoot, 'RUN-1_reference.mat')));
            testCase.verifyTrue(isfile(fullfile( ...
                cacheRoot, 'RUN-2_reference.mat')));
        end

        function discoveryFailureDoesNotAbortOtherFiles(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            writeRecording(fullfile(folder, 'valid.mat'));
            unrelated = 1;
            save(fullfile(folder, 'invalid.mat'), 'unrelated');
            writeReferenceCacheFixture(fullfile(folder, 'SPARQ_results', ...
                '.reference_cache', 'valid_reference.mat'), ...
                fullfile(folder, 'valid.mat'), 400, [0 0.399], [0 0.099]);

            config = baseConfig(folder);
            batch = SPARQ.internal.runMain(config);

            testCase.verifyEqual(height(batch.report), 2);
            testCase.verifyEqual(nnz(batch.report.Status == "ok"), 1);
            testCase.verifyEqual(nnz(batch.report.Status == "failed"), 1);
            failed = batch.report(batch.report.Status == "failed", :);
            testCase.verifyTrue(contains(failed.SourceFile, 'invalid.mat'));
            testCase.verifyNotEmpty(failed.ErrorIdentifier);
            succeeded = batch.report(batch.report.Status == "ok", :);
            testCase.verifyTrue(contains(succeeded.SourceFile, 'valid.mat'));
            testCase.verifyTrue(isfile(succeeded.OutputFile));
        end

    end
end

% ------------------------------------------------------------------------
function config = baseConfig(dataFolder)
    config.dataFolder = string(dataFolder);
    config.filePattern = "*.mat";
    config.inputFormat = "auto";
    config.loader.lfpVariable = "LFP";
    config.loader.samplingRateVariable = "fs";
    config.loader.samplingRateHz = [];
    config.loader.timeVariable = "";
    config.loader.channelLabelsVariable = "";
    config.loader.dataOrientation = "channels-by-samples";
    config.loader.signalUnits = "arbitrary";
    config.loader.signalScale = 1;
    config.excludedChannels = [];
    config.detection.thresholdStd = [];
    config.detection.minSimultaneousChannels = [];
    config.detection.mergeGapSamples = [];
    config.detection.settleWindowSamples = [];
    config.detection.settleToleranceStd = [];
    config.output.includeConcat = false;
    config.output.includeNaN = false;
    config.outputFolderName = "SPARQ_results";
    config.overwriteResults = false;
    config.forceNewReferences = false;
    config.maxDisplayPointsPerChannel = 1000;
    config.plot.enabled = false;
end

% ------------------------------------------------------------------------
function writeRealData(filePath)
    RUN.signal = {zeros(14, 400), ones(14, 400)};
    RUN.signal{1}(:, 250:270) = 10;
    RUN.signal{2}(:, 300:320) = 11;
    RUN.srate = 1000;
    RUN.time = {545.008 + (0:399) / RUN.srate, ...
        1086.053 + (0:399) / RUN.srate};
    RUN.channels = "channel-" + (1:14);
    RUN.speed = [30 45];
    save(filePath, 'RUN');
end

% ------------------------------------------------------------------------
function writeRecording(filePath)
    fs = 1000;
    LFP = repmat([-1 1], 4, 200);
    LFP(:, 250:270) = LFP(:, 250:270) + 10;
    save(filePath, 'LFP', 'fs');
end

% ------------------------------------------------------------------------
function [folder, cleanupObject] = temporaryFolder()
    folder = tempname;
    mkdir(folder);
    cleanupObject = onCleanup(@() removeTemporaryFolder(folder));
end

% ------------------------------------------------------------------------
function removeTemporaryFolder(folder)
    if exist(folder, 'dir') == 7
        rmdir(folder, 's');
    end
end

% ------------------------------------------------------------------------
function cleanUpPlotFigures(previousVisibility)
    tags = SPARQ.internal.figureTags();
    tagFields = fieldnames(tags);
    for i = 1:numel(tagFields)
        figures = findall(groot, 'Type', 'figure', ...
            'Tag', tags.(tagFields{i}));
        delete(figures);
    end
    set(groot, 'DefaultFigureVisible', previousVisibility);
end
