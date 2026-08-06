function session = createSession(lfp, samplingRateHz, varargin)
% session = SPARQ.createSession(lfp, samplingRateHz, Name, Value, ...)
%
% Constroi uma sessao canonica de LFP diretamente a partir de uma matriz,
% sem depender de nomes de arquivos, pastas por animal, variaveis LFP/INFO,
% especie ou condicao experimental. Esta e a fronteira recomendada para novos
% carregadores e para laboratorios que ja possuem os dados em memoria.
%
% ENTRADAS:
%   lfp            = matriz numerica real, nao vazia. Por padrao, as linhas sao
%                    canais e as colunas sao amostras. Entradas inteiras sao
%                    convertidas para double para que representacoes com NaN
%                    sejam semanticamente corretas.
%   samplingRateHz = taxa de amostragem positiva e finita, em hertz
%
% PARES NOME-VALOR:
%   'DataOrientation' = "channels-by-samples" (padrao) ou
%                       "samples-by-channels"
%   'Time'            = vetor de timestamps, em segundos. Quando omitido,
%                       usa (0:N-1)/samplingRateHz. Deve ser estritamente
%                       crescente, regular e consistente com samplingRateHz.
%   'ChannelLabels'   = rotulos, um por canal. O padrao e ch1, ch2, ...
%   'SubjectId'       = identificador generico do sujeito/preparacao
%   'SessionId'       = identificador generico da sessao
%   'Condition'       = condicao experimental opcional
%   'Events'          = tempos de eventos opcionais, em segundos
%   'SourceFile'      = caminho ou identificador de origem opcional
%   'SignalUnits'     = unidade fisica do LFP; padrao "arbitrary"
%   'SignalScale'     = fator finito aplicado ao sinal; padrao 1
%   'Metadata'        = struct escalar com metadados adicionais
%
% SAIDAS:
%   session = struct canonica com:
%       .lfp, .time, .samplingRateHz, .channelLabels, .subjectId,
%       .sessionId, .condition, .events, .sourceFile, .signalUnits,
%       .timeUnits e .metadata
%     Para compatibilidade temporaria com a API existente, tambem inclui os
%     aliases .samplingRate e .areas. .ratId e um alias legado de .subjectId.
%
% EXEMPLO:
%   session = SPARQ.createSession(eegLfp, 1000, ...
%       'SubjectId', "mouse-07", 'SignalUnits', "uV");
%
% OBSERVAÇÕES:
%   - A funcao normaliza apenas representacao, orientacao, escala e metadados;
%     nao filtra, reamostra nem rereferencia o sinal.
%   - O detector atual assume amostragem regular.

    validateLfp(lfp);
    validatePositiveScalar(samplingRateHz, 'samplingRateHz');

    parser = inputParser();
    parser.FunctionName = 'SPARQ.createSession';
    addParameter(parser, 'DataOrientation', "channels-by-samples");
    addParameter(parser, 'Time', []);
    addParameter(parser, 'ChannelLabels', []);
    addParameter(parser, 'SubjectId', "");
    addParameter(parser, 'SessionId', "");
    addParameter(parser, 'Condition', "");
    addParameter(parser, 'Events', []);
    addParameter(parser, 'SourceFile', "");
    addParameter(parser, 'SignalUnits', "arbitrary");
    addParameter(parser, 'SignalScale', 1);
    addParameter(parser, 'Metadata', struct());
    parse(parser, varargin{:});
    options = parser.Results;

    orientation = normalizeTextScalar(options.DataOrientation, 'DataOrientation');
    if orientation == "samples-by-channels"
        lfp = lfp.';
    elseif orientation ~= "channels-by-samples"
        error('SPARQ:createSession:badOrientation', ...
            ['DataOrientation must be "channels-by-samples" or ' ...
             '"samples-by-channels".']);
    end

    validateScale(options.SignalScale);
    originalClass = string(class(lfp));
    if isinteger(lfp)
        lfp = double(lfp);
    end
    lfp = lfp .* cast(options.SignalScale, 'like', lfp);

    if any(~isfinite(lfp), 'all')
        error('SPARQ:createSession:nonFiniteLfp', ...
            'lfp must contain only finite values.');
    end

    [nChannels, nSamples] = size(lfp);
    time = normalizeTime(options.Time, nSamples, samplingRateHz);
    channelLabels = normalizeChannelLabels(options.ChannelLabels, nChannels);
    events = normalizeEvents(options.Events);

    if ~isstruct(options.Metadata) || ~isscalar(options.Metadata)
        error('SPARQ:createSession:badMetadata', ...
            'Metadata must be a scalar struct.');
    end

    subjectId = normalizeTextScalar(options.SubjectId, 'SubjectId');
    sessionId = normalizeTextScalar(options.SessionId, 'SessionId');
    condition = normalizeTextScalar(options.Condition, 'Condition');
    sourceFile = normalizeTextScalar(options.SourceFile, 'SourceFile');
    signalUnits = normalizeTextScalar(options.SignalUnits, 'SignalUnits');

    session.lfp = lfp;
    session.time = time;
    session.samplingRateHz = samplingRateHz;
    session.channelLabels = channelLabels;
    session.subjectId = subjectId;
    session.sessionId = sessionId;
    session.condition = condition;
    session.events = events;
    session.sourceFile = sourceFile;
    session.signalUnits = signalUnits;
    session.timeUnits = "seconds";
    session.metadata = options.Metadata;
    session.metadata.originalSignalClass = originalClass;
    session.metadata.signalScaleApplied = options.SignalScale;

    % Aliases legados. Devem permanecer simples espelhos do contrato canonico.
    session.samplingRate = samplingRateHz;
    session.areas = channelLabels;
    session.ratId = subjectId; % deprecated compatibility alias
end

% ------------------------------------------------------------------------
function validateLfp(lfp)
    if ~isnumeric(lfp) || ~isreal(lfp) || ~ismatrix(lfp) || isempty(lfp)
        error('SPARQ:createSession:badLfp', ...
            'lfp must be a non-empty real numeric matrix.');
    end
end

% ------------------------------------------------------------------------
function validatePositiveScalar(value, name)
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
            ~isfinite(value) || value <= 0
        error('SPARQ:createSession:badPositiveScalar', ...
            '%s must be a positive finite numeric scalar.', name);
    end
end

% ------------------------------------------------------------------------
function validateScale(value)
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
            ~isfinite(value) || value == 0
        error('SPARQ:createSession:badScale', ...
            'SignalScale must be a finite nonzero numeric scalar.');
    end
end

% ------------------------------------------------------------------------
function value = normalizeTextScalar(value, name)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('SPARQ:createSession:badTextScalar', ...
            '%s must be a character vector or string scalar.', name);
    end
    value = string(value);
end

% ------------------------------------------------------------------------
function time = normalizeTime(time, nSamples, samplingRateHz)
    if isempty(time)
        time = (0:nSamples - 1) / samplingRateHz;
        return;
    end

    if ~isnumeric(time) || ~isreal(time) || ~isvector(time) || ...
            numel(time) ~= nSamples || any(~isfinite(time))
        error('SPARQ:createSession:badTime', ...
            'Time must be a finite real vector with one value per sample.');
    end

    time = double(time(:).');
    timeSteps = diff(time);
    if any(timeSteps <= 0)
        error('SPARQ:createSession:nonMonotonicTime', ...
            'Time must be strictly increasing.');
    end

    expectedStep = 1 / samplingRateHz;
    tolerance = max(1e-9, expectedStep * 1e-6);
    if any(abs(timeSteps - expectedStep) > tolerance)
        error('SPARQ:createSession:inconsistentTime', ...
            ['Time must be regularly sampled and consistent with ' ...
             'samplingRateHz (expected step %.17g seconds).'], expectedStep);
    end
end

% ------------------------------------------------------------------------
function labels = normalizeChannelLabels(labels, nChannels)
    if isempty(labels)
        labels = compose("ch%d", (1:nChannels).');
        return;
    end

    if ~(isstring(labels) || iscellstr(labels) || ischar(labels))
        error('SPARQ:createSession:badChannelLabels', ...
            'ChannelLabels must be text with one label per channel.');
    end

    if ischar(labels)
        labels = string(cellstr(labels));
    else
        labels = string(labels(:));
    end
    labels = labels(:);
    if numel(labels) ~= nChannels || any(ismissing(labels))
        error('SPARQ:createSession:badChannelLabels', ...
            'ChannelLabels must contain exactly %d nonmissing labels.', nChannels);
    end
end

% ------------------------------------------------------------------------
function events = normalizeEvents(events)
    if isempty(events)
        events = zeros(1, 0);
        return;
    end
    if ~isnumeric(events) || ~isreal(events) || ~isvector(events) || ...
            any(~isfinite(events))
        error('SPARQ:createSession:badEvents', ...
            'Events must be a finite real vector of times in seconds.');
    end
    events = double(events(:).');
end
