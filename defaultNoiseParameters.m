function params = defaultNoiseParameters()
% params = defaultNoiseParameters()
%
% Wrapper que retorna a estrutura de parâmetros padrão para
% todo o pipeline de limpeza de ruído (limiares de detecção, montagem de
% canais, resolução da taxa de amostragem, condições a processar, plotagem e
% comportamento de E/S). Os valores pertencem ao perfil de compatibilidade
% esteira/odor; consulte SPARQ.defaultOptions para a documentação completa,
% campo a campo, de cada parâmetro e seu significado.
%
% as duas chamadas necessárias para uma execução completa são:
%
%   params  = defaultNoiseParameters();
%   results = cleanExperiment(folderPath, params);
%
% SAÍDAS:
%   params = estrutura de parâmetros; consulte SPARQ.defaultOptions para a
%            referência completa
%
% EXEMPLO (sobrescreve um parâmetro e mantém os demais no padrão):
%   params = defaultNoiseParameters();
%   params.detection.thresholdStd = 5;
%   results = cleanExperiment('C:\data\odor_experiment', params);

    params = SPARQ.defaultOptions();
end
