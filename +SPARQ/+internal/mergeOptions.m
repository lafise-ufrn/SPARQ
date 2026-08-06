function merged = mergeOptions(defaults, overrides, contextName)
% merged = SPARQ.internal.mergeOptions(defaults, overrides, contextName)
%
% Mescla recursivamente uma estrutura de `overrides` do usuário sobre uma
% estrutura de `defaults`, retornando uma estrutura de parâmetros completa.
% Qualquer campo presente em `overrides` que NÃO exista em `defaults` gera um
% erro, de modo que erros de digitação (por exemplo, `thresholdStd` escrito
% como `thresholdSTD`) falham explicitamente, em vez de serem ignorados em
% silêncio.
%
% ENTRADAS:
%   defaults    = estrutura de valores padrão (conjunto de campos autoritativo)
%   overrides   = estrutura de valores fornecidos pelo usuário (pode ser [] ou
%                 ter campos ausentes; apenas os campos fornecidos são aplicados)
%   contextName = (opcional) char/string usada para construir mensagens de erro
%                 legíveis, por exemplo, 'params'. O padrão é 'options'.
%
% SAÍDAS:
%   merged = estrutura idêntica a `defaults`, exceto onde `overrides` forneceu
%            um valor. Estruturas aninhadas são mescladas recursivamente.
%


    if nargin < 3 || isempty(contextName)
        contextName = 'options';
    end
    if isempty(overrides)
        merged = defaults;
        return;
    end
    if ~isstruct(overrides)
        error('SPARQ:mergeOptions:notStruct', ...
            '%s must be a struct.', contextName);
    end

    merged = defaults;
    overrideFields = fieldnames(overrides);
    for i = 1:numel(overrideFields)
        field = overrideFields{i};
        fieldPath = sprintf('%s.%s', contextName, field);

        if ~isfield(defaults, field)
            error('SPARQ:mergeOptions:unknownField', ...
                'Unknown parameter "%s". Check the spelling against defaultNoiseParameters.', ...
                fieldPath);
        end

        if isstruct(defaults.(field))
            % Recursa nos grupos de opções aninhados (por exemplo, params.detection).
            merged.(field) = SPARQ.internal.mergeOptions( ...
                defaults.(field), overrides.(field), fieldPath);
        else
            merged.(field) = overrides.(field);
        end
    end
end
