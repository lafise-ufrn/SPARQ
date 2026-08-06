function outputPath = saveCleanSignals(result, outputDir, params)
% outputPath = SPARQ.saveCleanSignals(result, outputDir, params)
%
% Persiste a estrutura de saída produzida por SPARQ.processSession em um
% arquivo .mat, sob um diretório de saída absoluto e explícito. Esta é a
% ÚNICA função da biblioteca que grava no disco; ela nunca altera o diretório
% de trabalho atual nem deduz um local de salvamento.
%
% A variável salva se chama `clean_data` e o nome do arquivo segue
% "<subjectId>_<condition><cleanSuffix>.mat" (por exemplo,
% "rato4_aversivo_clean.mat"). A variável e o padrão de nome permanecem
% estáveis para compatibilidade com análises posteriores.
%
% ENTRADAS:
%   result    = estrutura de SPARQ.processSession
%   outputDir = caminho absoluto para a pasta de salvamento (criada se ainda
%               não existir)
%   params    = estrutura de parâmetros (consulte defaultNoiseParameters).
%               Campos lidos:
%       .io.cleanSuffix = sufixo acrescentado a "<subjectId>_<condition>"
%       .io.saveFormat  = sinalizador de formato passado a save() (por exemplo,
%                         "-v7.3", necessário para as grandes matrizes de sinal limpo)
%
% SAÍDAS:
%   outputPath = caminho absoluto do arquivo gravado
%
% NOTAS:
%   - Mantida deliberadamente simples: sem plotagem, sem cálculo, apenas E/S.
%     Chamadores que precisam somente do resultado em memória (por exemplo,
%     para análises posteriores na mesma sessão) podem ignorar esta função.
%   - `clean_data.noiseMask` está sempre presente (0 = não é ruído, 1 = ruído).
%     `clean_data.concat` e `clean_data.nan` só estão presentes quando
%     habilitados por params.output.includeConcat / includeNaN.

    if exist(outputDir, 'dir') ~= 7
        mkdir(outputDir);
    end

    subjectId = resultSubjectId(result);
    baseName = sprintf('%s_%s', subjectId, result.condition);
    fileName = sprintf('%s%s.mat', baseName, params.io.cleanSuffix);
    outputPath = fullfile(outputDir, fileName);

    if isfield(result, 'sourceFile') && ...
            SPARQ.internal.pathsEqual(outputPath, result.sourceFile)
        error('SPARQ:saveCleanSignals:sourceOverwriteRefused', ...
            'Refusing to overwrite the source recording: %s', outputPath);
    end
    if exist(outputPath, 'file') == 2 && ...
            ~SPARQ.internal.isCleanResultFile(outputPath)
        error('SPARQ:saveCleanSignals:unsafeOverwriteRefused', ...
            ['Refusing to overwrite an existing MAT file that is not a ' ...
             'recognized SPARQ clean result: %s'], outputPath);
    end

    clean_data = result.cleanSignals; % nome da variável corresponde ao campo salvo
    save(outputPath, 'clean_data', params.io.saveFormat);
end

% ------------------------------------------------------------------------
function subjectId = resultSubjectId(result)
    if isfield(result, 'subjectId') && strlength(string(result.subjectId)) > 0
        subjectId = string(result.subjectId);
    elseif isfield(result, 'ratId') && strlength(string(result.ratId)) > 0
        subjectId = string(result.ratId);
    else
        error('SPARQ:saveCleanSignals:missingSubjectId', ...
            'result.subjectId is required to name the output file.');
    end
end
