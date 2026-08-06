%% SPARQ - SCRIPT PRINCIPAL PARA PROCESSAMENTO GENERICO
% Este script foi preparado para quem deseja usar a biblioteca como uma
% ferramenta computacional, sem precisar conhecer sua organizacao interna.
%
% COMO USAR:
%   1. Edite somente o bloco "EDITE AQUI" abaixo.
%   2. Clique em Run.
%   3. Para cada gravacao ainda sem referencia salva, clique duas vezes no
%      grafico: primeiro no inicio e depois no fim de um trecho sem ruido.
%   4. Consulte a tabela `batch.report` criada no Workspace.

%% =========================== EDITE AQUI ================================

% Pasta que contem os arquivos .mat. Deixe "" para escolher em uma janela.
config.dataFolder = "";

% Todos os arquivos com este padrao, inclusive em subpastas, serao lidos.
config.filePattern = "*.mat";

% "auto" reconhece os presets MAT conhecidos. Informe "mat" para forcar o
% mapeamento manual.
config.inputFormat = "auto";

config.loader.lfpVariable = "LFP";              % matriz de LFP
config.loader.samplingRateVariable = "fs";      % frequencia em Hz
% Para usar uma frequencia fixa, deixe a linha acima = "" e informe, ex.: 1000.
config.loader.samplingRateHz = [];
config.loader.timeVariable = "";                 
% opcional, var do tempo em segundos. caso permaneca "", a biblioteca cria
% automaticamente.
config.loader.channelLabelsVariable = "";        
% opcional. nome da var que contem os rotulos dos canais.
config.loader.dataOrientation = "channels-by-samples";    
% canais nas linhas e amostras na colunas. "samples-by-channels" caso contrario 
config.loader.signalUnits = "arbitrary";         % ex.: "uV".
config.loader.signalScale = 1;                 
% fator multiplicativo aplicado ao carregar. uV = 1; mV = 1000; V = 1e6. 

% Canais que nao devem participar da deteccao. [] usa todos os canais.
config.excludedChannels = [];

% MAPA DOS PARAMETROS DE DETECCAO
% Deixe [] para manter o valor padrao.
config.detection.thresholdStd = [];               % padrao: 4
config.detection.minSimultaneousChannels = [];     % padrao: min(7, nCanais)
config.detection.mergeGapSamples = [];            % padrao: 100 amostras
config.detection.settleWindowSamples = [];        % padrao: 50 amostras
config.detection.settleToleranceStd = [];         % padrao: 2

% Saidas: noiseMask e sempre salva (vetor logico -> 0 = nao identificado como ruido;
% 1 = ruido). 
% As duas matrizes abaixo sao opcionais. uma retorna o sinal concatenado e
% a outra o sinal completo com os ruidos trocados por NaNs.
config.output.includeConcat = false;
config.output.includeNaN = false;

% Resultados sao gravados em uma subpasta dentro da pasta de dados definida
% anteriormente.
config.outputFolderName = "SPARQ_results";
config.overwriteResults = false;          % true substitui resultados existentes
config.forceNewReferences = false;        % true ignora referencias em cache
config.maxDisplayPointsPerChannel = 20000;

% Abre as quatro figuras do fluxo visual: selecao, limites, ruido e resumo.
config.plot.enabled = true;

%% ======================== FIM DO BLOCO EDITAVEL ========================

% Garante que a pasta da biblioteca esteja no path, mesmo quando este script
% for executado a partir de outro diretorio.
libraryRoot = fileparts(mfilename('fullpath'));
addpath(libraryRoot);

% Executa descoberta, selecao das referencias, deteccao e salvamento.
batch = SPARQ.internal.runMain(config);
