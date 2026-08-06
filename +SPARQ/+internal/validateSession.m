function validateSession(session, params, validationScope)
% SPARQ.internal.validateSession(session, params, validationScope)
%
% Valida uma estrutura de sessão carregada antes de entregá-la ao pipeline de
% processamento. Detecta arquivos .mat malformados ou truncados logo no
% início, com uma mensagem que nomeia o campo problemático.
%
% ENTRADAS:
%   session = estrutura produzida por SPARQ.loadSession, com os campos:
%       .lfp    = matriz numérica CxN
%       .time   = vetor numérico 1xN
%       .events = vetor de tempos de eventos (INFO.ttltime)
%       .areas  = rótulos de área, um por canal
%   params  = estrutura de parâmetros (consulte defaultNoiseParameters)
%   validationScope = (opcional) 'full' para uma sessão carregada pelo fluxo
%                     legado, incluindo os eventos exigidos pela visualização;
%                     'core' para o contrato computacional sem TTLs. O padrão
%                     é 'full', preservando o comportamento existente.
%
% SAÍDAS:
%   (nenhuma) Gera 'SPARQ:validateSession:*' no primeiro problema encontrado.
%

    if nargin < 3 || isempty(validationScope)
        validationScope = 'full';
    end
    if ~ismember(validationScope, {'full', 'core'})
        error('SPARQ:validateSession:badScope', ...
            'validationScope must be ''full'' or ''core''.');
    end

    requireField(session, 'lfp',   'session');
    requireField(session, 'time',  'session');
    requireField(session, 'areas', 'session');

    if ~(isa(session.lfp, 'double') || isa(session.lfp, 'single')) || ...
            ~isreal(session.lfp) || ~ismatrix(session.lfp) || ...
            isempty(session.lfp) || any(~isfinite(session.lfp), 'all')
        error('SPARQ:validateSession:badLfp', ...
            ['session.lfp must be a non-empty finite real single/double matrix ' ...
             '(channels x samples). Use SPARQ.createSession to normalize input.']);
    end

    [nChannels, nSamples] = size(session.lfp);

    if nChannels ~= params.channels.count
        error('SPARQ:validateSession:channelCountMismatch', ...
            ['session.lfp has %d channels but params.channels.count is %d. ' ...
             'Adjust the montage in the parameters or check the recording.'], ...
            nChannels, params.channels.count);
    end

    if ~isnumeric(session.time) || ~isreal(session.time) || ...
            ~isvector(session.time) || numel(session.time) ~= nSamples || ...
            any(~isfinite(session.time))
        error('SPARQ:validateSession:timeLengthMismatch', ...
            ['session.time must be a finite real vector (%d values) matching ' ...
             'the LFP length (%d samples).'], ...
            numel(session.time), nSamples);
    end
    if nSamples < 2 || any(diff(double(session.time(:))) <= 0)
        error('SPARQ:validateSession:nonMonotonicTime', ...
            'session.time must contain at least two strictly increasing values.');
    end

    if labelCount(session.areas) < nChannels
        error('SPARQ:validateSession:areasTooShort', ...
            'session.areas has %d labels but there are %d channels.', ...
            labelCount(session.areas), nChannels);
    end

    if isfield(session, 'samplingRateHz')
        fs = session.samplingRateHz;
        if ~isnumeric(fs) || ~isreal(fs) || ~isscalar(fs) || ...
                ~isfinite(fs) || fs <= 0
            error('SPARQ:validateSession:badSamplingRate', ...
                'session.samplingRateHz must be a positive finite scalar.');
        end
    end

    if strcmp(validationScope, 'full')
        requireField(session, 'events', 'session');
        if ~isnumeric(session.events) || ~isreal(session.events) || ...
                ~isvector(session.events) || any(~isfinite(session.events))
            error('SPARQ:validateSession:badEvents', ...
                'session.events must be a finite real vector.');
        end
        neededEvents = max([params.channels.referenceEventStart, ...
                            params.channels.referenceEventEnd, nChannels]);
        if numel(session.events) < neededEvents
            error('SPARQ:validateSession:tooFewEvents', ...
                ['session.events has %d entries but the pipeline needs at least %d ' ...
                 '(per-channel markers and reference events %d..%d).'], ...
                numel(session.events), neededEvents, ...
                params.channels.referenceEventStart, params.channels.referenceEventEnd);
        end
    end
end

% ------------------------------------------------------------------------
function count = labelCount(labels)
    if ischar(labels)
        count = size(labels, 1);
    elseif isstring(labels) || iscellstr(labels) || iscategorical(labels)
        count = numel(labels);
    else
        count = 0;
    end
end

% ------------------------------------------------------------------------
function requireField(s, field, name)
    if ~isfield(s, field)
        error('SPARQ:validateSession:missingField', ...
            'Required field "%s.%s" is missing.', name, field);
    end
end
