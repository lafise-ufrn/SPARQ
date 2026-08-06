classdef test_createSession < matlab.unittest.TestCase
% test_createSession  Testes do contrato canonico e das unidades da sessao.

    methods (Test)

        function buildsCanonicalSessionWithSeconds(testCase)
            lfp = reshape(1:12, 3, 4);

            session = SPARQ.createSession(lfp, 2, ...
                'SubjectId', "subject-1", 'SessionId', "session-a", ...
                'SignalUnits', "uV");

            testCase.verifyEqual(session.lfp, lfp);
            testCase.verifyEqual(session.time, [0 0.5 1 1.5]);
            testCase.verifyEqual(session.samplingRateHz, 2);
            testCase.verifyEqual(session.timeUnits, "seconds");
            testCase.verifyEqual(session.channelLabels, ["ch1"; "ch2"; "ch3"]);
            testCase.verifyEqual(session.subjectId, "subject-1");
            testCase.verifyEqual(session.ratId, session.subjectId);
            testCase.verifyEqual(session.sessionId, "session-a");
            testCase.verifyEqual(session.signalUnits, "uV");
            testCase.verifyEmpty(session.events);
        end

        function normalizesSamplesByChannelsAndIntegerStorage(testCase)
            stored = int16([1 2 3; 4 5 6; 7 8 9; 10 11 12]);

            session = SPARQ.createSession(stored, 1000, ...
                'DataOrientation', "samples-by-channels", ...
                'SignalScale', 0.25);

            testCase.verifyClass(session.lfp, 'double');
            testCase.verifyEqual(session.lfp, double(stored.') * 0.25);
            testCase.verifyEqual(session.metadata.originalSignalClass, "int16");
            testCase.verifyEqual(session.metadata.signalScaleApplied, 0.25);
        end

        function rejectsTimeInconsistentWithSamplingRate(testCase)
            testCase.verifyError(@() SPARQ.createSession(zeros(2, 4), 10, ...
                'Time', [0 0.1 0.21 0.3]), ...
                'SPARQ:createSession:inconsistentTime');
        end

        function rejectsNonFiniteSignalBeforeDetection(testCase)
            lfp = zeros(2, 10);
            lfp(1, 5) = NaN;

            testCase.verifyError(@() SPARQ.createSession(lfp, 1000), ...
                'SPARQ:createSession:nonFiniteLfp');
        end

        function coreProcessingDoesNotRequireEvents(testCase)
            lfp = repmat([-1 1], 3, 100);
            session = SPARQ.createSession(lfp, 1000, ...
                'SubjectId', "subject-without-ttl");
            params = SPARQ.profiles.esteiraOdor();
            params.channels.count = 3;
            params.channels.excluded = [];
            params.detection.minSimultaneousChannels = 2;

            result = SPARQ.processSession(session, 1:100, params);

            testCase.verifyEmpty(result.noise.windows);
            testCase.verifyFalse(any(result.cleanSignals.noiseMask));
            testCase.verifyEqual(result.subjectId, "subject-without-ttl");
            testCase.verifyEqual(result.ratId, result.subjectId);
            testCase.verifyEqual(result.samplingRateHz, 1000);
            testCase.verifyEqual(result.timeUnits, "seconds");
        end

        function legacyLoaderPromotesSubjectIdAndKeepsAlias(testCase)
            root = tempname;
            subjectFolder = fullfile(root, 'subject-legacy');
            mkdir(subjectFolder);
            cleanup = onCleanup(@() rmdir(root, 's'));

            LFP = zeros(16, 20);
            INFO.ttltime = 1:16;
            INFO.areas = compose("area%02d", (1:16).');
            INFO.timevector = 0:19;
            sourceFile = fullfile(subjectFolder, ...
                'subject-legacy_neutro.mat');
            save(sourceFile, 'LFP', 'INFO');

            session = SPARQ.loadSession(sourceFile, ...
                SPARQ.profiles.esteiraOdor());

            testCase.verifyEqual(session.subjectId, "subject-legacy");
            testCase.verifyEqual(session.ratId, 'subject-legacy');
        end

    end
end
