function session = loadSession(matFilePath, params)
% session = SPARQ.loadSession(matFilePath, params)
%
% Carrega uma sessão MAT do fluxo legado esteira/odor. Esta é uma função
% de compatibilidade com o layout histórico desse experimento, não um
% carregador MAT genérico: além das variáveis LFP e INFO, ela interpreta o
% nome da pasta pai como sujeito e o sufixo do arquivo como condição.
% Para outros layouts MAT, use SPARQ.io.loadMat ou SPARQ.createSession.
%
% ENTRADAS:
%   matFilePath = caminho para um arquivo .mat de sessão, por exemplo,
%                 "...\outputs\rato4\rato4_aversivo.mat"
%   params      = estrutura do perfil legado (consulte
%                 defaultNoiseParameters). Opcional; SPARQ.defaultOptions()
%                 é usado quando omitido.
%
% SAÍDAS:
%   session = estrutura com os campos:
%       .lfp            = matriz LFP CxN; armazenamento inteiro é convertido
%                         para double
%       .time           = INFO.timevector multiplicado pela taxa selecionada
%       .samplingRate   = taxa de amostragem escolhida para esta sessão
%       .events         = tempos de eventos (INFO.ttltime)
%       .areas          = rótulos de área por canal (INFO.areas)
%       .subjectId      = id do sujeito, obtido do nome da pasta pai
%       .ratId          = alias legado de .subjectId
%       .condition      = nome da condição (por exemplo, "aversivo")
%       .conditionIndex = índice desse nome em params.conditions.names
%       .sourceFile     = matFilePath, preservado como recebido
%       .info           = estrutura INFO bruta, mantida para análises posteriores
%
% CONTRATO DO LAYOUT LEGADO:
%   - O arquivo deve existir e usar a extensão .mat.
%   - O nome da pasta pai é o id do sujeito experimental.
%   - O nome-base do arquivo termina com um valor de
%     params.conditions.names, por exemplo, "rato4_aversivo".
%   - O arquivo contém LFP e INFO; INFO contém ttltime, areas e timevector.
%   - LFP já está orientada como canais x amostras. A função não
%     transpõe, filtra, reamostra nem rereferencia o sinal.
%
% OBSERVAÇÕES:
%   - A função nunca chama cd nem altera a pasta de trabalho atual.

    if nargin < 2 || isempty(params)
        params = SPARQ.defaultOptions();
    end

    if exist(matFilePath, 'file') ~= 2
        error('SPARQ:loadSession:fileNotFound', ...
            'Session file not found: %s', matFilePath);
    end
    [~, ~, extension] = fileparts(matFilePath);
    if ~strcmpi(extension, '.mat')
        error('SPARQ:loadSession:unsupportedExtension', ...
            'Session recordings must use the .mat extension.');
    end

    raw = load(matFilePath);
    requireVar(raw, 'LFP', matFilePath);
    requireVar(raw, 'INFO', matFilePath);
    requireInfoField(raw.INFO, 'ttltime', matFilePath);
    requireInfoField(raw.INFO, 'areas', matFilePath);
    requireInfoField(raw.INFO, 'timevector', matFilePath);

    [folderPath, baseName] = fileparts(matFilePath);
    [~, subjectId] = fileparts(folderPath);

    [conditionName, conditionIndex] = inferCondition(baseName, params);

    [samplingRate, time] = SPARQ.internal.resolveSamplingRate( ...
        subjectId, raw.INFO.timevector, params);

    if isinteger(raw.LFP)
        raw.LFP = double(raw.LFP);
    end
    session.lfp            = raw.LFP;
    session.time           = time;
    session.samplingRate   = samplingRate;
    session.events         = raw.INFO.ttltime;
    session.areas          = raw.INFO.areas;
    session.subjectId      = string(subjectId);
    session.ratId          = subjectId; % deprecated compatibility alias
    session.condition      = conditionName;
    session.conditionIndex = conditionIndex;
    session.sourceFile     = matFilePath;
    session.info           = raw.INFO;

    SPARQ.internal.validateSession(session, params);
end

% ------------------------------------------------------------------------
function requireVar(raw, name, filePath)
    if ~isfield(raw, name)
        error('SPARQ:loadSession:missingVariable', ...
            'Variable "%s" not found in %s', name, filePath);
    end
end

function requireInfoField(info, field, filePath)
    if ~isstruct(info) || ~isfield(info, field)
        error('SPARQ:loadSession:missingInfoField', ...
            'INFO.%s not found in %s', field, filePath);
    end
end

function [name, idx] = inferCondition(baseName, params)
% Compara o sufixo do nome do arquivo com params.conditions.names.
    baseName = string(baseName);
    idx = NaN;
    for c = 1:numel(params.conditions.names)
        if endsWith(baseName, params.conditions.names(c))
            idx = c;
            break;
        end
    end
    if isnan(idx)
        error('SPARQ:loadSession:unknownCondition', ...
            ['Could not match "%s" to any condition in ' ...
             'params.conditions.names (%s).'], ...
            baseName, strjoin(cellstr(params.conditions.names), ', '));
    end
    name = params.conditions.names(idx);
end
