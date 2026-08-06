% demo_matDiscovery 
% 
% Descobre e processa sessoes logicas em arquivos MAT.
% Substitua os caminhos de exemplo por arquivos MAT locais.

libraryRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(libraryRoot);

sources = ["RealData.mat"; "LongLFPs.mat"];
manifest = SPARQ.discoverSessions(sources);

% Cada sessao sem cache valido solicita dois cliques para selecionar um trecho
% limpo. A selecao manual pode ser reutilizada em execucoes posteriores por
% meio da coluna ReferenceCacheFile do manifesto.

% Os parametros genericos sao pontos de partida e nao limiares universais.
parameterProvider = @(session, ~) SPARQ.processingOptions(size(session.lfp, 1));

disp(manifest(:, {'SourceFile', 'SessionId', 'Condition', ...
    'InputFormat', 'SamplingRateHz'}));
% batch = SPARQ.runBatch(manifest, 'Parameters', parameterProvider);
