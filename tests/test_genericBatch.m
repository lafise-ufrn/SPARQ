classdef test_genericBatch < matlab.unittest.TestCase
% test_genericBatch  Integracao do loader MAT, manifesto, lote e persistencia.

    methods (Test)

        function configurableMatLoaderBuildsCanonicalSession(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            filePath = fullfile(folder, 'custom.mat');
            data = int16(reshape(1:40, 4, 10));
            fs = 1000;
            labels = ["A"; "B"; "C"; "D"];
            save(filePath, 'data', 'fs', 'labels');

            mapping.lfpVariable = "data";
            mapping.samplingRateVariable = "fs";
            mapping.channelLabelsVariable = "labels";
            mapping.signalScale = 0.5;
            mapping.subjectId = "subject-01";
            session = SPARQ.io.loadMat(filePath, mapping);

            testCase.verifyClass(session.lfp, 'double');
            testCase.verifyEqual(session.lfp, double(data) * 0.5);
            testCase.verifyEqual(session.samplingRateHz, 1000);
            testCase.verifyEqual(session.channelLabels, labels);
            testCase.verifyEqual(session.subjectId, "subject-01");
            testCase.verifyEqual(session.metadata.loader, "SPARQ.io.loadMat");
        end

        function manifestBatchProcessesAndSavesVersionedResult(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            outputDirectory = fullfile(folder, 'derived');

            fs = 1000;
            data = repmat([-1 1], 4, 200);
            data(:, 250:270) = data(:, 250:270) + 10;
            labels = ["one"; "two"; "three"; "four"];
            save(sourcePath, 'data', 'fs', 'labels');

            mapping.lfpVariable = "data";
            mapping.samplingRateVariable = "fs";
            mapping.channelLabelsVariable = "labels";
            cacheFile = fullfile(folder, 'reference-cache.mat');
            writeReferenceCacheFixture( ...
                cacheFile, sourcePath, 400, [0 0.399], [0 0.099]);
            manifest = SPARQ.createManifest(sourcePath, ...
                'SubjectId', "mouse-1", ...
                'SessionId', "baseline", ...
                'ReferenceCacheFile', cacheFile, ...
                'OutputDirectory', outputDirectory, ...
                'LoaderOptions', mapping);

            batch = SPARQ.runBatch(manifest, 'SaveResults', true);

            testCase.verifyEqual(batch.report.Status, "ok");
            testCase.verifyEqual(batch.report.SubjectId, "mouse-1");
            testCase.verifyNotEmpty(batch.results{1}.noise.windows);
            testCase.verifyEqual(batch.results{1}.subjectId, "mouse-1");
            testCase.verifyTrue(isfile(batch.report.OutputFile));

            saved = load(batch.report.OutputFile, 'SPARQ_result');
            testCase.verifyEqual(saved.SPARQ_result.schemaVersion, "1.0");
            testCase.verifyEqual(saved.SPARQ_result.software.status, "beta");
            testCase.verifyEqual( ...
                saved.SPARQ_result.result.cleanSignals.noiseMask, ...
                batch.results{1}.cleanSignals.noiseMask);
            testCase.verifyEqual( ...
                saved.SPARQ_result.provenance.source.exists, true);
        end

        function manifestHasNoAutomaticReferenceColumns(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            LFP = zeros(2, 100);
            fs = 1000;
            save(sourcePath, 'LFP', 'fs');

            mapping.samplingRateVariable = "fs";
            manifest = SPARQ.createManifest(sourcePath, ...
                'LoaderOptions', mapping);
            expectedColumns = {'SourceFile', 'SubjectId', 'SessionId', ...
                'Condition', 'SamplingRateHz', 'ReferenceCacheFile', ...
                'OutputDirectory', 'InputFormat', 'DataSelector', ...
                'LoaderOptions', 'ExcludedChannels'};
            testCase.verifyEqual( ...
                manifest.Properties.VariableNames, expectedColumns);
        end

        function versionedSaveRefusesOverwriteByDefault(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            outputPath = fullfile(folder, 'result.mat');
            result.cleanSignals.noiseMask = false(1, 10);
            params = SPARQ.processingOptions(1);

            SPARQ.io.saveResult(result, outputPath, params, struct());

            testCase.verifyError(@() SPARQ.io.saveResult( ...
                result, outputPath, params, struct()), ...
                'SPARQ:io:saveResult:fileExists');
        end

    end
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
