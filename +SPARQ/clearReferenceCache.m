function deletedFiles = clearReferenceCache(folderPath, params)
% deletedFiles = SPARQ.clearReferenceCache(folderPath, params)
%
% Exclui toda seleção de referência limpa em cache sob a raiz de dados de um
% experimento, para que a próxima execução peça novamente a seleção
% interativa, em vez de reutilizar silenciosamente uma escolha anterior.
%
% POR QUE ISSO EXISTE: SPARQ.selectCleanReference armazena cada escolha
% interativa em um arquivo "<subjectId>_<condition>_clean_reference.mat" dentro
% da propria pasta da sessao (consulte params.io.referenceCacheName),
% especificamente para que uma execucao em lote nao seja interrompida
% toda vez que for executada novamente.
% Esse cache vive no DISCO, nao no workspace do MATLAB;
% executar `clear` e rodar cleanExperiment/runNoiseCleaning novamente NÃO o
% redefine. Qualquer combinação sujeito/condição marcada anteriormente
% continua sendo processada silenciosamente usando a escolha antiga ("como se
% já estivesse marcada"), enquanto somente sessões nunca marcadas solicitam
% interação. Esta função é a maneira explícita e deliberada de desfazer isso e
% forçar um início realmente novo.
%
% ENTRADAS:
%   folderPath = caminho absoluto para a raiz de dados do experimento (o mesmo
%                passado a cleanExperiment/runNoiseCleaning)
%   params     = (opcional) estrutura de parâmetros; somente
%                params.io.sessionFolderPattern e
%                params.io.referenceCacheName são lidos. Os padrões são
%                usados quando omitido.
%
% SAÍDAS:
%   deletedFiles = matriz de células com os caminhos absolutos excluídos
%
% OBSERVAÇÕES:
%   Isto exclui PERMANENTEMENTE as selecoes de referencia em cache (arquivos
%   contendo apenas os dois timestamps clicados em segundos); NAO toca
%   nas gravacoes brutas nem em nenhuma saida de sinal limpo ("_clean.mat") ja
%   salva. A proxima execucao de cleanExperiment/runSession solicitara uma
%   nova escolha interativa para cada sessao encontrada em folderPath.

    if nargin < 2 || isempty(params)
        params = SPARQ.defaultOptions();
    end

    sessionEntries = dir(fullfile(folderPath, params.io.sessionFolderPattern));
    sessionEntries = sessionEntries([sessionEntries.isdir]);

    deletedFiles = {};
    for s = 1:numel(sessionEntries)
        sessionFolder = fullfile(folderPath, sessionEntries(s).name);
        pattern = fullfile(sessionFolder, ['*_' char(params.io.referenceCacheName)]);
        matches = dir(pattern);

        for m = 1:numel(matches)
            filePath = fullfile(sessionFolder, matches(m).name);
            if SPARQ.internal.isReferenceCacheFile(filePath)
                delete(filePath);
                deletedFiles{end + 1} = filePath; %#ok<AGROW>
            end
        end
    end
end

