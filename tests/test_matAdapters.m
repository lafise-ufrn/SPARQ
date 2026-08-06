classdef test_matAdapters < matlab.unittest.TestCase
% test_matAdapters  Contratos de descoberta e carregamento de arquivos MAT.

    methods (Test)
        function manifestsRemainBackwardCompatible(testCase)
            manifest = SPARQ.createManifest("recording.mat");
            testCase.verifyTrue(ismember('InputFormat', manifest.Properties.VariableNames));
            testCase.verifyTrue(ismember('DataSelector', manifest.Properties.VariableNames));
            testCase.verifyEqual(manifest.InputFormat, "");
            testCase.verifyEmpty(fieldnames(manifest.DataSelector{1}));
        end

        function nestedMatCellsAreDiscoveredAndLoaded(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'nested.mat');
            RUN.signal = {reshape(1:40, 4, 10), reshape(41:80, 4, 10)};
            RUN.time = {(10:19).' / 1000, (20:29).' / 1000};
            RUN.srate = 1000;
            RUN.channels = {'a', 'b', 'c', 'd'};
            RUN.speed = [30 45];
            save(path, 'RUN');

            manifest = SPARQ.discoverSessions(path);
            testCase.verifyEqual(height(manifest), 2);
            testCase.verifyEqual(manifest.Condition, ["speed-30"; "speed-45"]);
            options = manifest.LoaderOptions{2};
            options.inputFormat = manifest.InputFormat(2);
            options.dataSelector = manifest.DataSelector{2};
            options.condition = manifest.Condition(2);
            session = SPARQ.io.load(path, options);
            testCase.verifyEqual(session.lfp, RUN.signal{2});
            testCase.verifyEqual(session.time, RUN.time{2}.');
            testCase.verifyEqual(session.metadata.inputAdapter, "realdata");
        end

        function genericMatSupportsThreeDimensionalTrials(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'cube.mat');
            data = reshape(1:120, 4, 10, 3);
            fs = 500;
            save(path, 'data', 'fs');
            map.lfpPath = "data";
            map.samplingRatePath = "fs";
            map.trialDimension = 3;
            manifest = SPARQ.discoverSessions(path, 'LoaderOptions', map);
            testCase.verifyEqual(height(manifest), 3);
            options = map;
            options.inputFormat = manifest.InputFormat(3);
            options.dataSelector = manifest.DataSelector{3};
            session = SPARQ.io.load(path, options);
            testCase.verifyEqual(session.lfp, data(:, :, 3));
        end

        function genericMatSupportsValidatedNestedPaths(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'nested-generic.mat');
            payload.data = reshape(1:60, 3, 20);
            payload.fs = 250;
            payload.labels = {'x', 'y', 'z'};
            save(path, 'payload');
            map.lfpPath = "payload.data";
            map.samplingRatePath = "payload.fs";
            map.channelLabelsPath = "payload.labels";
            manifest = SPARQ.discoverSessions(path, 'LoaderOptions', map);
            options = map;
            options.inputFormat = manifest.InputFormat;
            options.dataSelector = manifest.DataSelector{1};
            session = SPARQ.io.load(path, options);
            testCase.verifyEqual(session.lfp, payload.data);
            testCase.verifyEqual(session.channelLabels, ["x"; "y"; "z"]);
            bad = map;
            bad.lfpPath = "payload.missing";
            testCase.verifyError(@() SPARQ.discoverSessions(path, ...
                'LoaderOptions', bad), 'SPARQ:io:mat:missingPath');
        end

        function longLfpsPresetExpandsTrialsAndAreas(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'long.mat');
            srate = 1000;
            NewAreas = {'a', 'b'};
            GOODTRIALS_A = {[10 12], 20};
            GOODTRIALS_V = {30, [40 41]};
            LFPallAtrials = makeLongCells([2 1], 2, 20, 100);
            LFPallVtrials = makeLongCells([1 2], 2, 20, 500);
            electLeft = 1;
            electRight = 2;
            save(path, 'srate', 'NewAreas', 'GOODTRIALS_A', 'GOODTRIALS_V', ...
                'LFPallAtrials', 'LFPallVtrials', 'electLeft', 'electRight', '-v7.3');
            manifest = SPARQ.discoverSessions(path);
            testCase.verifyEqual(height(manifest), 6);
            reader = SPARQ.io.SourceReader(path, struct('inputFormat', 'longlfps'));
            cleanupReader = onCleanup(@() reader.close());
            session = reader.load(manifest.DataSelector{2}, struct());
            testCase.verifySize(session.lfp, [2 20]);
            testCase.verifyEqual(session.metadata.originalTrial, 12);
            testCase.verifyEqual(session.channelLabels, ["a"; "b"]);
        end

        function dispatcherBatchReportsInputMetrics(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'recording.mat');
            LFP = repmat([-1 1], 4, 100);
            fs = 1000;
            save(path, 'LFP', 'fs');
            mapping.samplingRateVariable = "fs";
            cacheFile = fullfile(folder, 'reference-cache.mat');
            writeReferenceCacheFixture( ...
                cacheFile, path, 200, [0 0.199], [0 0.049]);
            manifest = SPARQ.createManifest(path, ...
                'LoaderOptions', mapping, ...
                'ReferenceCacheFile', cacheFile);
            batch = SPARQ.runBatch(manifest);
            testCase.verifyEqual(batch.report.Status, "ok");
            testCase.verifyEqual(batch.report.InputFormat, "mat");
            testCase.verifyEqual(batch.report.Channels, 4);
            testCase.verifyEqual(batch.report.Samples, 200);
            testCase.verifyGreaterThanOrEqual(batch.report.LoadSeconds, 0);
            testCase.verifyGreaterThanOrEqual(batch.report.ProcessSeconds, 0);
        end

        function unsupportedExtensionsAreRejected(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            path = fullfile(folder, 'recording.unsupported');
            fid = fopen(path, 'w');
            fwrite(fid, uint8(1), 'uint8');
            fclose(fid);
            testCase.verifyError(@() SPARQ.io.SourceReader(path, struct()), ...
                'SPARQ:io:detectInputFormat:unsupportedExtension');
            testCase.verifyError(@() SPARQ.createManifest(path), ...
                'SPARQ:validateManifest:unsupportedExtension');
            testCase.verifyError(@() SPARQ.io.loadMat(path, struct()), ...
                'SPARQ:io:loadMat:unsupportedExtension');
        end
    end
end

function cells = makeLongCells(trialCounts, nAreas, nSamples, offset)
    cells = cell(nAreas, numel(trialCounts));
    for area = 1:nAreas
        for subject = 1:numel(trialCounts)
            cells{area, subject} = offset + area * 1000 + subject * 100 + ...
                reshape(1:(trialCounts(subject) * nSamples), trialCounts(subject), nSamples);
        end
    end
end

function [folder, cleanupObject] = temporaryFolder()
    folder = tempname;
    mkdir(folder);
    cleanupObject = onCleanup(@() removeTemporaryFolder(folder));
end

function removeTemporaryFolder(folder)
    if exist(folder, 'dir') == 7
        rmdir(folder, 's');
    end
end
