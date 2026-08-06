function manifest = validateManifest(manifest)
% manifest = SPARQ.validateManifest(manifest)
%
% Valida e normaliza uma tabela de sessoes para SPARQ.runBatch. Somente
% SourceFile e obrigatoria; as demais colunas canonicas ausentes recebem
% valores neutros e podem ser preenchidas pelo loader.

    if ~istable(manifest) || height(manifest) < 1
        error('SPARQ:validateManifest:badManifest', ...
            'manifest must be a nonempty table.');
    end
    if ~ismember('SourceFile', manifest.Properties.VariableNames)
        error('SPARQ:validateManifest:missingSourceFile', ...
            'manifest must contain a SourceFile column.');
    end

    nRows = height(manifest);
    manifest.SourceFile = normalizeTextColumn( ...
        manifest.SourceFile, nRows, 'SourceFile', "");
    if any(ismissing(manifest.SourceFile)) || any(strlength(manifest.SourceFile) == 0)
        error('SPARQ:validateManifest:emptySourceFile', ...
            'SourceFile values must be nonempty.');
    end
    for i = 1:nRows
        [~, ~, extension] = fileparts(manifest.SourceFile(i));
        if ~strcmpi(extension, '.mat')
            error('SPARQ:validateManifest:unsupportedExtension', ...
                'SourceFile accepts electrophysiology recordings only from .mat files.');
        end
    end

    manifest = addTextColumn(manifest, 'SubjectId', "");
    manifest = addTextColumn(manifest, 'SessionId', "");
    manifest = addTextColumn(manifest, 'Condition', "");
    manifest = addTextColumn(manifest, 'OutputDirectory', "");
    manifest = addTextColumn(manifest, 'ReferenceCacheFile', "");
    manifest = addTextColumn(manifest, 'InputFormat', "");
    manifest = addNumericColumn(manifest, 'SamplingRateHz', NaN);

    if ~ismember('DataSelector', manifest.Properties.VariableNames)
        manifest.DataSelector = repmat({struct()}, nRows, 1);
    elseif ~iscell(manifest.DataSelector) || numel(manifest.DataSelector) ~= nRows || ...
            ~all(cellfun(@(x) isstruct(x) && isscalar(x), manifest.DataSelector))
        error('SPARQ:validateManifest:badDataSelector', ...
            'DataSelector must contain one scalar struct per row.');
    else
        manifest.DataSelector = manifest.DataSelector(:);
    end

    if ~ismember('LoaderOptions', manifest.Properties.VariableNames)
        manifest.LoaderOptions = repmat({struct()}, nRows, 1);
    elseif ~iscell(manifest.LoaderOptions) || numel(manifest.LoaderOptions) ~= nRows || ...
            ~all(cellfun(@(x) isstruct(x) && isscalar(x), manifest.LoaderOptions))
        error('SPARQ:validateManifest:badLoaderOptions', ...
            'LoaderOptions must contain one scalar struct per row.');
    else
        manifest.LoaderOptions = manifest.LoaderOptions(:);
    end

    if ~ismember('ExcludedChannels', manifest.Properties.VariableNames)
        manifest.ExcludedChannels = repmat({[]}, nRows, 1);
    elseif ~iscell(manifest.ExcludedChannels) || ...
            numel(manifest.ExcludedChannels) ~= nRows || ...
            ~all(cellfun(@(x) isnumeric(x) && isreal(x), manifest.ExcludedChannels))
        error('SPARQ:validateManifest:badExcludedChannels', ...
            'ExcludedChannels must contain one real numeric vector per row.');
    else
        manifest.ExcludedChannels = cellfun( ...
            @(x) x(:).', manifest.ExcludedChannels(:), 'UniformOutput', false);
    end

    fs = manifest.SamplingRateHz;
    if any(~isnan(fs) & (~isfinite(fs) | fs <= 0))
        error('SPARQ:validateManifest:badSamplingRate', ...
            'SamplingRateHz must be NaN or positive and finite.');
    end
end

% ------------------------------------------------------------------------
function manifest = addTextColumn(manifest, name, defaultValue)
    nRows = height(manifest);
    if ~ismember(name, manifest.Properties.VariableNames)
        manifest.(name) = repmat(string(defaultValue), nRows, 1);
    else
        manifest.(name) = normalizeTextColumn( ...
            manifest.(name), nRows, name, defaultValue);
    end
end

% ------------------------------------------------------------------------
function values = normalizeTextColumn(values, nRows, name, defaultValue)
    if isempty(values)
        values = repmat(string(defaultValue), nRows, 1);
    elseif ischar(values) || iscellstr(values) || isstring(values)
        values = string(values);
        values = values(:);
    else
        error('SPARQ:validateManifest:badTextColumn', ...
            '%s must contain text.', name);
    end
    if numel(values) ~= nRows
        error('SPARQ:validateManifest:columnLengthMismatch', ...
            '%s must have one value per row.', name);
    end
end

% ------------------------------------------------------------------------
function manifest = addNumericColumn(manifest, name, defaultValue)
    nRows = height(manifest);
    if ~ismember(name, manifest.Properties.VariableNames)
        manifest.(name) = repmat(defaultValue, nRows, 1);
    elseif ~isnumeric(manifest.(name)) || ~isreal(manifest.(name)) || ...
            numel(manifest.(name)) ~= nRows
        error('SPARQ:validateManifest:badNumericColumn', ...
            '%s must contain one real numeric value per row.', name);
    else
        manifest.(name) = double(manifest.(name)(:));
    end
end
