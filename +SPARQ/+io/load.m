function session = load(source, options)
% session = SPARQ.io.load(source, options)
%
% Carrega uma unica sessao de um arquivo MAT.
% Arquivos MAT multissessao exigem options.dataSelector; use
% SPARQ.discoverSessions para obter seletores validos.

    if nargin < 2 || isempty(options)
        options = struct();
    end
    selector = struct();
    if isfield(options, 'dataSelector')
        selector = options.dataSelector;
        options = rmfield(options, 'dataSelector');
    end
    reader = SPARQ.io.SourceReader(source, options);
    cleanupObject = onCleanup(@() reader.close());
    session = reader.load(selector, options);
end
