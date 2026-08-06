% demo_singleSession.m
%
% Processa UMA sessao de ponta a ponta usando o bloco de mais alto nivel que
% ainda opera em um unico arquivo: SPARQ.runSession. Abre a selecao
% interativa da referencia limpa (ou reutiliza uma em cache), executa a
% deteccao, desenha todos os graficos e salva o sinal limpo para exatamente um
% arquivo, com todos os caminhos fornecidos explicitamente, sem cd nem
% suposicoes sobre a pasta atual.
%
% EDITE os tres caminhos abaixo para apontar para seus dados antes de executar.

matFilePath = fullfile('path', 'to', 'legacy_data', 'subject', 'recording_aversivo.mat');
outputDir   = fullfile('path', 'to', 'derived_results');

params = defaultNoiseParameters();
% A noiseMask logica e sempre salva. Habilite cada matriz opcional somente se
% esta analise precisar dela:
params.output.includeConcat = true;
params.output.includeNaN = true;

result = SPARQ.runSession(matFilePath, outputDir, params);

fprintf('Rat %s, condition %s: %.1f%% saved, %.1f%% discarded as noise.\n', ...
    result.subjectId, result.condition, result.noise.percentSaved, result.noise.percentNoise);
