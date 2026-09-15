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
            testCase.verifyEqual(saved.SPARQ_result.schemaVersion, "2.0");
            testCase.verifyEqual(saved.SPARQ_result.noiseMask, ...
                batch.results{1}.cleanSignals.noiseMask);
            testCase.verifyEqual(fieldnames(saved.SPARQ_result), ...
                {'noiseMask'; 'samplingRateHz'; 'schemaVersion'});
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
            result.samplingRateHz = 1000;
            params = SPARQ.processingOptions(1);

            SPARQ.io.saveResult(result, outputPath, params, struct());

            testCase.verifyError(@() SPARQ.io.saveResult( ...
                result, outputPath, params, struct()), ...
                'SPARQ:io:saveResult:fileExists');
        end

        function optionalSignalsArePromotedIndependently(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            mask = logical([0 1 0 0]);
            nanSignal = [1 NaN 3 4; 5 NaN 7 8];
            concatSignal = [1 3 4; 5 7 8];
            combinations = logical([0 0; 1 0; 0 1; 1 1]);

            for i = 1:size(combinations, 1)
                result.cleanSignals.noiseMask = mask;
                result.cleanSignals.channels = [1 3];
                result.samplingRateHz = 1000;
                result.signalUnits = "uV";
                if combinations(i, 1)
                    result.cleanSignals.concat = concatSignal;
                end
                if combinations(i, 2)
                    result.cleanSignals.nan = nanSignal;
                end

                outputPath = fullfile(folder, sprintf('result-%d.mat', i));
                params = SPARQ.processingOptions(3);
                SPARQ.io.saveResult(result, outputPath, params, struct());
                loaded = load(outputPath, 'SPARQ_result');
                saved = loaded.SPARQ_result;

                testCase.verifyEqual(isfield(saved, 'concat'), ...
                    combinations(i, 1));
                testCase.verifyEqual(isfield(saved, 'nan'), ...
                    combinations(i, 2));
                testCase.verifyEqual(saved.noiseMask, mask);
                if combinations(i, 1)
                    testCase.verifyEqual(saved.concat, concatSignal);
                end
                if combinations(i, 2)
                    testCase.verifyEqual(saved.nan, nanSignal);
                end
                if any(combinations(i, :))
                    testCase.verifyEqual(saved.channels, [1 3]);
                    testCase.verifyEqual(saved.signalUnits, "uV");
                else
                    testCase.verifyFalse(isfield(saved, 'channels'));
                    testCase.verifyFalse(isfield(saved, 'signalUnits'));
                end

                result.cleanSignals = rmfield(result.cleanSignals, ...
                    intersect({'concat', 'nan'}, ...
                    fieldnames(result.cleanSignals)));
            end
        end

        function legacyVersionedResultCanBeSafelyReplaced(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            outputPath = fullfile(folder, 'legacy-result.mat');
            SPARQ_result.schemaVersion = "1.0";
            SPARQ_result.software = struct();
            SPARQ_result.processedAtUtc = "2026-01-01T00:00:00Z";
            SPARQ_result.result = struct();
            SPARQ_result.parameters = struct();
            SPARQ_result.provenance = struct();
            save(outputPath, 'SPARQ_result');

            result.cleanSignals.noiseMask = false(1, 10);
            result.samplingRateHz = 1000;
            params = SPARQ.processingOptions(1);
            SPARQ.io.saveResult(result, outputPath, params, struct(), ...
                'Overwrite', true);

            loaded = load(outputPath, 'SPARQ_result');
            testCase.verifyEqual(loaded.SPARQ_result.schemaVersion, "2.0");
            testCase.verifyEqual(loaded.SPARQ_result.noiseMask, false(1, 10));
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
