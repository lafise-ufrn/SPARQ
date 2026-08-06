function result = processSession(session, referenceIdx, params)
% result = SPARQ.processSession(session, referenceIdx, params)
%
% Executa o NÚCLEO de limpeza de ruído para uma sessão já carregada: detecta
% segmentos ruidosos e então constrói a máscara lógica obrigatória de ruído e
% quaisquer representações opcionais de sinal limpo solicitadas em
% params.output. Esta função não cria figuras nem faz E/S em disco. Ela recebe
% os índices produzidos pela seleção manual e mantém o cálculo separado da
% interface. Plotagem e persistência são etapas separadas; consulte SPARQ.viz.* e
% SPARQ.saveCleanSignals.
%
% ENTRADAS:
%   session      = estrutura canônica de SPARQ.createSession ou de um loader
%   referenceIdx = índices de amostra do trecho de referência limpa escolhido
%                  manualmente por SPARQ.selectCleanReference ou
%                  SPARQ.reference.selectInteractive
%   params       = estrutura de parâmetros (consulte defaultNoiseParameters)
%
% SAÍDAS:
%   result = estrutura com os campos:
%       .subjectId      = identidade canonica do sujeito
%       .ratId          = alias legado de .subjectId
%       .condition      = session.condition
%       .sourceFile     = session.sourceFile
%       .referenceIdx   = índices de referência usados (ecoados de volta)
%       .noise          = estrutura de SPARQ.internal.detectNoiseWindows
%                         (.windows, .mask, .percentSaved, .percentNoise,
%                          .channelMean, .channelStd)
%       .cleanSignals   = estrutura de SPARQ.internal.buildCleanSignals
%                         cujo primeiro campo é SEMPRE:
%                           .noiseMask = lógico 1xN (0 limpo, 1 ruído)
%                         Campos de sinal opcionais, controlados por params.output:
%                           .concat    = incluído por .includeConcat
%                           .nan       = incluído por .includeNaN
%                         seguidos pelos metadados de tempo/canal de suporte
%       Inclui ainda os metadados canônicos opcionais .sessionId,
%       .samplingRateHz, .signalUnits e .timeUnits.
%
% NOTAS:
%   - Os parâmetros são validados aqui (uma vez por sessão), e não dentro das
%     funções do algoritmo, para que um parâmetro inválido seja reportado com
%     o contexto completo da sessão (qual sujeito/condição o acionou).

    SPARQ.internal.validateParameters(params);
    % O nucleo nao depende de eventos TTL. A validacao completa, incluindo os
    % requisitos legados de eventos usados pela interface grafica, permanece
    % em loadSession; aqui validamos somente o contrato computacional.
    SPARQ.internal.validateSession(session, params, 'core');

    if ~isnumeric(referenceIdx) || ~isreal(referenceIdx) || ...
            ~isvector(referenceIdx) || numel(referenceIdx) < 2 || ...
            any(~isfinite(referenceIdx)) || ...
            any(referenceIdx ~= round(referenceIdx)) || ...
            any(referenceIdx < 1) || any(referenceIdx > size(session.lfp, 2)) || ...
            any(diff(referenceIdx(:)) <= 0)
        error('SPARQ:processSession:badReference', ...
            ['referenceIdx must contain at least two unique, increasing integer ' ...
             'indices within the session.']);
    end

    noise = SPARQ.internal.detectNoiseWindows( ...
        session.time, session.lfp, referenceIdx, params);

    cleanSignals = SPARQ.internal.buildCleanSignals( ...
        session.time, session.lfp, noise.windows, session.areas, params);

    subjectId = sessionSubjectId(session);
    result.subjectId     = subjectId;
    if isfield(session, 'ratId')
        result.ratId = session.ratId; % preserve the legacy value and type
    else
        result.ratId = subjectId; % deprecated compatibility alias
    end
    result.condition     = session.condition;
    result.sourceFile   = session.sourceFile;
    result.referenceIdx = referenceIdx;
    result.noise        = noise;
    result.cleanSignals = cleanSignals;

    % Metadados canonicos sao aditivos e nao alteram o contrato legado nem as
    % representacoes numericas congeladas pelos golden tests.
    canonicalFields = {'sessionId', 'samplingRateHz', ...
        'signalUnits', 'timeUnits'};
    for i = 1:numel(canonicalFields)
        field = canonicalFields{i};
        if isfield(session, field)
            result.(field) = session.(field);
        end
    end

    % Ambos os caminhos derivam das mesmas janelas detectadas.
    if ~isequal(result.cleanSignals.noiseMask, result.noise.mask)
        error('SPARQ:processSession:maskMismatch', ...
            'The primary output noiseMask does not match the detector mask.');
    end
end

% ------------------------------------------------------------------------
function subjectId = sessionSubjectId(session)
    if isfield(session, 'subjectId') && ...
            strlength(string(session.subjectId)) > 0
        subjectId = string(session.subjectId);
    elseif isfield(session, 'ratId')
        subjectId = string(session.ratId);
    else
        subjectId = "";
    end
end
