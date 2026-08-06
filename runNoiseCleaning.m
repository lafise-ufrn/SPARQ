function results = runNoiseCleaning(folderPath)
% results = runNoiseCleaning(folderPath)
%
% Ponto de entrada mais simples possível: executa todo o pipeline de limpeza
% de ruído na pasta de dados de um experimento usando todos os parâmetros
% padrão. Equivalente a:
%
%   params  = defaultNoiseParameters();
%   results = cleanExperiment(folderPath, params);
%
% Use isto quando os limiares de detecção, a montagem e o conjunto de
% condições padrão forem exatamente os desejados, sem parâmetros a
% sobrescrever. Com os padrões, toda sessão salva contém o
% `clean_data.noiseMask` lógico obrigatório; as matrizes opcionais `.concat` e
% `.nan` não são materializadas. Use cleanExperiment diretamente quando
% precisar habilitar uma saída opcional ou alterar outro parâmetro.
%
% ENTRADAS:
%   folderPath = caminho absoluto para a raiz de dados do experimento (consulte
%                cleanExperiment para o layout esperado das pastas)
%
% SAÍDAS:
%   results = estrutura com os campos .report (tabela) e .sessions (matriz de
%             células com resultados por sessão); consulte cleanExperiment
%             para obter detalhes
%
% EXEMPLO:
%   results = runNoiseCleaning('C:\data\odor_experiment');
%   disp(results.report)

    results = cleanExperiment(folderPath, defaultNoiseParameters());
end
