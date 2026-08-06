% demo_savingResults.m
%
% Demonstra o salvamento EXPLICITO de resultados, usando as pecas da API de
% nivel inferior em vez de SPARQ.runSession, que reune tudo. E util quando
% o sinal limpo deve ser escrito em outro lugar que nao ao lado dos dados
% brutos (por exemplo, uma pasta separada de "dados derivados"), ou quando
% salvar e uma etapa deliberadamente separada do processamento (por exemplo,
% scripts em lote que processam primeiro e deixam uma pessoa decidir o que manter).
%
% EDITE os caminhos abaixo para apontar para seus dados antes de executar.

matFilePath = fullfile('path', 'to', 'legacy_data', 'subject', 'recording_aversivo.mat');
referenceCacheDir = fullfile('path', 'to', 'legacy_data', 'subject');
resultsDir = fullfile('path', 'to', 'derived_results');

params = defaultNoiseParameters();
params.output.includeConcat = true; % segunda saida opcional
params.output.includeNaN = true;    % terceira saida opcional

session = SPARQ.loadSession(matFilePath, params);

% Reutiliza uma selecao manual valida em cache ou abre a figura para que o
% usuario escolha a referencia com dois cliques.
[referenceIdx, ~, wasCached] = SPARQ.selectCleanReference( ...
    session, params, referenceCacheDir);
fprintf('Reference %s.\n', ternary(wasCached, 'loaded from cache', 'selected interactively'));

result = SPARQ.processSession(session, referenceIdx, params);

% Salvo em resultsDir, deliberadamente NAO na pasta de onde vieram os dados brutos.
outputPath = SPARQ.saveCleanSignals(result, resultsDir, params);
fprintf('Clean signal saved to: %s\n', outputPath);

function out = ternary(condition, ifTrue, ifFalse)
    if condition
        out = ifTrue;
    else
        out = ifFalse;
    end
end
