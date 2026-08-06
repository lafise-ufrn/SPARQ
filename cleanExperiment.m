function results = cleanExperiment(folderPath, params)
% results = cleanExperiment(folderPath, params)
%
% Ponto de entrada público: executa o pipeline completo de limpeza de ruído
% em cada sessão encontrada na pasta de dados de um experimento, para cada
% condição selecionada em params.conditions.process. O conjunto de pastas e a
% quantidade de sujeitos são descobertos no disco, e uma falha em uma sessão é
% registrada sem interromper o restante do lote.
%
% Tudo o que a biblioteca faz pode ser acessado por esta chamada. Um usuário
% que nunca queira ver a estrutura interna do pacote precisa apenas desta
% função (ou da ainda mais simples runNoiseCleaning, que apenas fornece
% defaultNoiseParameters).
%
% ENTRADAS:
%   folderPath = caminho absoluto para a raiz de dados do experimento. Deve
%                conter uma subpasta por animal, correspondente a
%                params.io.sessionFolderPattern (padrão "rato*"), cada uma
%                contendo um arquivo .mat por condição, nomeado como
%                "<qualquer_coisa>_<nomeDaCondicao>.mat" (ex.: "rato4_aversivo.mat").
%   params     = (opcional) estrutura de parâmetros de
%                defaultNoiseParameters(). Se omitida, os padrões do perfil
%                esteira/odor são usados.
%
% SAIDAS:
%   results = estrutura com os campos:
%       .report   = tabela com uma linha por (rato, condição) tentado:
%                   SubjectId, Condition, Status ("ok"/"failed"), PercentSaved,
%                   PercentNoise, OutputFile, ErrorMessage
%                   RatId permanece como coluna legada de compatibilidade.
%       .sessions = matriz de células com as estruturas de resultado por
%                   sessão (consulte SPARQ.processSession) para cada sessão
%                   bem-sucedida, na mesma ordem das linhas "ok" de .report
%
% EXEMPLO:
%   params  = defaultNoiseParameters();
%   results = cleanExperiment('C:\data\odor_experiment', params);
%   disp(results.report)
%
% NOTAS:
%   - Esta função exige caminhos ABSOLUTOS e nunca chama cd(); o diretório de
%     trabalho atual nunca é lido nem alterado.
%   - Quando params.plot.enabled é true, cada sessão pausa para a seleção
%     interativa da referência limpa, a menos que já exista uma seleção em
%     cache na pasta da sessão (consulte SPARQ.selectCleanReference). Para
%     processar o lote totalmente sem intervenção, preencha previamente os
%     caches de referência ou defina params.plot.enabled = false (o que exige
%     que os caches existam).
%   - Toda sessão bem-sucedida salva `clean_data.noiseMask`. As matrizes
%     opcionais `.concat` e `.nan` só são incluídas quando habilitadas por
%     params.output.includeConcat / includeNaN.

    if nargin < 2 || isempty(params)
        params = defaultNoiseParameters();
    end

    if ~(ischar(folderPath) || isstring(folderPath)) || exist(folderPath, 'dir') ~= 7
        error('cleanExperiment:folderNotFound', ...
            'folderPath must be an existing absolute directory: %s', folderPath);
    end

    SPARQ.internal.validateParameters(params);

    sessionEntries = dir(fullfile(folderPath, params.io.sessionFolderPattern));
    sessionEntries = sessionEntries([sessionEntries.isdir]);

    if isempty(sessionEntries)
        error('cleanExperiment:noSessionsFound', ...
            ['No session folders matching "%s" were found under %s. ' ...
             'Check params.io.sessionFolderPattern and the folder path.'], ...
            params.io.sessionFolderPattern, folderPath);
    end

    reportRows = struct('SubjectId', {}, 'RatId', {}, 'Condition', {}, 'Status', {}, ...
        'PercentSaved', {}, 'PercentNoise', {}, 'OutputFile', {}, 'ErrorMessage', {});
    sessionResults = {};

    for s = 1:numel(sessionEntries)
        subjectId = sessionEntries(s).name;
        sessionFolder = fullfile(folderPath, subjectId);

        for conditionIdx = params.conditions.process
            conditionName = params.conditions.names(conditionIdx);

            [matFilePath, findError] = findConditionFile(sessionFolder, conditionName);

            row.SubjectId    = subjectId;
            row.RatId        = subjectId; % deprecated compatibility column
            row.Condition    = char(conditionName);
            row.PercentSaved = NaN;
            row.PercentNoise = NaN;
            row.OutputFile   = '';
            row.ErrorMessage = '';

            if ~isempty(findError)
                row.Status = 'failed';
                row.ErrorMessage = findError;
                reportRows(end + 1) = row; %#ok<AGROW>
                continue;
            end

            try
                result = SPARQ.runSession(matFilePath, sessionFolder, params);

                row.Status       = 'ok';
                row.PercentSaved = result.noise.percentSaved;
                row.PercentNoise = result.noise.percentNoise;
                row.OutputFile   = fullfile(sessionFolder, ...
                    sprintf('%s_%s%s.mat', subjectId, conditionName, params.io.cleanSuffix));

                sessionResults{end + 1} = result; %#ok<AGROW>
            catch ME
                row.Status = 'failed';
                row.ErrorMessage = ME.message;
            end

            reportRows(end + 1) = row; %#ok<AGROW>
        end
    end

    results.report   = struct2table(reportRows);
    results.sessions = sessionResults;
end

% ------------------------------------------------------------------------
function [matFilePath, errorMessage] = findConditionFile(sessionFolder, conditionName)
% Localiza o único arquivo .mat de uma condição dentro de uma pasta de sessão,
% Descobre os arquivos da condição pelo sufixo configurado.
% (dir('rato*_X.mat')), em vez de presumir um nome exato de arquivo.
    matFilePath = '';
    errorMessage = '';

    pattern = fullfile(sessionFolder, sprintf('*_%s.mat', conditionName));
    matches = dir(pattern);

    if isempty(matches)
        errorMessage = sprintf('No file matching "%s" found.', pattern);
        return;
    end
    if numel(matches) > 1
        errorMessage = sprintf('Multiple files matching "%s" found; expected exactly one.', pattern);
        return;
    end

    matFilePath = fullfile(sessionFolder, matches(1).name);
end
