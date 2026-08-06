% demo_visualization.m
%
% Demonstra a composicao explicita da camada de plotagem: visao geral dos
% canais base, sobreposicao de limiares, sobreposicao de janelas de ruido e
% grafico de barras do resumo de preservacao, cada um desenhado por sua
% propria funcao de proposito unico em SPARQ.viz. E util quando voce quer os
% graficos SEM reexecutar o comportamento completo de salvamento em disco de
% SPARQ.runSession, ou quer organiza-los de outra forma (subplots, layout
% de figura personalizado etc.).
%
% As figuras sao recicladas por SPARQ.internal.getOrCreateFigure, o mesmo
% helper usado por SPARQ.runSession; assim, reexecutar esta demo redesenha
% as mesmas 2 janelas em vez de acumular novas a cada vez.
%
% EDITE os caminhos abaixo para apontar para seus dados antes de executar.

matFilePath = fullfile('path', 'to', 'legacy_data', 'subject', 'recording_aversivo.mat');
referenceCacheDir = fullfile('path', 'to', 'legacy_data', 'subject');

params = defaultNoiseParameters();
tags = SPARQ.internal.figureTags();

session = SPARQ.loadSession(matFilePath, params);

overviewFig = SPARQ.internal.getOrCreateFigure(tags.overview);
overviewAxes = axes('Parent', overviewFig);
SPARQ.viz.channels(session, params, overviewAxes);

[referenceIdx, ~, ~] = SPARQ.selectCleanReference( ...
    session, params, referenceCacheDir, overviewAxes);

result = SPARQ.processSession(session, referenceIdx, params);

% Compoe as sobreposicoes em um unico eixo novo: canais base + limiares +
% blocos de ruido detectados, todos na mesma plotagem.
combinedFig = SPARQ.internal.getOrCreateFigure(tags.noiseWindows);
combinedAxes = axes('Parent', combinedFig);
SPARQ.viz.channels(session, params, combinedAxes);
SPARQ.viz.withThresholds(combinedAxes, session, result.noise, params);
SPARQ.viz.withNoiseWindows(combinedAxes, session, result.noise, params);

% Resumo no nivel da sessao, em sua propria figura independente.
summaryFig = SPARQ.internal.getOrCreateFigure(tags.summary);
summaryAxes = axes('Parent', summaryFig);
SPARQ.viz.preservationSummary(result.noise, ...
    SPARQ.internal.sessionTitle(session, params), summaryAxes);
