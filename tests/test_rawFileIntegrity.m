classdef test_rawFileIntegrity < matlab.unittest.TestCase
% test_rawFileIntegrity  Protecoes contra alteracao das gravacoes de origem.

    methods (Test)

        function mainDefaultPreservesRawFileByteForByte(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            writeRecording(sourcePath);
            writeMainCache(folder, sourcePath);
            before = fileSnapshot(sourcePath);

            batch = SPARQ.internal.runMain(mainConfig(folder));

            testCase.verifyEqual(batch.report.Status, "ok");
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function overwriteResultsPreservesRawFileByteForByte(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            writeRecording(sourcePath);
            writeMainCache(folder, sourcePath);
            before = fileSnapshot(sourcePath);

            config = mainConfig(folder);
            firstBatch = SPARQ.internal.runMain(config);
            config.overwriteResults = true;
            batch = SPARQ.internal.runMain(config);

            testCase.verifyEqual(firstBatch.report.Status, "ok");
            testCase.verifyEqual(batch.report.Status, "ok");
            testCase.verifyTrue(isfile(batch.report.OutputFile));
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function forceNewReferenceAndOverwritePreserveRawFile(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            outputDirectory = fullfile(folder, 'derived');
            cachePath = fullfile(folder, 'cache', 'recording_reference.mat');
            writeRecording(sourcePath);
            writeReferenceCacheFixture( ...
                cachePath, sourcePath, 400, [0 0.399], [0.01 0.05]);
            before = fileSnapshot(sourcePath);

            map.samplingRateVariable = "fs";
            manifest = SPARQ.createManifest(sourcePath, ...
                'SessionId', "recording", ...
                'ReferenceCacheFile', cachePath, ...
                'OutputDirectory', outputDirectory, ...
                'LoaderOptions', map);
            batch = SPARQ.runBatch(manifest, ...
                'SaveResults', true, ...
                'Overwrite', true, ...
                'ForceNewReferences', true, ...
                'SelectionProvider', @(~) [0.06 0.12]);

            testCase.verifyEqual(batch.report.Status, "ok");
            testCase.verifyFalse(batch.results{1}.referenceInfo.wasCached);
            cached = load(cachePath, 'referenceSeconds');
            testCase.verifyEqual(cached.referenceSeconds, [0.06 0.12]);
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function failedInputPreservesRawFileByteForByte(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'invalid.mat');
            unrelated = magic(4);
            save(sourcePath, 'unrelated');
            before = fileSnapshot(sourcePath);

            batch = SPARQ.internal.runMain(mainConfig(folder));

            testCase.verifyEqual(batch.report.Status, "failed");
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function versionedSaverRefusesSourceAsDestination(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            writeRecording(sourcePath);
            before = fileSnapshot(sourcePath);
            result.sourceFile = string(sourcePath);
            result.cleanSignals.noiseMask = false(1, 10);
            params = SPARQ.processingOptions(1);
            provenance.source = SPARQ.internal.sourceIdentity(sourcePath);

            testCase.verifyError(@() SPARQ.io.saveResult( ...
                result, sourcePath, params, provenance, 'Overwrite', true), ...
                'SPARQ:io:saveResult:sourceOverwriteRefused');
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function legacySaverRefusesSourceAsDestination(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'subject_baseline_clean.mat');
            writeRecording(sourcePath);
            before = fileSnapshot(sourcePath);
            result.subjectId = "subject";
            result.condition = "baseline";
            result.sourceFile = string(sourcePath);
            result.cleanSignals.noiseMask = false(1, 10);
            params = SPARQ.defaultOptions();

            testCase.verifyError(@() SPARQ.saveCleanSignals( ...
                result, folder, params), ...
                'SPARQ:saveCleanSignals:sourceOverwriteRefused');
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function versionedSaverRefusesUnknownMatWithoutSourceMetadata(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            destination = fullfile(folder, 'unknown.mat');
            writeRecording(destination);
            before = fileSnapshot(destination);
            result.cleanSignals.noiseMask = false(1, 10);
            params = SPARQ.processingOptions(1);

            testCase.verifyError(@() SPARQ.io.saveResult( ...
                result, destination, params, struct(), 'Overwrite', true), ...
                'SPARQ:io:saveResult:unsafeOverwriteRefused');
            verifyFileUnchanged(testCase, destination, before);
        end

        function legacySaverRefusesUnknownMatWithoutSourceMetadata(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            destination = fullfile(folder, 'subject_baseline_clean.mat');
            writeRecording(destination);
            before = fileSnapshot(destination);
            result.subjectId = "subject";
            result.condition = "baseline";
            result.cleanSignals.noiseMask = false(1, 10);
            params = SPARQ.defaultOptions();

            testCase.verifyError(@() SPARQ.saveCleanSignals( ...
                result, folder, params), ...
                'SPARQ:saveCleanSignals:unsafeOverwriteRefused');
            verifyFileUnchanged(testCase, destination, before);
        end

        function referenceCacheRefusesSourceAsDestination(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, 'recording.mat');
            writeRecording(sourcePath);
            before = fileSnapshot(sourcePath);
            session = SPARQ.createSession(zeros(2, 100), 1000, ...
                'SourceFile', sourcePath);

            testCase.verifyError(@() SPARQ.reference.selectInteractive( ...
                session, 'CacheFile', sourcePath, 'ForceNew', true, ...
                'SelectionProvider', @(~) [0.01 0.02]), ...
                'SPARQ:reference:selectInteractive:sourceOverwriteRefused');
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function legacyReferenceCacheRefusesSourceAsDestination(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourcePath = fullfile(folder, ...
                'subject_baseline_clean_reference.mat');
            writeRecording(sourcePath);
            before = fileSnapshot(sourcePath);
            session = SPARQ.createSession(zeros(2, 100), 1000, ...
                'SubjectId', "subject", 'Condition', "baseline", ...
                'SourceFile', sourcePath);
            params = SPARQ.defaultOptions();
            params.plot.enabled = false;

            testCase.verifyError(@() SPARQ.selectCleanReference( ...
                session, params, folder), ...
                'SPARQ:selectCleanReference:sourceOverwriteRefused');
            verifyFileUnchanged(testCase, sourcePath, before);
        end

        function referenceCacheRefusesUnknownMatWithoutSourceMetadata(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            cachePath = fullfile(folder, 'unknown.mat');
            writeRecording(cachePath);
            before = fileSnapshot(cachePath);
            session = SPARQ.createSession(zeros(2, 100), 1000);

            testCase.verifyError(@() SPARQ.reference.selectInteractive( ...
                session, 'CacheFile', cachePath, 'ForceNew', true, ...
                'SelectionProvider', @(~) [0.01 0.02]), ...
                ['SPARQ:reference:selectInteractive:' ...
                 'unsafeCacheOverwriteRefused']);
            verifyFileUnchanged(testCase, cachePath, before);
        end

        function cacheCleanupDeletesOnlyValidatedCacheFiles(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sessionFolder = fullfile(folder, 'rato1');
            mkdir(sessionFolder);

            rawPath = fullfile(sessionFolder, ...
                'rato1_neutro_clean_reference.mat');
            writeRecording(rawPath);
            rawBefore = fileSnapshot(rawPath);

            resultPath = fullfile(sessionFolder, 'rato1_neutro_clean.mat');
            clean_data.noiseMask = false(1, 10);
            save(resultPath, 'clean_data');
            resultBefore = fileSnapshot(resultPath);

            cachePath = fullfile(sessionFolder, ...
                'rato1_aversivo_clean_reference.mat');
            referenceSeconds = [0.01 0.02];
            cacheMetadata.schemaVersion = "1.0";
            save(cachePath, 'referenceSeconds', 'cacheMetadata');

            deleted = SPARQ.clearReferenceCache(folder);

            testCase.verifyEqual(deleted, {cachePath});
            testCase.verifyFalse(isfile(cachePath));
            verifyFileUnchanged(testCase, rawPath, rawBefore);
            verifyFileUnchanged(testCase, resultPath, resultBefore);
        end

    end
end

% ------------------------------------------------------------------------
function config = mainConfig(folder)
    config.dataFolder = string(folder);
    config.plot.enabled = false;
    config.detection.minSimultaneousChannels = 2;
end

% ------------------------------------------------------------------------
function writeRecording(filePath)
    fs = 1000;
    time = (0:399) / fs;
    LFP = repmat(sin(2 * pi * 8 * time), 4, 1);
    LFP(:, 250:270) = LFP(:, 250:270) + 10;
    save(filePath, 'LFP', 'fs');
end

% ------------------------------------------------------------------------
function writeMainCache(folder, sourcePath)
    cachePath = fullfile(folder, 'SPARQ_results', ...
        '.reference_cache', 'recording_reference.mat');
    writeReferenceCacheFixture( ...
        cachePath, sourcePath, 400, [0 0.399], [0.01 0.10]);
end

% ------------------------------------------------------------------------
function snapshot = fileSnapshot(filePath)
    info = dir(filePath);
    snapshot.bytes = readFileBytes(filePath);
    snapshot.size = info.bytes;
    snapshot.modifiedDatenum = info.datenum;
end

% ------------------------------------------------------------------------
function verifyFileUnchanged(testCase, filePath, expected)
    testCase.verifyTrue(isfile(filePath), ...
        sprintf('The source file was deleted: %s', filePath));
    actual = fileSnapshot(filePath);
    testCase.verifyEqual(actual.size, expected.size, ...
        'The source file size changed.');
    testCase.verifyEqual(actual.bytes, expected.bytes, ...
        'The source file contents changed.');
    testCase.verifyEqual(actual.modifiedDatenum, expected.modifiedDatenum, ...
        'The source file modification time changed.');
end

% ------------------------------------------------------------------------
function bytes = readFileBytes(filePath)
    fileId = fopen(filePath, 'rb');
    if fileId < 0
        error('SPARQ:tests:cannotReadFile', ...
            'Could not open file for verification: %s', filePath);
    end
    cleanupObject = onCleanup(@() fclose(fileId));
    bytes = fread(fileId, Inf, '*uint8');
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
