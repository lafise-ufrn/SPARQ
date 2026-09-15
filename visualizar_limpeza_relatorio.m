%% VISUALIZAR_LIMPEZA_RELATORIO
% Script exploratorio e independente do workflow da biblioteca SPARQ.
%
% Gera somente duas figuras:
%   1) sinal original com o trecho de referencia limpa destacado em azul;
%   2) sinal concatenado depois da remocao das amostras marcadas como ruido.
%
% O script NAO executa novamente o detector e NAO altera os arquivos MAT.
% Ele usa a selecao e a noiseMask ja salvas em um resultado *_clean.mat.

%% =========================== EDITE AQUI ================================

% Resultado gerado pela SPARQ. Deixe "" para escolher em uma janela.
config.arquivoResultado = "C:\pesquisa\dados_eletro\exp_esteira_odor\outputs\rato4\SPARQ_results\rato4_aversivo_clean.mat";

% Normalmente estes dois arquivos sao encontrados automaticamente ao lado
% de um resultado legado clean_data. Preencha somente se eles foram movidos.
config.arquivoSinalOriginal = "";
config.arquivoReferenciaLimpa = "";

% Use [] para mostrar todos os canais analisados. Exemplo: [1 3 5].
config.canais = [];

% Limite aproximado de pontos desenhados por canal. A reducao afeta somente
% a figura, nunca os dados nem a concatenacao.
config.maxPontosPorCanal = 50000;

% Aparencia do trecho de referencia limpa na primeira figura.
config.corFundoReferencia = [0.45 0.72 1.00];
config.transparenciaReferencia = 0.48;
config.corLimitesReferencia = [0.35 0.48 0.60];
% As cores e o empilhamento dos sinais seguem SPARQ.viz.channels.

% Exportacao opcional para o relatorio (somente PNG em alta resolucao).
config.exportar = true;
config.pastaExportacao = "C:\pesquisa\figuras_random"; % "" cria/usa "figuras_exploratorias"
config.sobrescreverFiguras = true;
config.resolucaoPngDpi = 600;

%% ======================= FIM DA EDICAO ================================

arquivoResultado = escolherArquivoResultado(config.arquivoResultado);
dados = carregarResultado(arquivoResultado);
[sessao, leitor] = recarregarSessaoOriginal(dados, config);
limpezaLeitor = onCleanup(@() fecharLeitor(leitor));

mascaraRuido = extrairMascaraRuido(dados, size(sessao.lfp, 2));
intervaloReferencia = extrairIntervaloReferencia(dados, sessao, config);
canais = escolherCanais(config.canais, dados, size(sessao.lfp, 1));

figuraReferencia = plotarReferenciaLimpa( ...
    sessao, canais, intervaloReferencia, dados.formato, config);
figuraConcatenada = plotarSinalConcatenado( ...
    sessao, canais, mascaraRuido, dados.formato, config);

if config.exportar
    exportarFiguras(figuraReferencia, figuraConcatenada, ...
        arquivoResultado, config);
end

fprintf('\nVisualizacao concluida sem reprocessar o sinal.\n');
fprintf('Amostras originais: %d\n', numel(mascaraRuido));
fprintf('Amostras removidas como ruido: %d (%.3f%%)\n', ...
    nnz(mascaraRuido), 100 * nnz(mascaraRuido) / numel(mascaraRuido));
fprintf('Amostras mantidas na concatenacao: %d (%.3f%%)\n', ...
    nnz(~mascaraRuido), 100 * nnz(~mascaraRuido) / numel(mascaraRuido));

%% Funcoes locais

function arquivo = escolherArquivoResultado(valorConfigurado)
    if ~(ischar(valorConfigurado) || ...
            (isstring(valorConfigurado) && isscalar(valorConfigurado)))
        error('SPARQ:exploracao:arquivoResultadoInvalido', ...
            'config.arquivoResultado deve ser um texto escalar.');
    end

    arquivo = string(valorConfigurado);
    if strlength(arquivo) == 0
        [nome, pasta] = uigetfile({'*_clean.mat', 'Resultado SPARQ (*_clean.mat)'; ...
            '*.mat', 'Arquivo MAT (*.mat)'}, 'Escolha o resultado da SPARQ');
        if isequal(nome, 0)
            error('SPARQ:exploracao:selecaoCancelada', ...
                'Nenhum arquivo de resultado foi selecionado.');
        end
        arquivo = string(fullfile(pasta, nome));
    end

    if ~isfile(arquivo)
        error('SPARQ:exploracao:resultadoNaoEncontrado', ...
            'O arquivo de resultado nao foi encontrado: %s', arquivo);
    end
end

function dados = carregarResultado(arquivo)
    variaveis = string({whos('-file', arquivo).name});
    dados.arquivoResultado = string(arquivo);
    if ismember("SPARQ_result", variaveis)
        conteudo = load(arquivo, 'SPARQ_result');
        if ~isstruct(conteudo.SPARQ_result) || ...
                ~isscalar(conteudo.SPARQ_result)
            error('SPARQ:exploracao:resultadoInvalido', ...
                'SPARQ_result deve ser uma estrutura escalar.');
        end
        dados.formato = "SPARQ_result";
        dados.conteudo = conteudo.SPARQ_result;
    elseif ismember("clean_data", variaveis)
        conteudo = load(arquivo, 'clean_data');
        if ~isstruct(conteudo.clean_data) || ~isscalar(conteudo.clean_data)
            error('SPARQ:exploracao:resultadoInvalido', ...
                'clean_data deve ser uma estrutura escalar.');
        end
        dados.formato = "clean_data";
        dados.conteudo = conteudo.clean_data;
    else
        error('SPARQ:exploracao:resultadoInvalido', ...
            ['O MAT deve conter SPARQ_result (workflow generico) ou ' ...
             'clean_data (fluxo legado esteira/odor).']);
    end
end

function [sessao, leitor] = recarregarSessaoOriginal(dados, config)
    if dados.formato == "clean_data"
        arquivoFonte = localizarFonteLegada(dados.arquivoResultado, ...
            config.arquivoSinalOriginal);
        sessao = SPARQ.loadSession( ...
            char(arquivoFonte), SPARQ.profiles.esteiraOdor());
        leitor = [];
        return;
    end

    salvo = dados.conteudo;
    if ~isfield(salvo, 'provenance') || ...
            ~isfield(salvo.provenance, 'manifestRow')
        error('SPARQ:exploracao:provenienciaAusente', ...
            ['O resultado nao contem provenance.manifestRow. ' ...
             'Use um resultado completo gerado pelo workflow atual.']);
    end

    linha = salvo.provenance.manifestRow;
    camposObrigatorios = {'SourceFile', 'LoaderOptions', 'DataSelector'};
    if ~isstruct(linha) || ~isscalar(linha) || ...
            ~all(isfield(linha, camposObrigatorios))
        error('SPARQ:exploracao:manifestoInvalido', ...
            'provenance.manifestRow esta incompleto.');
    end

    arquivoFonte = string(config.arquivoSinalOriginal);
    if strlength(arquivoFonte) == 0
        arquivoFonte = string(linha.SourceFile);
    end
    if ~isfile(arquivoFonte)
        error('SPARQ:exploracao:fonteNaoEncontrada', ...
            ['O sinal original registrado na proveniencia nao foi encontrado:\n%s\n' ...
             'Mova o resultado junto com sua fonte ou atualize a proveniencia.'], ...
            arquivoFonte);
    end

    opcoes = retirarCelulaUnica(linha.LoaderOptions, 'LoaderOptions');
    seletor = retirarCelulaUnica(linha.DataSelector, 'DataSelector');
    if isfield(linha, 'SubjectId'), opcoes.subjectId = linha.SubjectId; end
    if isfield(linha, 'SessionId'), opcoes.sessionId = linha.SessionId; end
    if isfield(linha, 'Condition'), opcoes.condition = linha.Condition; end
    if isfield(linha, 'SamplingRateHz') && ...
            isnumeric(linha.SamplingRateHz) && isfinite(linha.SamplingRateHz)
        opcoes.samplingRateHz = linha.SamplingRateHz;
    end
    if isfield(linha, 'InputFormat') && strlength(string(linha.InputFormat)) > 0
        opcoes.inputFormat = linha.InputFormat;
    else
        opcoes.inputFormat = "auto";
    end

    leitor = SPARQ.io.SourceReader(arquivoFonte, opcoes);
    try
        sessao = leitor.load(seletor, opcoes);
    catch excecao
        leitor.close();
        rethrow(excecao);
    end
end

function arquivoFonte = localizarFonteLegada(arquivoResultado, valorConfigurado)
    arquivoFonte = string(valorConfigurado);
    if strlength(arquivoFonte) == 0
        [pasta, nome, extensao] = fileparts(arquivoResultado);
        nomeFonte = regexprep(string(nome), "_clean$", "");
        arquivoFonte = string(fullfile(pasta, nomeFonte + string(extensao)));
    end
    if ~isfile(arquivoFonte)
        error('SPARQ:exploracao:fonteNaoEncontrada', ...
            ['O sinal bruto correspondente ao clean_data nao foi encontrado:\n%s\n' ...
             'Informe o caminho em config.arquivoSinalOriginal.'], ...
            char(arquivoFonte));
    end
end

function valor = retirarCelulaUnica(valor, nome)
    if iscell(valor) && isscalar(valor)
        valor = valor{1};
    end
    if ~isstruct(valor) || ~isscalar(valor)
        error('SPARQ:exploracao:campoManifestoInvalido', ...
            'O campo %s deve conter uma estrutura escalar.', nome);
    end
end

function fecharLeitor(leitor)
    if ~isempty(leitor) && isvalid(leitor)
        leitor.close();
    end
end

function mascara = extrairMascaraRuido(dados, numeroAmostras)
    if dados.formato == "clean_data"
        sinaisLimpos = dados.conteudo;
    else
        salvo = dados.conteudo;
        if ~isfield(salvo, 'result') || ...
                ~isfield(salvo.result, 'cleanSignals')
            error('SPARQ:exploracao:mascaraAusente', ...
                'O resultado nao contem result.cleanSignals.');
        end
        sinaisLimpos = salvo.result.cleanSignals;
    end
    if ~isfield(sinaisLimpos, 'noiseMask')
        error('SPARQ:exploracao:mascaraAusente', ...
            'O resultado nao contem noiseMask.');
    end
    mascara = sinaisLimpos.noiseMask;
    if ~(islogical(mascara) || isnumeric(mascara)) || ...
            ~isvector(mascara) || numel(mascara) ~= numeroAmostras || ...
            (isnumeric(mascara) && any(~ismember(mascara, [0 1])))
        error('SPARQ:exploracao:mascaraInvalida', ...
            'noiseMask deve conter um valor logico para cada amostra original.');
    end
    mascara = logical(mascara(:).');
    if nnz(~mascara) < 2
        error('SPARQ:exploracao:nenhumaAmostraLimpa', ...
            ['Menos de duas amostras permaneceram limpas; nao ha sinal ' ...
             'suficiente para construir a figura concatenada.']);
    end
end

function intervalo = extrairIntervaloReferencia(dados, sessao, config)
    if dados.formato == "clean_data"
        intervalo = carregarReferenciaLegada(dados.arquivoResultado, ...
            config.arquivoReferenciaLimpa);
        indices = find(sessao.time > intervalo(1) & sessao.time < intervalo(2));
        if numel(indices) < 2
            error('SPARQ:exploracao:referenciaInvalida', ...
                'A referencia limpa nao corresponde ao eixo do sinal bruto.');
        end
        tempoFisico = eixoTemporalFisico(sessao, dados.formato);
        intervalo = tempoFisico([indices(1), indices(end)]);
        return;
    end

    salvo = dados.conteudo;
    intervalo = [];
    if isfield(salvo, 'result') && ...
            isfield(salvo.result, 'referenceInfo') && ...
            isfield(salvo.result.referenceInfo, 'interval')
        intervalo = salvo.result.referenceInfo.interval;
    elseif isfield(salvo, 'provenance') && ...
            isfield(salvo.provenance, 'reference') && ...
            isfield(salvo.provenance.reference, 'interval')
        intervalo = salvo.provenance.reference.interval;
    end

    if ~isnumeric(intervalo) || ~isreal(intervalo) || ...
            numel(intervalo) ~= 2 || any(~isfinite(intervalo))
        error('SPARQ:exploracao:referenciaAusente', ...
            'O intervalo da referencia limpa nao foi encontrado no resultado.');
    end
    intervalo = sort(double(intervalo(:).'));
    if intervalo(1) < sessao.time(1) || intervalo(2) > sessao.time(end) || ...
            intervalo(1) >= intervalo(2)
        error('SPARQ:exploracao:referenciaInvalida', ...
            'O intervalo da referencia limpa esta fora do eixo temporal.');
    end
end

function intervalo = carregarReferenciaLegada(arquivoResultado, valorConfigurado)
    arquivoReferencia = string(valorConfigurado);
    if strlength(arquivoReferencia) == 0
        [pasta, nome] = fileparts(arquivoResultado);
        nomeBase = regexprep(string(nome), "_clean$", "");
        arquivoReferencia = string(fullfile( ...
            pasta, nomeBase + "_clean_reference.mat"));
    end
    if ~isfile(arquivoReferencia)
        error('SPARQ:exploracao:referenciaNaoEncontrada', ...
            ['O cache da referencia limpa nao foi encontrado:\n%s\n' ...
             'Informe o caminho em config.arquivoReferenciaLimpa.'], ...
            char(arquivoReferencia));
    end
    conteudo = load(arquivoReferencia, 'referenceSeconds');
    if ~isfield(conteudo, 'referenceSeconds')
        error('SPARQ:exploracao:referenciaAusente', ...
            'O cache nao contem a variavel referenceSeconds.');
    end
    intervalo = conteudo.referenceSeconds;
    if ~isnumeric(intervalo) || ~isreal(intervalo) || ...
            numel(intervalo) ~= 2 || any(~isfinite(intervalo))
        error('SPARQ:exploracao:referenciaInvalida', ...
            'referenceSeconds deve conter dois valores finitos.');
    end
    intervalo = sort(double(intervalo(:).'));
end

function canais = escolherCanais(solicitados, dados, totalCanais)
    if isempty(solicitados)
        canais = 1:totalCanais;
        salvo = dados.conteudo;
        if dados.formato == "clean_data" && isfield(salvo, 'channels')
            canais = salvo.channels;
        elseif isfield(salvo, 'parameters') && ...
                isfield(salvo.parameters, 'channels') && ...
                isfield(salvo.parameters.channels, 'excluded')
            canais = setdiff(canais, salvo.parameters.channels.excluded);
        elseif isfield(salvo, 'result') && ...
                isfield(salvo.result, 'cleanSignals') && ...
                isfield(salvo.result.cleanSignals, 'channels')
            canais = salvo.result.cleanSignals.channels;
        end
    else
        canais = solicitados;
    end

    if ~isnumeric(canais) || ~isreal(canais) || ~isvector(canais) || ...
            isempty(canais) || any(~isfinite(canais)) || ...
            any(canais ~= round(canais)) || any(canais < 1) || ...
            any(canais > totalCanais) || numel(unique(canais)) ~= numel(canais)
        error('SPARQ:exploracao:canaisInvalidos', ...
            'config.canais deve conter indices unicos entre 1 e %d.', totalCanais);
    end
    canais = canais(:).';
end

function figura = plotarReferenciaLimpa( ...
        sessao, canais, intervalo, formato, config)
    validarAparencia(config);
    sessaoVisual = prepararSessaoVisual(sessao, formato, true);
    params = parametrosVisualizacao(sessaoVisual, canais, formato);
    figura = figure('Color', 'w', 'Name', ...
        'SPARQ - referencia limpa selecionada', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.05 0.08 0.90 0.82]);
    eixo = axes('Parent', figura);
    geometria = SPARQ.internal.plotLayout(sessaoVisual, params);
    fundo = patch(eixo, ...
        [intervalo(1) intervalo(2) intervalo(2) intervalo(1)], ...
        [geometria.yBottom geometria.yBottom ...
         geometria.yTop geometria.yTop], ...
        config.corFundoReferencia, 'FaceAlpha', ...
        config.transparenciaReferencia, 'EdgeColor', 'none', ...
        'DisplayName', 'Trecho limpo selecionado');
    eixo.ColorOrderIndex = 1;
    SPARQ.viz.channels(sessaoVisual, params, eixo, ...
        'MaxDisplayPoints', config.maxPontosPorCanal);
    aplicarRotulosCanais(eixo, sessaoVisual, canais, params);
    uistack(fundo, 'bottom');
    xline(eixo, intervalo(1), '--', ...
        'Color', config.corLimitesReferencia, 'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
    xline(eixo, intervalo(2), '--', ...
        'Color', config.corLimitesReferencia, 'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
    eixo.Layer = 'top';
    legend(eixo, fundo, 'Location', 'best');
end

function figura = plotarSinalConcatenado( ...
        sessao, canais, mascaraRuido, formato, config)
    indicesLimpos = find(~mascaraRuido);
    sessaoVisual = prepararSessaoVisual(sessao, formato, true);
    sessaoVisual.lfp = sessao.lfp(:, indicesLimpos);
    sessaoVisual.time = ...
        (0:numel(indicesLimpos) - 1) / taxaAmostragem(sessao);
    params = parametrosVisualizacao(sessaoVisual, canais, formato);
    figura = figure('Color', 'w', 'Name', ...
        'SPARQ - sinal concatenado sem ruido', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.05 0.08 0.90 0.82]);
    eixo = axes('Parent', figura);
    eixo.ColorOrderIndex = 1;
    SPARQ.viz.channels(sessaoVisual, params, eixo, ...
        'MaxDisplayPoints', config.maxPontosPorCanal);
    aplicarRotulosCanais(eixo, sessaoVisual, canais, params);
    title(eixo, sprintf('%s - Sinal concatenado sem ruido', ...
        SPARQ.internal.sessionTitle(sessaoVisual, params)));
    xlabel(eixo, 'Tempo acumulado apos concatenacao (s)');
end

function tempo = eixoTemporalFisico(sessao, formato)
    if formato == "clean_data"
        if ~isfield(sessao, 'info') || ...
                ~isfield(sessao.info, 'srate')
            error('SPARQ:exploracao:tempoFisicoAusente', ...
                'A sessao legada nao contem INFO.srate.');
        end
        tempo = (0:size(sessao.lfp, 2) - 1) / double(sessao.info.srate);
    else
        tempo = double(sessao.time(:).');
    end
end

function sessaoVisual = prepararSessaoVisual(sessao, formato, removerEventos)
    sessaoVisual = sessao;
    if formato == "clean_data"
        sessaoVisual.time = eixoTemporalFisico(sessao, formato);
        if isfield(sessaoVisual, 'events') && ...
                isfield(sessaoVisual, 'samplingRate')
            sessaoVisual.events = ...
                double(sessaoVisual.events) / sessaoVisual.samplingRate;
        end
    end
    if removerEventos && isfield(sessaoVisual, 'events')
        sessaoVisual = rmfield(sessaoVisual, 'events');
    end
end

function params = parametrosVisualizacao(sessao, canais, formato)
    if formato == "clean_data" || formato == "concatenado"
        params = SPARQ.profiles.esteiraOdor();
    else
        params = SPARQ.processingOptions(size(sessao.lfp, 1));
    end
    params.channels.count = size(sessao.lfp, 1);
    params.channels.excluded = setdiff(1:size(sessao.lfp, 1), canais);
    params.plot.enabled = true;
end

function aplicarRotulosCanais(eixo, sessao, canais, params)
    geometria = SPARQ.internal.plotLayout(sessao, params);
    rotulos = strings(numel(canais), 1);
    for indice = 1:numel(canais)
        rotulos(indice) = sprintf('ch%d', canais(indice));
    end
    set(eixo, 'YTick', geometria.yTicks, ...
        'YTickLabel', cellstr(rotulos), 'YDir', 'reverse');
    ylim(eixo, [geometria.yBottom, geometria.yTop]);
    ylabel(eixo, 'Channel');
end

function taxa = taxaAmostragem(sessao)
    if isfield(sessao, 'info') && isfield(sessao.info, 'srate')
        taxa = sessao.info.srate;
    elseif isfield(sessao, 'samplingRateHz')
        taxa = sessao.samplingRateHz;
    elseif isfield(sessao, 'samplingRate')
        taxa = sessao.samplingRate;
    else
        error('SPARQ:exploracao:taxaAusente', ...
            'A sessao nao contem samplingRateHz nem samplingRate.');
    end
    if ~isnumeric(taxa) || ~isscalar(taxa) || ~isfinite(taxa) || taxa <= 0
        error('SPARQ:exploracao:taxaInvalida', ...
            'A taxa de amostragem deve ser um escalar positivo e finito.');
    end
end

function validarAparencia(config)
    cores = {config.corFundoReferencia, config.corLimitesReferencia};
    if any(cellfun(@(cor) ~isnumeric(cor) || numel(cor) ~= 3 || ...
            any(~isfinite(cor)) || any(cor < 0) || any(cor > 1), cores))
        error('SPARQ:exploracao:corInvalida', ...
            'As cores devem ser vetores RGB com valores entre 0 e 1.');
    end
    if ~isnumeric(config.transparenciaReferencia) || ...
            ~isscalar(config.transparenciaReferencia) || ...
            config.transparenciaReferencia < 0 || ...
            config.transparenciaReferencia > 1
        error('SPARQ:exploracao:transparenciaInvalida', ...
            'config.transparenciaReferencia deve estar entre 0 e 1.');
    end
    maxPontos = config.maxPontosPorCanal;
    if ~isnumeric(maxPontos) || ~isscalar(maxPontos) || ...
            ~isfinite(maxPontos) || maxPontos < 100 || ...
            maxPontos ~= round(maxPontos)
        error('SPARQ:exploracao:maxPontosInvalido', ...
            'config.maxPontosPorCanal deve ser um inteiro >= 100.');
    end
end

function exportarFiguras(figuraReferencia, figuraConcatenada, ...
        arquivoResultado, config)
    pasta = string(config.pastaExportacao);
    if strlength(pasta) == 0
        pasta = string(fullfile(fileparts(arquivoResultado), ...
            'figuras_exploratorias'));
    end
    if ~isfolder(pasta)
        [criada, mensagem] = mkdir(pasta);
        if ~criada
            error('SPARQ:exploracao:pastaNaoCriada', '%s', mensagem);
        end
    end

    [~, nomeResultado] = fileparts(arquivoResultado);
    nomes = [nomeResultado + "_referencia_limpa", ...
        nomeResultado + "_sinal_concatenado"];
    figuras = [figuraReferencia, figuraConcatenada];
    resolucao = config.resolucaoPngDpi;
    if ~isnumeric(resolucao) || ~isscalar(resolucao) || ...
            ~isfinite(resolucao) || resolucao < 72 || ...
            resolucao ~= round(resolucao)
        error('SPARQ:exploracao:resolucaoInvalida', ...
            'config.resolucaoPngDpi deve ser um inteiro maior ou igual a 72.');
    end

    destinos = strings(2, 1);
    for indice = 1:2
        destinos(indice) = fullfile(pasta, nomes(indice) + ".png");
    end

    for indice = 1:2
        exportarPngSePermitido(figuras(indice), destinos(indice), ...
            config.sobrescreverFiguras, resolucao);
    end
    fprintf('Figuras exportadas em: %s\n', pasta);
end

function exportarPngSePermitido(figura, destino, sobrescrever, resolucao)
    if isfile(destino) && ~sobrescrever
        fprintf('Arquivo existente preservado: %s\n', destino);
        return;
    end
    exportgraphics(figura, destino, 'Resolution', resolucao);
    fprintf('Figura salva: %s\n', destino);
end
