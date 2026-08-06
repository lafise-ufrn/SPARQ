classdef test_processSessionOutputs < matlab.unittest.TestCase
% test_processSessionOutputs  Testes de contrato das saidas do processamento.
%
% Confirma que SPARQ.processSession sempre promove a mascara logica de
% comprimento total do detector para a saida cleanSignals primaria, enquanto
% as grandes matrizes concatenada e mascarada com NaN continuam opcionais de
% forma independente.

    methods (Test)

        function primaryMaskExactlyMatchesDetectorMask(testCase)
            [session, params] = makeSession();

            result = SPARQ.processSession(session, 1:2000, params);

            testCase.verifyEqual( ...
                result.cleanSignals.noiseMask, result.noise.mask);
            testCase.verifyClass(result.cleanSignals.noiseMask, 'logical');
            testCase.verifySize( ...
                result.cleanSignals.noiseMask, size(session.time));
            testCase.verifyEqual(result.subjectId, "synthetic");
            testCase.verifyEqual(result.ratId, result.subjectId);
        end

        function optionalRepresentationsAreIndependent(testCase)
            [session, params] = makeSession();
            params.output.includeConcat = false;
            params.output.includeNaN = true;

            result = SPARQ.processSession(session, 1:2000, params);

            testCase.verifyFalse(isfield(result.cleanSignals, 'concat'));
            testCase.verifyTrue(isfield(result.cleanSignals, 'nan'));
        end

        function outputFlagsMustBeLogicalScalars(testCase)
            [session, params] = makeSession();
            params.output.includeConcat = 1;

            testCase.verifyError( ...
                @() SPARQ.processSession(session, 1:2000, params), ...
                'SPARQ:validateParameters:notLogicalScalar');
        end

    end
end

% ------------------------------------------------------------------------
function [session, params] = makeSession()
    [time, lfp, params] = makeSyntheticRecording();
    params.channels.referenceEventStart = 1;
    params.channels.referenceEventEnd = params.channels.count;

    session.subjectId  = "synthetic";
    session.condition  = "test";
    session.sourceFile = "synthetic.mat";
    session.time       = time;
    session.lfp        = lfp;
    session.events     = 1:params.channels.count;
    session.areas      = repmat("area", params.channels.count, 1);
end
