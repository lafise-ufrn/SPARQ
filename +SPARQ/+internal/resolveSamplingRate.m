function [samplingRate, time] = resolveSamplingRate(subjectId, timeVector, params)
% [samplingRate, time] = SPARQ.internal.resolveSamplingRate(subjectId, timeVector, params)
%
% Determina a taxa de amostragem de aquisição de uma sessão e retorna o eixo
% de tempo na escala esperada pelo restante do pipeline. Duas gerações de
% aquisição coexistem neste conjunto de dados e armazenam seu vetor de tempo
% em escalas diferentes; esta função seleciona a correta pela IDENTIDADE DA
% SESSÃO, nunca por sua posição em um laço.
%
% A identidade da sessão torna a escolha independente da ordem em que as
% pastas são descobertas. Com os padrões fornecidos, rato2 e rato3 usam a
% configuração de aquisição legada.
%
% ENTRADAS:
%   subjectId  = char/string que identifica o sujeito, isto e, o nome da pasta
%                (por exemplo, "rato4")
%   timeVector = vetor de tempo bruto armazenado no .mat (INFO.timevector)
%   params     = estrutura de parâmetros (consulte defaultNoiseParameters).
%                Campos lidos:
%       .acquisition.legacySubjectIds  = ids gravados no sistema legado
%       .acquisition.legacySamplingRate= taxa de amostragem das sessões legadas
%       .acquisition.samplingRate      = taxa de amostragem das sessões modernas
%
% SAÍDAS:
%   samplingRate = taxa de amostragem escalar selecionada para esta sessão
%   time         = timeVector .* samplingRate, na escala temporal usada pelo
%                  restante do pipeline
%

    if isfield(params.acquisition, 'legacySubjectIds')
        legacySubjectIds = params.acquisition.legacySubjectIds;
    else
        legacySubjectIds = params.acquisition.legacyRatIds; % compatibility
    end
    isLegacy = ismember(string(subjectId), string(legacySubjectIds));
    if isLegacy
        samplingRate = params.acquisition.legacySamplingRate;
    else
        samplingRate = params.acquisition.samplingRate;
    end
    time = timeVector * samplingRate;
end
