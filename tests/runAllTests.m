function result = runAllTests()
% result = runAllTests()
%
% Executor conveniente: executa cada teste unitario desta pasta e imprime um
% resumo de aprovado/reprovado. Pode ser executado de qualquer lugar; esta
% funcao resolve sua propria pasta e a raiz da biblioteca a partir de mfilename,
% portanto nunca depende do diretorio de trabalho atual.
%
% USO:
%   runAllTests()

    testsDir = fileparts(mfilename('fullpath'));
    libraryRoot = fileparts(testsDir);

    addpath(libraryRoot);
    addpath(testsDir);

    suite = matlab.unittest.TestSuite.fromFolder(testsDir);
    result = run(suite);

    disp(result);
    if any([result.Failed]) || any([result.Incomplete])
        error('SPARQ:tests:failed', ...
            '%d test(s) failed and %d were incomplete.', ...
            nnz([result.Failed]), nnz([result.Incomplete]));
    end
end
