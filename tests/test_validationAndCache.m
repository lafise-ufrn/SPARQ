classdef test_validationAndCache < matlab.unittest.TestCase
% test_validationAndCache  Regressões de validação e identidade do cache.

    methods (Test)

        function unknownParameterIsRejectedAtPublicProcessingBoundary(testCase)
            [session, params] = validSession();
            params.unrecognized = 123;

            testCase.verifyError(@() SPARQ.processSession( ...
                session, 1:20, params), ...
                'SPARQ:validateParameters:unknownField');
        end

        function fractionalConditionIndexIsRejected(testCase)
            [session, params] = validSession();
            params.conditions.process = 1.5;

            testCase.verifyError(@() SPARQ.processSession( ...
                session, 1:20, params), ...
                'SPARQ:validateParameters:badConditionIndex');
        end

        function directIntegerSessionMustBeNormalizedFirst(testCase)
            [session, params] = validSession();
            session.lfp = int16(session.lfp);

            testCase.verifyError(@() SPARQ.processSession( ...
                session, 1:20, params), ...
                'SPARQ:validateSession:badLfp');
        end

        function invalidReferenceIndicesFailBeforeDetector(testCase)
            [session, params] = validSession();

            testCase.verifyError(@() SPARQ.processSession( ...
                session, [1 2.5 3], params), ...
                'SPARQ:processSession:badReference');
        end

        function cacheIdentityIsReusedAndStaleMetadataIsRejected(testCase)
            [folder, cleanupObject] = temporaryFolder(); %#ok<ASGLU>
            sourceFile = fullfile(folder, 'source.mat');
            marker = 1;
            save(sourceFile, 'marker');

            session = SPARQ.createSession(zeros(2, 100), 1000, ...
                'SubjectId', "subject", 'Condition', "baseline", ...
                'SourceFile', sourceFile);
            params = SPARQ.processingOptions(2);
            params.io.cacheReferences = true;
            params.plot.enabled = false;

            referenceSeconds = [0.01 0.02];
            cacheMetadata.schemaVersion = "1.0";
            cacheMetadata.nSamples = 100;
            cacheMetadata.timeBounds = [0 0.099];
            source = SPARQ.internal.sourceIdentity(sourceFile);
            cacheMetadata.sourceToken = source.token;
            cachePath = fullfile(folder, ...
                'subject_baseline_clean_reference.mat');
            save(cachePath, 'referenceSeconds', 'cacheMetadata');

            [indices, loadedSeconds, wasCached] = ...
                SPARQ.selectCleanReference(session, params, folder);
            testCase.verifyTrue(wasCached);
            testCase.verifyEqual(loadedSeconds, referenceSeconds);
            testCase.verifyGreaterThanOrEqual(numel(indices), 2);

            cacheMetadata.nSamples = 99;
            save(cachePath, 'referenceSeconds', 'cacheMetadata');
            testCase.verifyError(@() SPARQ.selectCleanReference( ...
                session, params, folder), ...
                'SPARQ:selectCleanReference:manualReferenceMissing');
        end

    end
end

% ------------------------------------------------------------------------
function [session, params] = validSession()
    session = SPARQ.createSession(repmat([-1 1], 2, 50), 1000, ...
        'SubjectId', "test", 'Condition', "condition");
    params = SPARQ.processingOptions(2);
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
