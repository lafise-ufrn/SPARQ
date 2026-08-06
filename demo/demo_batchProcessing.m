% demo_batchProcessing.m
%
% Executa o pipeline em cada sujeito/condicao encontrada na pasta de dados de
% um experimento. Pastas de
% sessoes e nomes de arquivos sao DESCOBERTOS no disco (via
% params.io.sessionFolderPattern); adicionar ou remover a pasta
% de um sujeito nao exige mudanca de codigo.
%
% Uma falha em qualquer sessao (arquivo ausente, dados malformados etc.) e
% registrada no relatorio, em vez de interromper todo o lote.
%
% EDITE o caminho abaixo para apontar para a raiz do seu experimento antes de executar.

dataRoot = fullfile("<path to data>");

% runNoiseCleaning usa os padroes: a saida primaria de sinal salva e
% noiseMask. Use cleanExperiment com uma estrutura params editada se .concat
% e/ou .nan tambem forem necessarios.
results = runNoiseCleaning(dataRoot);

disp(results.report);

nFailed = sum(strcmp(results.report.Status, 'failed'));
fprintf('\n%d/%d sessions processed successfully (%d failed).\n', ...
    height(results.report) - nFailed, height(results.report), nFailed);
