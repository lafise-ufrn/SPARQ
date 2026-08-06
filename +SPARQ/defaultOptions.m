function params = defaultOptions()
% params = SPARQ.defaultOptions()
%
% Retorna a estrutura completa de parametros do pipeline de limpeza de ruido,
% preenchida com os valores do perfil SPARQ.profiles.esteiraOdor. Esta funcao
% e um wrapper de compatibilidade.
%
%
% SAIDAS:
%   params = estrutura com os seguintes grupos e padroes:
%
%     params.detection   -- algoritmo de deteccao de ruido
%       .thresholdStd            = 4    numero de desvios-padrao que
%                                       define o limiar de desvio por canal
%       .minSimultaneousChannels = 7    quantidade de canais que deve exceder o
%                                       o limiar na mesma amostra para que ela
%                                       seja candidata a ruido (n_threshold)
%       .mergeGapSamples         = 100  candidatas mais proximas que isto (em
%                                       amostras) sao fundidas em um bloco
%                                       (gap_limit)
%       .settleWindowSamples     = 50   janela de observacao a frente/atras usada ao
%                                       expandir um bloco (buffer)
%       .settleToleranceStd      = 2    faixa, em desvios-padrao, dentro da qual
%                                       dentro da qual o sinal deve cair para a
%                                       borda do bloco parar de crescer
%
%     params.channels    -- montagem de eletrodos
%       .count                   = 16   total de canais adquiridos
%       .excluded                = 12   canais a remover
%       .referenceEventStart     = 11   indice de evento que marca o inicio do
%                                       intervalo x de analise / linhas de limiar
%       .referenceEventEnd       = 16   indice de evento que marca seu fim
%
%     params.acquisition -- resolucao da taxa de amostragem (consulte resolveSamplingRate)
%       .legacySubjectIds        = ["rato2","rato3"]  sessoes gravadas em
%                                       sistema legado (tempo ja em s)
%       .legacySamplingRate      = 1
%       .samplingRate            = 30000 taxa de amostragem da aquisicao moderna
%
%     params.conditions  -- quais condicoes experimentais processar
%       .names                   = ["neutro","aversivo"]  sufixos de arquivo; o
%                                       N-esimo nome mapeia para o indice N
%       .displayNames            = ["Neutral Odor","Aversive Odor"]  rotulos
%                                       legiveis usados nos titulos dos graficos,
%                                       na mesma ordem de .names
%       .process                 = [1 2]  indices de condicoes a executar. O
%                                       padrao executa AMBAS as condicoes.
%
%     params.spectral    -- parametros auxiliares para analises espectrais;
%                           nao usados pela deteccao
%       .samplingRate            = 1000
%       .window                  = 2000
%       .noverlap                = 1000
%       .nfft                    = 2048
%
%     params.plot        -- visualizacao
%       .enabled                 = true  quando false nao mostra os graficos
%                                       de processamento; uma referencia manual
%                                       valida em cache continua obrigatoria
%       .channelSpacing          = 1500  deslocamento vertical entre canais
%                                       nos graficos empilhados
%       .thresholdStd            = 4     multiplicador do desvio-padrao para as
%                                       linhas de limiar tracejadas nos graficos
%       .eventColor              = [.35 .35 .35] cor RGB visivel dos eventos
%
%     params.output      -- saidas do processamento
%       .includeConcat           = false quando true, inclui a matriz LFP
%                                       opcional `.concat`, sem lacunas
%       .includeNaN              = false quando true, inclui a matriz LFP
%                                       opcional `.nan`, com comprimento total
%                                       (amostras ruidosas substituidas por NaN)
%       A mascara logica `.noiseMask` de comprimento total e SEMPRE produzida,
%       independentemente dessas duas flags: false (0) significa limpo, true
%       (1) significa ruido.
%
%     params.io          -- comportamento de entrada/saida
%       .cleanSuffix             = "_clean"  acrescentado ao nome-base dos
%                                       sinais limpos salvos
%       .saveFormat              = "-v7.3"   formato de save() para matrizes grandes
%       .cacheReferences         = true      armazena em cache no disco a selecao
%                                       interativa da referencia limpa
%       .referenceCacheName      = "clean_reference.mat"
%       .sessionFolderPattern    = "rato*"   curinga de dir() usado por cleanExperiment
%                                       para descobrir pastas por animal sob a
%                                       raiz de dados. Sobrescreva para reutilizar
%                                       a biblioteca com outra convencao de nomes
%                                       (por exemplo, "subject*", "P*").
%
% NOTAS:
%   - Editar este arquivo altera os padroes da biblioteca para todos. Para
%     mudar valores em uma unica execucao, copie a estrutura e sobrescreva os
%     campos: p = defaultNoiseParameters(); p.detection.thresholdStd = 5;

    % Os valores especificos do experimento vivem em um perfil nomeado para
    % que nao sejam confundidos com padroes universais de LFP.
    % Este wrapper permanece por compatibilidade com a API existente.
    params = SPARQ.profiles.esteiraOdor();
end
