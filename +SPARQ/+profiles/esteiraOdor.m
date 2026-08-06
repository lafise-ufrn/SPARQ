function params = esteiraOdor()
% params = SPARQ.profiles.esteiraOdor()
%
% Retorna o perfil de compatibilidade do experimento esteira/odor. Este perfil
% concentra todas as escolhas especificas desse conjunto de dados: montagem
% de 16 canais, canal respiratorio excluido, eventos de
% referencia, sistemas de aquisicao, condicoes, visualizacao e nomenclatura de
% arquivos.
%
% O perfil e a fonte dos valores usados pelas entradas legadas
% defaultNoiseParameters, SPARQ.defaultOptions, cleanExperiment e
% runNoiseCleaning. Alterar qualquer valor abaixo pode mudar os resultados ou
% a compatibilidade com esse fluxo e exige atualizar deliberadamente
% os testes golden em tests/test_esteiraOdorGolden.m.
%
% SAIDAS:
%   params = estrutura completa de parametros que reproduz o comportamento
%            atual do experimento esteira/odor
%
% EXEMPLO:
%   params = SPARQ.profiles.esteiraOdor();
%   results = cleanExperiment(folderPath, params);
%
% OBSERVAÇÕES:
%   - Este e um perfil de compatibilidade, nao um conjunto de valores universais
%     para qualquer gravacao de LFP.
%   - O detector numerico permanece em
%     SPARQ.internal.detectNoiseWindows e nao e modificado por este perfil.

    % --- Deteccao de ruido ------------------------------------------------
    params.detection.thresholdStd            = 4;
    params.detection.minSimultaneousChannels = 7;
    params.detection.mergeGapSamples         = 100;
    params.detection.settleWindowSamples     = 50;
    params.detection.settleToleranceStd      = 2;

    % --- Montagem de canais -----------------------------------------------
    params.channels.count               = 16;
    params.channels.excluded            = 12;
    params.channels.referenceEventStart = 11;
    params.channels.referenceEventEnd   = 16;

    % --- Aquisicao / taxa de amostragem -----------------------------------
    params.acquisition.legacySubjectIds   = ["rato2", "rato3"];
    params.acquisition.legacySamplingRate = 1;
    params.acquisition.samplingRate       = 30000;

    % --- Condicoes a processar --------------------------------------------
    params.conditions.names        = ["neutro", "aversivo"];
    params.conditions.displayNames = ["Neutral Odor", "Aversive Odor"];
    params.conditions.process      = [1 2];

    % --- Preambulo espectral legado (nao usado pela deteccao) -------------
    params.spectral.samplingRate = 1000;
    params.spectral.window       = 2 * 1000;
    params.spectral.noverlap     = 1000;
    params.spectral.nfft         = 2^11;

    % --- Plotagem ----------------------------------------------------------
    params.plot.enabled        = true;
    params.plot.channelSpacing = 1500;
    params.plot.thresholdStd   = 4;
    params.plot.eventColor     = [0.35 0.35 0.35];

    % --- Saidas do processamento ------------------------------------------
    params.output.includeConcat = false;
    params.output.includeNaN    = false;

    % --- Entrada / saida ---------------------------------------------------
    params.io.cleanSuffix          = "_clean";
    params.io.saveFormat           = "-v7.3";
    params.io.cacheReferences      = true;
    params.io.referenceCacheName   = "clean_reference.mat";
    params.io.sessionFolderPattern = "rato*";
end
