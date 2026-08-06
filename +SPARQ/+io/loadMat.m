function session = loadMat(matFilePath, options)
% session = SPARQ.io.loadMat(matFilePath, options)
%
% Carrega uma sessao canonica de um arquivo MAT com mapeamento configuravel de
% variaveis. Somente as variaveis solicitadas sao materializadas.
%
% ENTRADAS:
%   matFilePath = caminho para um arquivo MAT existente
%   options     = (opcional) struct parcial com:
%       .lfpVariable          = nome da matriz; padrao "LFP"
%       .samplingRateVariable = nome de uma variavel escalar em Hz; padrao ""
%       .samplingRateHz       = taxa explicita alternativa; padrao []
%       .timeVariable         = timestamps em segundos; padrao ""
%       .channelLabelsVariable= rotulos por canal; padrao ""
%       .eventsVariable       = eventos em segundos; padrao ""
%       .dataOrientation      = orientacao aceita por createSession
%       .subjectId, .sessionId, .condition, .signalUnits
%       .signalScale          = escala fisica aplicada ao sinal
%       .metadata             = struct escalar adicional
%
% SAIDAS:
%   session = estrutura de SPARQ.createSession
%
% EXEMPLO:
%   map.lfpVariable = "data";
%   map.samplingRateVariable = "fs";
%   session = SPARQ.io.loadMat("recording.mat", map);

    if nargin < 2 || isempty(options)
        options = struct();
    end
    if ~(ischar(matFilePath) || (isstring(matFilePath) && isscalar(matFilePath))) || ...
            exist(matFilePath, 'file') ~= 2
        error('SPARQ:io:loadMat:fileNotFound', ...
            'matFilePath must identify an existing file.');
    end
    [~, ~, extension] = fileparts(matFilePath);
    if ~strcmpi(extension, '.mat')
        error('SPARQ:io:loadMat:unsupportedExtension', ...
            'matFilePath must use the .mat extension.');
    end

    defaults.lfpVariable = "LFP";
    defaults.samplingRateVariable = "";
    defaults.samplingRateHz = [];
    defaults.timeVariable = "";
    defaults.channelLabelsVariable = "";
    defaults.eventsVariable = "";
    defaults.dataOrientation = "channels-by-samples";
    defaults.subjectId = "";
    defaults.sessionId = "";
    defaults.condition = "";
    defaults.signalUnits = "arbitrary";
    defaults.signalScale = 1;
    defaults.metadata = struct();
    options = SPARQ.internal.mergeOptions(defaults, options, 'loaderOptions');

    variableFields = {'lfpVariable', 'samplingRateVariable', 'timeVariable', ...
        'channelLabelsVariable', 'eventsVariable'};
    variableNames = strings(1, 0);
    for i = 1:numel(variableFields)
        value = options.(variableFields{i});
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            error('SPARQ:io:loadMat:badVariableName', ...
                'loaderOptions.%s must be a text scalar.', variableFields{i});
        end
        value = string(value);
        options.(variableFields{i}) = value;
        if strlength(value) > 0
            variableNames(end + 1) = value; %#ok<AGROW>
        end
    end
    variableNames = unique(variableNames, 'stable');
    raw = load(matFilePath, variableNames{:});

    lfp = requireVariable(raw, options.lfpVariable, matFilePath);
    if ~isempty(options.samplingRateHz)
        samplingRateHz = options.samplingRateHz;
    elseif strlength(options.samplingRateVariable) > 0
        samplingRateHz = requireVariable( ...
            raw, options.samplingRateVariable, matFilePath);
    else
        error('SPARQ:io:loadMat:missingSamplingRate', ...
            ['Provide loaderOptions.samplingRateHz or ' ...
             'loaderOptions.samplingRateVariable.']);
    end

    time = optionalVariable(raw, options.timeVariable);
    channelLabels = optionalVariable(raw, options.channelLabelsVariable);
    events = optionalVariable(raw, options.eventsVariable);

    metadata = options.metadata;
    if ~isstruct(metadata) || ~isscalar(metadata)
        error('SPARQ:io:loadMat:badMetadata', ...
            'loaderOptions.metadata must be a scalar struct.');
    end
    metadata.loader = "SPARQ.io.loadMat";
    metadata.variableMapping = options;

    session = SPARQ.createSession(lfp, samplingRateHz, ...
        'DataOrientation', options.dataOrientation, ...
        'Time', time, ...
        'ChannelLabels', channelLabels, ...
        'SubjectId', options.subjectId, ...
        'SessionId', options.sessionId, ...
        'Condition', options.condition, ...
        'Events', events, ...
        'SourceFile', string(matFilePath), ...
        'SignalUnits', options.signalUnits, ...
        'SignalScale', options.signalScale, ...
        'Metadata', metadata);
end

% ------------------------------------------------------------------------
function value = requireVariable(raw, name, filePath)
    name = char(name);
    if isempty(name) || ~isfield(raw, name)
        error('SPARQ:io:loadMat:missingVariable', ...
            'Variable "%s" was not found in %s.', name, filePath);
    end
    value = raw.(name);
end

% ------------------------------------------------------------------------
function value = optionalVariable(raw, name)
    name = char(name);
    if isempty(name)
        value = [];
    elseif ~isfield(raw, name)
        error('SPARQ:io:loadMat:missingVariable', ...
            'Optional mapped variable "%s" was not found.', name);
    else
        value = raw.(name);
    end
end
