function params = processingOptions(nChannels)
% params = SPARQ.processingOptions(nChannels)
%
% Retorna uma configuracao computacional neutra quanto a especie, pastas,
% condicoes e sistema de aquisicao. Os parametros numericos do detector sao os
% valores historicos congelados do perfil esteira/odor, mas a montagem e
% adaptada ao numero de canais informado e nenhum canal e excluido por padrao.
%
% ENTRADAS:
%   nChannels = numero positivo e inteiro de canais da sessao
%
% SAIDAS:
%   params = estrutura completa aceita por SPARQ.processSession
%
% OBSERVAÇÕES:
%   Os limiares historicos nao sao universais. Em particular,
%   minSimultaneousChannels e limitado a nChannels apenas para produzir uma
%   configuracao valida; cada laboratorio deve calibra-lo e validar o metodo
%   em sua montagem, taxa de amostragem e preparacao.

    if ~isnumeric(nChannels) || ~isreal(nChannels) || ~isscalar(nChannels) || ...
            ~isfinite(nChannels) || nChannels < 1 || nChannels ~= round(nChannels)
        error('SPARQ:processingOptions:badChannelCount', ...
            'nChannels must be a positive integer scalar.');
    end

    params = SPARQ.profiles.esteiraOdor();
    params.channels.count = nChannels;
    params.channels.excluded = [];
    params.channels.referenceEventStart = 1;
    params.channels.referenceEventEnd = 1;
    params.detection.minSimultaneousChannels = min( ...
        params.detection.minSimultaneousChannels, nChannels);

    params.acquisition.legacySubjectIds = strings(1, 0);
    params.conditions.names = "session";
    params.conditions.displayNames = "Session";
    params.conditions.process = 1;
    params.plot.enabled = false;
    params.io.cacheReferences = false;
    params.io.sessionFolderPattern = "*";
end
