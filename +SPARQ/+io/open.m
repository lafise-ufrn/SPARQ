function reader = open(source, options)
% reader = SPARQ.io.open(source, options)
%
% Abre um arquivo MAT reutilizavel. Use reader.inspect(), reader.load(selector)
% e reader.close(). SPARQ.io.load e SPARQ.runBatch gerenciam esse ciclo
% automaticamente para usos simples.

    if nargin < 2
        options = struct();
    end
    reader = SPARQ.io.SourceReader(source, options);
end
