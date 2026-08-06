function value = readMatPath(filePath, path)
% value = SPARQ.internal.readMatPath(filePath, path)
%
% Le um caminho MAT restrito a campos e indices numericos, sem usar eval.
% Exemplos: "data", "RUN.signal", "RUN.signal{2}", "cube(:,:,1)".

    path = string(path);
    if ~isscalar(path) || strlength(path) == 0
        error('SPARQ:io:mat:badPath', 'MAT paths must be nonempty text scalars.');
    end
    root = regexp(char(path), '^[A-Za-z]\w*', 'match', 'once');
    if isempty(root)
        error('SPARQ:io:mat:badPath', 'Invalid MAT path "%s".', path);
    end
    raw = load(filePath, root);
    if ~isfield(raw, root)
        error('SPARQ:io:mat:missingPath', ...
            'Root variable "%s" was not found in %s.', root, filePath);
    end
    value = raw.(root);
    remainder = extractAfter(path, strlength(string(root)));
    while strlength(remainder) > 0
        text = char(remainder);
        if text(1) == '.'
            token = regexp(text, '^\.([A-Za-z]\w*)', 'tokens', 'once');
            if isempty(token) || ~isstruct(value) || ~isscalar(value) || ...
                    ~isfield(value, token{1})
                error('SPARQ:io:mat:missingPath', ...
                    'Field in MAT path "%s" was not found.', path);
            end
            value = value.(token{1});
            consumed = 1 + strlength(string(token{1}));
        elseif text(1) == '{' || text(1) == '('
            closing = ')';
            isCell = text(1) == '{';
            if isCell
                closing = '}';
            end
            stop = find(text == closing, 1, 'first');
            if isempty(stop)
                error('SPARQ:io:mat:badPath', 'Unclosed index in "%s".', path);
            end
            indexText = text(2:stop - 1);
            indices = parseIndices(indexText, ndims(value));
            try
                if isCell
                    value = value{indices{:}};
                else
                    value = value(indices{:});
                end
            catch exception
                error('SPARQ:io:mat:badIndex', ...
                    'Invalid index in MAT path "%s": %s', path, exception.message);
            end
            consumed = stop;
        else
            error('SPARQ:io:mat:badPath', ...
                'Unexpected token in MAT path "%s".', path);
        end
        remainder = extractAfter(remainder, consumed);
    end
end

function indices = parseIndices(text, nDimensions)
    parts = strtrim(string(strsplit(text, ',')));
    indices = cell(1, numel(parts));
    for i = 1:numel(parts)
        if parts(i) == ":"
            indices{i} = ':';
        elseif ~isempty(regexp(char(parts(i)), '^\d+$', 'once'))
            indices{i} = str2double(parts(i));
        else
            error('SPARQ:io:mat:badIndex', ...
                'Only positive integer indices and colon are accepted.');
        end
    end
    if isempty(parts) || numel(parts) > max(2, nDimensions)
        error('SPARQ:io:mat:badIndex', 'Invalid number of MAT indices.');
    end
end
