classdef test_validChannels < matlab.unittest.TestCase
% test_validChannels  Testes unitarios de SPARQ.internal.validChannels.
%
% Confirma que a unica fonte da verdade para o conjunto de canais validos
% reproduz [1:11, 13:16] codificado originalmente sob a montagem padrao e se
% comporta corretamente para uma configuracao de montagem diferente.

    methods (Test)

        function defaultMontageMatchesOriginalLiteral(testCase)
            params = defaultNoiseParameters();
            channels = SPARQ.internal.validChannels(params);

            expected = [1:11, 13:16];
            testCase.verifyEqual(channels, expected);
        end

        function customExclusionIsRespected(testCase)
            params = defaultNoiseParameters();
            params.channels.count = 8;
            params.channels.excluded = [3 4];

            channels = SPARQ.internal.validChannels(params);

            testCase.verifyEqual(channels, [1 2 5 6 7 8]);
        end

        function outputIsAlwaysARowVector(testCase)
            params = defaultNoiseParameters();
            params.channels.count = 5;
            params.channels.excluded = 5;

            channels = SPARQ.internal.validChannels(params);

            testCase.verifySize(channels, [1 4]);
        end

    end
end
