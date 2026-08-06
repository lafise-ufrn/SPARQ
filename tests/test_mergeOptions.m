classdef test_mergeOptions < matlab.unittest.TestCase
% test_mergeOptions  Testes unitarios de SPARQ.internal.mergeOptions.
%
% Confirma que as sobrescritas sao aplicadas (incluindo estruturas aninhadas),
% que campos intocados mantem seu valor padrao e que campos desconhecidos ou
% digitados incorretamente geram um erro claro, em vez de serem ignorados
% silenciosamente.

    methods (Test)

        function overrideAppliesOnTopOfDefaults(testCase)
            defaults.a = 1;
            defaults.b = 2;

            overrides.a = 10;

            merged = SPARQ.internal.mergeOptions(defaults, overrides);

            testCase.verifyEqual(merged.a, 10);
            testCase.verifyEqual(merged.b, 2);
        end

        function nestedStructsMergeRecursively(testCase)
            defaults.detection.thresholdStd = 4;
            defaults.detection.mergeGapSamples = 100;

            overrides.detection.thresholdStd = 6;

            merged = SPARQ.internal.mergeOptions(defaults, overrides);

            testCase.verifyEqual(merged.detection.thresholdStd, 6);
            testCase.verifyEqual(merged.detection.mergeGapSamples, 100);
        end

        function emptyOverridesReturnDefaultsUnchanged(testCase)
            defaults.a = 1;

            merged = SPARQ.internal.mergeOptions(defaults, []);

            testCase.verifyEqual(merged, defaults);
        end

        function unknownFieldRaisesError(testCase)
            defaults.a = 1;
            overrides.thisFieldDoesNotExist = 99;

            testCase.verifyError( ...
                @() SPARQ.internal.mergeOptions(defaults, overrides), ...
                'SPARQ:mergeOptions:unknownField');
        end

        function nonStructOverridesRaiseError(testCase)
            defaults.a = 1;

            testCase.verifyError( ...
                @() SPARQ.internal.mergeOptions(defaults, 42), ...
                'SPARQ:mergeOptions:notStruct');
        end

    end
end
