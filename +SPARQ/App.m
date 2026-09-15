classdef App < handle
% SPARQ.App  Interface grafica interativa para o fluxo generico do SPARQ.
%
% A interface apenas coordena carregamento, selecao da referencia, exibicao e
% salvamento. Toda atualizacao dos parametros chama SPARQ.processSession; o
% detector e a construcao das saidas permanecem nas funcoes cientificas da
% biblioteca.

    properties (SetAccess = private)
        UIFigure
    end

    properties (Access = private)
        DataFolderField
        FilePatternField
        InputFormatDropDown
        LfpVariableField
        SamplingRateVariableField
        SamplingRateField
        TimeVariableField
        ChannelLabelsVariableField
        OrientationDropDown
        SignalUnitsField
        SignalScaleField
        SessionListBox
        ExcludedChannelsField
        ThresholdStdField
        MinChannelsField
        MergeGapField
        SettleWindowField
        SettleToleranceField
        IncludeConcatCheckBox
        IncludeNaNCheckBox
        OverwriteCheckBox
        SelectReferenceButton
        SaveButton
        SaveAllButton
        SignalAxes
        SummaryAxes
        SummaryPanel
        PlotGrid
        StatusLabel

        Manifest = table()
        CurrentRowIndex = []
        CurrentSession = []
        CurrentParameters = []
        CurrentResult = []
        CurrentReferenceIdx = []
        CurrentReferenceSeconds = []
        ReferenceSelections
        SessionParameters
        SelectionStage = 0
        PendingReferenceStart = []
        BasePlotKey = []
        PlotOverlays = gobjects(0)
        MaxDisplayPoints = 20000
    end

    methods
        function obj = App(varargin)
            parser = inputParser();
            parser.FunctionName = 'SPARQ.App';
            addParameter(parser, 'Visible', 'on', @(x) any(strcmpi( ...
                string(x), ["on", "off"])));
            addParameter(parser, 'DataFolder', "", @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'FilePattern', "*.mat", @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'InputFormat', "auto", @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'LoaderOptions', struct(), ...
                @(x) isstruct(x) && isscalar(x));
            parse(parser, varargin{:});

            obj.ReferenceSelections = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'any');
            obj.SessionParameters = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'any');
            obj.buildInterface(char(parser.Results.Visible));
            obj.FilePatternField.Value = char(parser.Results.FilePattern);
            obj.InputFormatDropDown.Value = char(parser.Results.InputFormat);
            obj.applyLoaderOptions(parser.Results.LoaderOptions);

            dataFolder = string(parser.Results.DataFolder);
            if strlength(dataFolder) > 0
                obj.loadDataFolder(dataFolder);
            end
        end

        function delete(obj)
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.CloseRequestFcn = [];
                delete(obj.UIFigure);
            end
        end

        function loadDataFolder(obj, folder)
        % Descobre as sessoes da pasta e carrega a primeira delas.
            if ~(ischar(folder) || (isstring(folder) && isscalar(folder)))
                error('SPARQ:App:badDataFolder', ...
                    'A pasta de dados deve ser um texto escalar.');
            end
            folder = obj.absoluteFolder(folder);
            obj.DataFolderField.Value = folder;
            obj.setBusy(true, 'Procurando sessoes MAT...');
            busyCleanup = onCleanup(@() obj.setBusy(false, ''));

            outputRoot = fullfile(folder, 'SPARQ_results');
            files = SPARQ.internal.discoverInputFiles(folder, ...
                string(obj.FilePatternField.Value), outputRoot);
            if isempty(files)
                error('SPARQ:App:noInputFiles', ...
                    'Nenhum arquivo correspondente a "%s" foi encontrado.', ...
                    obj.FilePatternField.Value);
            end

            loaderOptions = obj.loaderOptionsFromControls();
            manifestParts = cell(numel(files), 1);
            errors = strings(0, 1);
            for i = 1:numel(files)
                try
                    manifestParts{i} = SPARQ.discoverSessions(files(i), ...
                        'InputFormat', string(obj.InputFormatDropDown.Value), ...
                        'LoaderOptions', loaderOptions);
                catch exception
                    errors(end + 1, 1) = string(files(i)) + ": " + ...
                        string(exception.message); %#ok<AGROW>
                end
            end
            manifestParts = manifestParts(~cellfun(@isempty, manifestParts));
            if isempty(manifestParts)
                error('SPARQ:App:noReadableSessions', ...
                    'Nenhuma sessao MAT pode ser carregada. %s', ...
                    strjoin(cellstr(errors), ' | '));
            end

            obj.Manifest = vertcat(manifestParts{:});
            obj.SessionListBox.Items = obj.sessionLabels(obj.Manifest);
            obj.SessionListBox.ItemsData = 1:height(obj.Manifest);
            obj.SessionListBox.Value = 1;
            obj.SaveAllButton.Enable = 'on';
            obj.loadSession(1);
            if isempty(errors)
                obj.setStatus(sprintf('%d sessao(oes) encontrada(s).', ...
                    height(obj.Manifest)), [0.10 0.40 0.16]);
            else
                obj.setStatus(sprintf( ...
                    '%d sessao(oes) carregada(s); %d arquivo(s) ignorado(s).', ...
                    height(obj.Manifest), numel(errors)), [0.65 0.36 0.05]);
            end
            clear busyCleanup;
        end

        function selectSession(obj, rowIndex)
        % Troca a sessao ativa sem fechar a interface.
            if ~isnumeric(rowIndex) || ~isscalar(rowIndex) || ...
                    rowIndex ~= round(rowIndex) || rowIndex < 1 || ...
                    rowIndex > height(obj.Manifest)
                error('SPARQ:App:badSessionIndex', ...
                    'O indice da sessao deve estar entre 1 e %d.', ...
                    height(obj.Manifest));
            end
            obj.SessionListBox.Value = rowIndex;
            obj.loadSession(rowIndex);
        end

        function setReferenceSeconds(obj, interval)
        % Define a referencia limpa e atualiza imediatamente a deteccao.
            obj.requireSession();
            if ~isnumeric(interval) || ~isreal(interval) || ...
                    numel(interval) ~= 2 || any(~isfinite(interval))
                error('SPARQ:App:badReference', ...
                    'A referencia deve conter dois tempos finitos.');
            end
            interval = sort(double(interval(:).'));
            time = double(obj.CurrentSession.time(:).');
            if interval(2) <= interval(1) || interval(1) < time(1) || ...
                    interval(2) > time(end)
                error('SPARQ:App:badReference', ...
                    'A referencia deve estar dentro do intervalo da sessao.');
            end
            [~, firstIndex] = min(abs(time - interval(1)));
            [~, lastIndex] = min(abs(time - interval(2)));
            if lastIndex <= firstIndex
                error('SPARQ:App:badReference', ...
                    'A referencia deve abranger ao menos duas amostras.');
            end
            obj.CurrentReferenceIdx = firstIndex:lastIndex;
            obj.CurrentReferenceSeconds = time([firstIndex lastIndex]);
            obj.ReferenceSelections(obj.currentSessionKey()) = ...
                obj.CurrentReferenceSeconds;
            obj.SelectionStage = 0;
            obj.PendingReferenceStart = [];
            obj.reprocess();
        end

        function setDetectionParameters(obj, values)
        % Atualiza programaticamente os mesmos campos usados pela GUI.
            if ~isstruct(values) || ~isscalar(values)
                error('SPARQ:App:badDetectionParameters', ...
                    'Os parametros devem ser fornecidos em uma struct escalar.');
            end
            controls.thresholdStd = obj.ThresholdStdField;
            controls.minSimultaneousChannels = obj.MinChannelsField;
            controls.mergeGapSamples = obj.MergeGapField;
            controls.settleWindowSamples = obj.SettleWindowField;
            controls.settleToleranceStd = obj.SettleToleranceField;
            names = fieldnames(values);
            for i = 1:numel(names)
                name = names{i};
                if ~isfield(controls, name)
                    error('SPARQ:App:unknownDetectionParameter', ...
                        'Parametro de deteccao desconhecido: %s', name);
                end
                controls.(name).Value = values.(name);
            end
            obj.reprocess();
        end

        function setExcludedChannels(obj, channels)
            if ~isnumeric(channels) || ~isreal(channels) || ...
                    (~isempty(channels) && (~isvector(channels) || ...
                    any(~isfinite(channels))))
                error('SPARQ:App:badExcludedChannels', ...
                    'Os canais excluidos devem formar um vetor numerico.');
            end
            obj.ExcludedChannelsField.Value = strjoin( ...
                string(channels(:).'), ' ');
            obj.reprocess();
        end

        function result = getCurrentResult(obj)
            result = obj.CurrentResult;
        end

        function params = getCurrentParameters(obj)
            params = obj.CurrentParameters;
        end

        function session = getCurrentSession(obj)
            session = obj.CurrentSession;
        end

        function mask = getDisplayedMask(obj)
        % Retorna a mascara completa usada nas marcacoes e no resumo visual.
            if isempty(obj.CurrentResult)
                mask = logical.empty(1, 0);
            else
                mask = obj.CurrentResult.cleanSignals.noiseMask;
            end
        end

        function selecting = isAwaitingReferenceSelection(obj)
        % Indica se o proximo clique no sinal define inicio/fim da referencia.
            selecting = obj.SelectionStage > 0;
        end

        function outputPath = saveCurrentResult(obj)
        % Salva somente a sessao ativa, sem escrever no arquivo de origem.
            obj.requireSession();
            if isempty(obj.CurrentResult)
                error('SPARQ:App:noResult', ...
                    'Selecione a referencia limpa antes de salvar.');
            end
            row = obj.Manifest(obj.CurrentRowIndex, :);
            outputDirectory = obj.outputDirectoryForRow(obj.CurrentRowIndex);
            row.OutputDirectory = string(outputDirectory);
            outputPath = obj.resultPathForRow(obj.CurrentRowIndex);

            provenance.manifestRow = table2struct(row);
            provenance.source = SPARQ.internal.sourceIdentity(row.SourceFile);
            provenance.reference.referenceSeconds = ...
                obj.CurrentReferenceSeconds;
            provenance.reference.referenceIdx = obj.CurrentReferenceIdx;
            provenance.reference.selectionMethod = "SPARQ.App";
            outputPath = string(SPARQ.io.saveResult( ...
                obj.CurrentResult, outputPath, obj.CurrentParameters, ...
                provenance, 'Overwrite', obj.OverwriteCheckBox.Value, ...
                'SaveFormat', obj.CurrentParameters.io.saveFormat));
            obj.drawExportOverview();
            SPARQ.internal.plotProcessingResult( ...
                obj.CurrentSession, obj.CurrentResult, obj.CurrentParameters, ...
                obj.MaxDisplayPoints);
            SPARQ.internal.savePlotImages( ...
                row, outputDirectory, obj.OverwriteCheckBox.Value);
            obj.setStatus('Resultado e graficos salvos em: ' + outputPath, ...
                [0.10 0.40 0.16]);
        end

        function outputPaths = saveAllResults(obj)
        % Salva todas as sessoes que ja possuem referencia limpa selecionada.
            if isempty(obj.Manifest)
                error('SPARQ:App:noSessions', ...
                    'Carregue as sessoes antes de salvar todos os resultados.');
            end

            missing = false(height(obj.Manifest), 1);
            for i = 1:height(obj.Manifest)
                missing(i) = ~isKey(obj.ReferenceSelections, ...
                    obj.sessionKeyForRow(obj.Manifest(i, :)));
            end
            if any(missing)
                labels = string(obj.sessionLabels(obj.Manifest(missing, :)));
                error('SPARQ:App:missingReferences', ...
                    ['Selecione uma referencia limpa em cada sessao antes ' ...
                     'de salvar todas. Faltando: %s'], strjoin(labels, ', '));
            end

            obj.assertAllDestinationsAvailable();
            originalRowIndex = obj.CurrentRowIndex;
            outputPaths = strings(height(obj.Manifest), 1);
            obj.setBusy(true, 'Salvando os resultados de todas as sessoes...');
            try
                for i = 1:height(obj.Manifest)
                    obj.loadSession(i);
                    outputPaths(i) = obj.saveCurrentResult();
                end
                obj.loadSession(originalRowIndex);
            catch exception
                if ~isempty(originalRowIndex) && ...
                        obj.CurrentRowIndex ~= originalRowIndex
                    try
                        obj.loadSession(originalRowIndex);
                    catch
                    end
                end
                obj.setBusy(false, '');
                rethrow(exception);
            end
            obj.setBusy(false, '');
            obj.setStatus(sprintf( ...
                '%d resultado(s) salvo(s) em pastas individuais.', ...
                numel(outputPaths)), [0.10 0.40 0.16]);
        end
    end

    methods (Access = private)
        function buildInterface(obj, visibility)
            obj.UIFigure = uifigure('Name', 'SPARQ - deteccao interativa', ...
                'Visible', 'off', ...
                'CloseRequestFcn', @(~, ~) delete(obj), ...
                'WindowButtonDownFcn', ...
                @(source, ~) obj.onFigureMouseDown(source));
            setappdata(obj.UIFigure, 'SPARQApp', obj);

            outer = uigridlayout(obj.UIFigure, [2 2]);
            outer.ColumnWidth = {350, '1x'};
            outer.RowHeight = {'1x', 34};
            outer.Padding = [8 8 8 8];
            outer.ColumnSpacing = 8;

            controlsPanel = uipanel(outer, 'Title', 'Dados e parametros', ...
                'Scrollable', 'on');
            controlsPanel.Layout.Row = 1;
            controlsPanel.Layout.Column = 1;
            controls = uigridlayout(controlsPanel, [31 2]);
            controls.ColumnWidth = {155, '1x'};
            controls.RowHeight = repmat({22}, 1, 31);
            controls.Padding = [8 8 8 8];
            controls.RowSpacing = 2;

            obj.addLabel(controls, 1, 'Pasta de dados');
            folderGrid = uigridlayout(controls, [1 2]);
            folderGrid.Layout.Row = 1;
            folderGrid.Layout.Column = 2;
            folderGrid.ColumnWidth = {'1x', 34};
            folderGrid.Padding = [0 0 0 0];
            obj.DataFolderField = uieditfield(folderGrid, 'text');
            uibutton(folderGrid, 'Text', '...', ...
                'ButtonPushedFcn', @(~, ~) obj.onBrowse());

            obj.FilePatternField = obj.addTextField(controls, 2, ...
                'Padrao dos arquivos', '*.mat');
            obj.InputFormatDropDown = obj.addDropDown(controls, 3, ...
                'Formato', {'auto', 'mat', 'realdata', 'longlfps'}, 'auto');
            obj.LfpVariableField = obj.addTextField(controls, 4, ...
                'Variavel do sinal', 'LFP');
            obj.SamplingRateVariableField = obj.addTextField(controls, 5, ...
                'Variavel da frequencia', '');
            obj.SamplingRateField = obj.addTextField(controls, 6, ...
                'Frequencia fixa (Hz)', '1000');
            obj.TimeVariableField = obj.addTextField(controls, 7, ...
                'Variavel de tempo', '');
            obj.ChannelLabelsVariableField = obj.addTextField(controls, 8, ...
                'Variavel de rotulos', '');
            obj.OrientationDropDown = obj.addDropDown(controls, 9, ...
                'Orientacao', {'channels-by-samples', ...
                'samples-by-channels'}, 'channels-by-samples');
            obj.SignalUnitsField = obj.addTextField(controls, 10, ...
                'Unidade do sinal', 'arbitrary');
            obj.SignalScaleField = obj.addNumericField(controls, 11, ...
                'Escala do sinal', 1, 'off');

            discoverButton = uibutton(controls, 'Text', 'Carregar sessoes', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) obj.onDiscover());
            discoverButton.Layout.Row = 12;
            discoverButton.Layout.Column = [1 2];

            obj.addLabel(controls, 13, 'Sessao');
            obj.SessionListBox = uilistbox(controls, 'Items', {'Nenhuma'}, ...
                'ValueChangedFcn', @(~, ~) obj.onSessionChanged());
            obj.SessionListBox.Layout.Row = [13 15];
            obj.SessionListBox.Layout.Column = 2;

            obj.ExcludedChannelsField = obj.addTextField(controls, 16, ...
                'Canais excluidos', '');
            obj.ExcludedChannelsField.ValueChangedFcn = ...
                @(~, ~) obj.onParameterChanged();
            obj.ThresholdStdField = obj.addNumericField(controls, 17, ...
                'Limiar (DP)', 4, 'off');
            obj.MinChannelsField = obj.addNumericField(controls, 18, ...
                'Canais simultaneos', 7, 'on');
            obj.MergeGapField = obj.addNumericField(controls, 19, ...
                'Unir intervalo (amostras)', 100, 'on');
            obj.SettleWindowField = obj.addNumericField(controls, 20, ...
                'Janela de retorno', 50, 'on');
            obj.SettleToleranceField = obj.addNumericField(controls, 21, ...
                'Tolerancia de retorno (DP)', 2, 'off');

            obj.ThresholdStdField.Tooltip = ...
                'Numero de desvios-padrao do limiar por canal.';
            obj.MinChannelsField.Tooltip = ...
                'Quantidade de canais que deve exceder o limiar ao mesmo tempo.';
            obj.MergeGapField.Tooltip = ...
                'Distancia maxima, em amostras, para unir candidatos proximos.';
            obj.SettleWindowField.Tooltip = ...
                'Janela, em amostras, usada para expandir as bordas.';
            obj.SettleToleranceField.Tooltip = ...
                'Faixa em desvios-padrao usada para encerrar a expansao.';

            parameterControls = [obj.ThresholdStdField, obj.MinChannelsField, ...
                obj.MergeGapField, obj.SettleWindowField, ...
                obj.SettleToleranceField];
            for i = 1:numel(parameterControls)
                parameterControls(i).ValueChangedFcn = ...
                    @(~, ~) obj.onParameterChanged();
            end

            obj.IncludeConcatCheckBox = uicheckbox(controls, ...
                'Text', 'Salvar sinal concatenado', 'Value', false, ...
                'ValueChangedFcn', @(~, ~) obj.onParameterChanged());
            obj.IncludeConcatCheckBox.Layout.Row = 22;
            obj.IncludeConcatCheckBox.Layout.Column = [1 2];
            obj.IncludeNaNCheckBox = uicheckbox(controls, ...
                'Text', 'Salvar sinal com NaN', 'Value', false, ...
                'ValueChangedFcn', @(~, ~) obj.onParameterChanged());
            obj.IncludeNaNCheckBox.Layout.Row = 23;
            obj.IncludeNaNCheckBox.Layout.Column = [1 2];
            obj.OverwriteCheckBox = uicheckbox(controls, ...
                'Text', 'Permitir substituir resultado SPARQ', 'Value', false);
            obj.OverwriteCheckBox.Layout.Row = 24;
            obj.OverwriteCheckBox.Layout.Column = [1 2];

            obj.SelectReferenceButton = uibutton(controls, ...
                'Text', 'Selecionar referencia no sinal', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) obj.onStartReference());
            obj.SelectReferenceButton.Layout.Row = 25;
            obj.SelectReferenceButton.Layout.Column = [1 2];
            obj.SaveButton = uibutton(controls, ...
                'Text', 'Salvar resultado desta sessao', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~, ~) obj.onSave());
            obj.SaveButton.Layout.Row = 26;
            obj.SaveButton.Layout.Column = [1 2];
            obj.SaveAllButton = uibutton(controls, ...
                'Text', 'Salvar resultados de todas as sessoes', ...
                'Enable', 'off', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) obj.onSaveAll());
            obj.SaveAllButton.Layout.Row = 27;
            obj.SaveAllButton.Layout.Column = [1 2];

            guidance = uilabel(controls, 'Text', ...
                ['1. Carregue a pasta.  2. Marque o inicio e o fim de um ' ...
                 'trecho limpo em cada sessao.  3. Altere os parametros; ' ...
                 'os graficos serao atualizados na mesma execucao.'], ...
                 'WordWrap', 'on');
            guidance.Layout.Row = [28 31];
            guidance.Layout.Column = [1 2];

            plotPanel = uipanel(outer, 'Title', 'Visualizacao interativa');
            plotPanel.Layout.Row = 1;
            plotPanel.Layout.Column = 2;
            obj.PlotGrid = uigridlayout(plotPanel, [2 2]);
            obj.PlotGrid.ColumnWidth = {'1x', '1x'};
            obj.PlotGrid.RowHeight = {'1x', 0};
            obj.PlotGrid.RowSpacing = 0;
            obj.PlotGrid.Padding = [8 8 8 8];
            obj.SignalAxes = uiaxes(obj.PlotGrid);
            obj.SignalAxes.Layout.Row = 1;
            obj.SignalAxes.Layout.Column = [1 2];
            obj.SignalAxes.Tag = 'SPARQAppSignalAxes';
            title(obj.SignalAxes, 'Carregue uma sessao');
            xlabel(obj.SignalAxes, 'Tempo (s)');
            obj.SummaryPanel = uipanel(obj.PlotGrid, ...
                'Tag', 'SPARQAppSummaryPanel', 'Visible', 'off');
            obj.SummaryPanel.Layout.Row = 2;
            obj.SummaryPanel.Layout.Column = 2;
            summaryGrid = uigridlayout(obj.SummaryPanel, [1 1]);
            summaryGrid.Padding = [0 0 0 0];
            obj.SummaryAxes = uiaxes(summaryGrid);
            obj.SummaryAxes.Tag = 'SPARQAppSummaryAxes';

            obj.StatusLabel = uilabel(outer, ...
                'Text', 'Selecione uma pasta de dados para comecar.', ...
                'FontWeight', 'bold');
            obj.StatusLabel.Layout.Row = 2;
            obj.StatusLabel.Layout.Column = [1 2];
            obj.UIFigure.WindowState = 'maximized';
            obj.UIFigure.Visible = visibility;
            if strcmpi(visibility, 'on')
                % Em algumas plataformas, o estado atribuido enquanto a
                % uifigure esta oculta so e aplicado depois que ela aparece.
                drawnow;
                obj.UIFigure.WindowState = 'maximized';
                drawnow limitrate;
            end
        end

        function addLabel(~, grid, row, textValue)
            label = uilabel(grid, 'Text', textValue);
            label.Layout.Row = row;
            label.Layout.Column = 1;
        end

        function field = addTextField(obj, grid, row, labelText, value)
            obj.addLabel(grid, row, labelText);
            field = uieditfield(grid, 'text', 'Value', value);
            field.Layout.Row = row;
            field.Layout.Column = 2;
        end

        function field = addNumericField(obj, grid, row, labelText, value, roundValue)
            obj.addLabel(grid, row, labelText);
            field = uieditfield(grid, 'numeric', 'Value', value, ...
                'Limits', [eps Inf], 'LowerLimitInclusive', 'on');
            if strcmp(roundValue, 'on')
                field.RoundFractionalValues = 'on';
            end
            field.Layout.Row = row;
            field.Layout.Column = 2;
        end

        function field = addDropDown(obj, grid, row, labelText, items, value)
            obj.addLabel(grid, row, labelText);
            field = uidropdown(grid, 'Items', items, 'Value', value);
            field.Layout.Row = row;
            field.Layout.Column = 2;
        end

        function applyLoaderOptions(obj, options)
            mappings = { ...
                'lfpVariable', obj.LfpVariableField; ...
                'samplingRateVariable', obj.SamplingRateVariableField; ...
                'timeVariable', obj.TimeVariableField; ...
                'channelLabelsVariable', obj.ChannelLabelsVariableField; ...
                'dataOrientation', obj.OrientationDropDown; ...
                'signalUnits', obj.SignalUnitsField};
            for i = 1:size(mappings, 1)
                name = mappings{i, 1};
                if isfield(options, name)
                    mappings{i, 2}.Value = char(string(options.(name)));
                end
            end
            if isfield(options, 'samplingRateHz') && ...
                    ~isempty(options.samplingRateHz)
                obj.SamplingRateField.Value = num2str(options.samplingRateHz);
            end
            if isfield(options, 'signalScale')
                obj.SignalScaleField.Value = options.signalScale;
            end
        end

        function options = loaderOptionsFromControls(obj)
            options.lfpVariable = string(obj.LfpVariableField.Value);
            options.samplingRateVariable = ...
                string(obj.SamplingRateVariableField.Value);
            fixedRate = strtrim(string(obj.SamplingRateField.Value));
            % Uma variavel explicitamente escolhida tem prioridade sobre o padrao.
            if strlength(strtrim(options.samplingRateVariable)) > 0 || ...
                    strlength(fixedRate) == 0
                options.samplingRateHz = [];
            else
                options.samplingRateHz = str2double(fixedRate);
                if ~isfinite(options.samplingRateHz) || ...
                        options.samplingRateHz <= 0
                    error('SPARQ:App:badSamplingRate', ...
                        'A frequencia fixa deve ser um numero positivo.');
                end
            end
            options.timeVariable = string(obj.TimeVariableField.Value);
            options.channelLabelsVariable = ...
                string(obj.ChannelLabelsVariableField.Value);
            options.dataOrientation = string(obj.OrientationDropDown.Value);
            options.signalUnits = string(obj.SignalUnitsField.Value);
            options.signalScale = obj.SignalScaleField.Value;
        end

        function loadSession(obj, rowIndex)
            obj.setBusy(true, 'Carregando a sessao selecionada...');
            busyCleanup = onCleanup(@() obj.setBusy(false, ''));
            row = obj.Manifest(rowIndex, :);
            loaderOptions = row.LoaderOptions{1};
            loaderOptions.subjectId = row.SubjectId;
            loaderOptions.sessionId = row.SessionId;
            loaderOptions.condition = row.Condition;
            if isfinite(row.SamplingRateHz)
                loaderOptions.samplingRateHz = row.SamplingRateHz;
            end
            requestedFormat = row.InputFormat;
            if strlength(requestedFormat) == 0
                requestedFormat = "auto";
            end
            loaderOptions.inputFormat = requestedFormat;
            reader = SPARQ.io.SourceReader(row.SourceFile, loaderOptions);
            readerCleanup = onCleanup(@() reader.close());
            session = reader.load(row.DataSelector{1}, loaderOptions);

            obj.CurrentRowIndex = rowIndex;
            obj.CurrentSession = session;
            obj.BasePlotKey = [];
            obj.CurrentResult = [];
            obj.CurrentReferenceIdx = [];
            obj.CurrentReferenceSeconds = [];
            obj.SelectionStage = 0;
            obj.PendingReferenceStart = [];

            key = obj.currentSessionKey();
            if isKey(obj.SessionParameters, key)
                obj.applySessionParameters(obj.SessionParameters(key));
            else
                defaults = SPARQ.processingOptions(size(session.lfp, 1));
                obj.ThresholdStdField.Value = defaults.detection.thresholdStd;
                obj.MinChannelsField.Value = ...
                    defaults.detection.minSimultaneousChannels;
                obj.MergeGapField.Value = defaults.detection.mergeGapSamples;
                obj.SettleWindowField.Value = ...
                    defaults.detection.settleWindowSamples;
                obj.SettleToleranceField.Value = ...
                    defaults.detection.settleToleranceStd;
            end
            obj.CurrentParameters = obj.parametersFromControls();

            if isKey(obj.ReferenceSelections, key)
                obj.setReferenceSeconds(obj.ReferenceSelections(key));
            else
                % A sessao nova ja fica armada para os dois cliques. Assim o
                % usuario pode clicar diretamente no sinal, sem uma etapa
                % oculta entre carregar a sessao e selecionar a referencia.
                obj.SelectionStage = 1;
                obj.drawSignalAndMask();
                obj.setStatus(sprintf([ ...
                    'Sessao carregada: %d canais, %d amostras. ' ...
                    'Clique no INICIO do trecho limpo no grafico do sinal.'], ...
                    size(session.lfp, 1), size(session.lfp, 2)), ...
                    [0.12 0.30 0.55]);
            end
            clear readerCleanup busyCleanup;
        end

        function params = parametersFromControls(obj)
            obj.requireSession();
            params = SPARQ.processingOptions(size(obj.CurrentSession.lfp, 1));
            params.channels.excluded = obj.parseExcludedChannels( ...
                obj.ExcludedChannelsField.Value, params.channels.count);
            params.detection.thresholdStd = obj.ThresholdStdField.Value;
            params.detection.minSimultaneousChannels = ...
                obj.MinChannelsField.Value;
            params.detection.mergeGapSamples = obj.MergeGapField.Value;
            params.detection.settleWindowSamples = obj.SettleWindowField.Value;
            params.detection.settleToleranceStd = ...
                obj.SettleToleranceField.Value;
            params.output.includeConcat = obj.IncludeConcatCheckBox.Value;
            params.output.includeNaN = obj.IncludeNaNCheckBox.Value;
            params.plot.enabled = true;
            params.plot.thresholdStd = params.detection.thresholdStd;
            SPARQ.internal.validateParameters(params);
        end

        function reprocess(obj)
            obj.requireSession();
            obj.setBusy(true, 'Atualizando a deteccao...');
            busyCleanup = onCleanup(@() obj.setBusy(false, ''));
            params = obj.parametersFromControls();
            obj.CurrentParameters = params;
            obj.SessionParameters(obj.currentSessionKey()) = params;
            if isempty(obj.CurrentReferenceIdx)
                obj.CurrentResult = [];
                obj.drawSignalAndMask();
                obj.setStatus('Selecione uma referencia limpa para detectar.', ...
                    [0.65 0.36 0.05]);
                clear busyCleanup;
                return;
            end

            result = SPARQ.processSession(obj.CurrentSession, ...
                obj.CurrentReferenceIdx, params);
            obj.CurrentResult = result;
            obj.drawSignalAndMask();
            obj.SaveButton.Enable = 'on';
            obj.setStatus(sprintf( ...
                'Atualizado: %.3f%% ruido | %.3f%% preservado.', ...
                result.noise.percentNoise, result.noise.percentSaved), ...
                [0.10 0.40 0.16]);
            clear busyCleanup;
        end

        function drawExportOverview(obj)
            tags = SPARQ.internal.figureTags();
            overviewFigure = SPARQ.internal.getOrCreateFigure(tags.overview);
            set(overviewFigure, 'Name', ...
                'SPARQ - selecao de referencia limpa', 'NumberTitle', 'off');
            overviewAxes = axes('Parent', overviewFigure);
            SPARQ.viz.channels(obj.CurrentSession, obj.CurrentParameters, ...
                overviewAxes, 'MaxDisplayPoints', obj.MaxDisplayPoints);
            sessionTitle = SPARQ.internal.sessionTitle( ...
                obj.CurrentSession, obj.CurrentParameters);
            title(overviewAxes, {sessionTitle, ...
                'Escolha um trecho sem ruido para a referencia', ...
                'Clique no INICIO e depois no FIM do trecho'}, ...
                'FontWeight', 'bold');
            SPARQ.internal.drawReferenceMarker( ...
                overviewAxes, obj.CurrentReferenceSeconds(1));
            SPARQ.internal.drawReferenceMarker( ...
                overviewAxes, obj.CurrentReferenceSeconds(2));
        end

        function drawSignalAndMask(obj)
            delete(obj.PlotOverlays(isgraphics(obj.PlotOverlays)));
            obj.PlotOverlays = gobjects(0);
            cla(obj.SummaryAxes);
            obj.SaveButton.Enable = 'off';
            if isempty(obj.CurrentSession)
                return;
            end

            params = obj.CurrentParameters;
            if isempty(params)
                params = SPARQ.processingOptions( ...
                    size(obj.CurrentSession.lfp, 1));
            end
            plotKey = {params.channels, params.plot.channelSpacing};
            if ~isequal(obj.BasePlotKey, plotKey)
                cla(obj.SignalAxes);
                SPARQ.viz.channels(obj.CurrentSession, params, obj.SignalAxes, ...
                    'MaxDisplayPoints', obj.MaxDisplayPoints);
                obj.BasePlotKey = plotKey;
                xlim(obj.SignalAxes, [obj.CurrentSession.time(1), ...
                    obj.CurrentSession.time(end)]);
            end
            baseChildren = obj.SignalAxes.Children;
            if obj.SelectionStage == 1
                title(obj.SignalAxes, ...
                    'Sinal multicanal - clique no INICIO da referencia');
            elseif obj.SelectionStage == 2
                title(obj.SignalAxes, ...
                    'Sinal multicanal - clique no FIM da referencia');
            else
                title(obj.SignalAxes, 'Sinal multicanal');
            end
            hold(obj.SignalAxes, 'on');
            if ~isempty(obj.CurrentResult)
                SPARQ.internal.highlightNoiseTraces(obj.SignalAxes, ...
                    obj.CurrentSession, obj.CurrentResult.noise, params, ...
                    'MaxDisplayPoints', obj.MaxDisplayPoints);
            end
            if ~isempty(obj.CurrentReferenceSeconds)
                xline(obj.SignalAxes, obj.CurrentReferenceSeconds(1), '--', ...
                    'Referencia', 'Color', [0.10 0.55 0.15], ...
                    'LineWidth', 1.5);
                xline(obj.SignalAxes, obj.CurrentReferenceSeconds(2), '--', ...
                    'Color', [0.10 0.55 0.15], 'LineWidth', 1.5);
            elseif ~isempty(obj.PendingReferenceStart)
                xline(obj.SignalAxes, obj.PendingReferenceStart, '--', ...
                    'Inicio', 'Color', [0.10 0.55 0.15], 'LineWidth', 1.5);
            end
            hold(obj.SignalAxes, 'off');
            obj.PlotOverlays = setdiff(obj.SignalAxes.Children, baseChildren);
            obj.disablePlotHitTesting(obj.SignalAxes);

            if isempty(obj.CurrentResult)
                obj.SummaryPanel.Visible = 'off';
                obj.PlotGrid.RowHeight = {'1x', 0};
            else
                % O resumo e compacto; o sinal conserva todo o espaco restante.
                obj.PlotGrid.RowHeight = {'1x', 150};
                obj.SummaryPanel.Visible = 'on';
                SPARQ.viz.preservationSummary(obj.CurrentResult.noise, ...
                    'Sessao', obj.SummaryAxes);
                title(obj.SummaryAxes, 'Preservacao do sinal', 'FontSize', 11);
                ylabel(obj.SummaryAxes, 'Amostras (%)', 'FontSize', 10);
                obj.SummaryAxes.XTickLabel = {'Preservado', 'Removido (ruido)'};
                obj.SummaryAxes.FontSize = 10;
                obj.SaveButton.Enable = 'on';
            end
            drawnow limitrate;
        end

        function disablePlotHitTesting(~, axesHandle)
            objects = findall(axesHandle);
            for i = 1:numel(objects)
                if isprop(objects(i), 'HitTest') && objects(i) ~= axesHandle
                    objects(i).HitTest = 'off';
                end
                if isprop(objects(i), 'PickableParts') && objects(i) ~= axesHandle
                    objects(i).PickableParts = 'none';
                end
            end
        end

        function onBrowse(obj)
            startFolder = obj.DataFolderField.Value;
            if exist(startFolder, 'dir') ~= 7
                startFolder = pwd;
            end
            folder = uigetdir(startFolder, ...
                'Selecione a pasta que contem as gravacoes MAT');
            if isequal(folder, 0)
                return;
            end
            obj.DataFolderField.Value = folder;
            obj.onDiscover();
        end

        function onDiscover(obj)
            try
                obj.loadDataFolder(obj.DataFolderField.Value);
            catch exception
                obj.showException(exception);
            end
        end

        function onSessionChanged(obj)
            try
                obj.loadSession(obj.SessionListBox.Value);
            catch exception
                obj.showException(exception);
            end
        end

        function onParameterChanged(obj)
            if isempty(obj.CurrentSession)
                return;
            end
            try
                obj.reprocess();
            catch exception
                obj.CurrentResult = [];
                obj.SaveButton.Enable = 'off';
                obj.setStatus(exception.message, [0.75 0.10 0.10]);
            end
        end

        function onStartReference(obj)
            if isempty(obj.CurrentSession)
                obj.setStatus('Carregue uma sessao antes da referencia.', ...
                    [0.75 0.10 0.10]);
                return;
            end
            obj.SelectionStage = 1;
            obj.PendingReferenceStart = [];
            obj.CurrentReferenceIdx = [];
            obj.CurrentReferenceSeconds = [];
            obj.CurrentResult = [];
            obj.drawSignalAndMask();
            obj.setStatus('Clique no INICIO do trecho limpo no grafico do sinal.', ...
                [0.12 0.30 0.55]);
        end

        function onFigureMouseDown(obj, figureHandle)
            if obj.SelectionStage == 0 || isempty(obj.CurrentSession)
                return;
            end
            clickedObject = figureHandle.CurrentObject;
            if isempty(clickedObject)
                return;
            end
            if isequal(clickedObject, obj.SignalAxes)
                clickedAxes = obj.SignalAxes;
            else
                clickedAxes = ancestor(clickedObject, 'axes');
            end
            if isempty(clickedAxes) || ~isequal(clickedAxes, obj.SignalAxes)
                return;
            end
            point = obj.SignalAxes.CurrentPoint;
            selectedTime = point(1, 1);
            bounds = [obj.CurrentSession.time(1), obj.CurrentSession.time(end)];
            if selectedTime < bounds(1) || selectedTime > bounds(2)
                return;
            end
            if obj.SelectionStage == 1
                obj.PendingReferenceStart = selectedTime;
                obj.SelectionStage = 2;
                obj.drawSignalAndMask();
                obj.setStatus('Agora clique no FIM do trecho limpo.', ...
                    [0.12 0.30 0.55]);
            else
                startTime = obj.PendingReferenceStart;
                try
                    obj.setReferenceSeconds([startTime selectedTime]);
                catch exception
                    obj.showException(exception);
                end
            end
        end

        function onSave(obj)
            try
                obj.saveCurrentResult();
            catch exception
                obj.showException(exception);
            end
        end

        function onSaveAll(obj)
            try
                obj.saveAllResults();
            catch exception
                obj.showException(exception);
            end
        end

        function showException(obj, exception)
            obj.setStatus(exception.message, [0.75 0.10 0.10]);
            if strcmp(obj.UIFigure.Visible, 'on')
                uialert(obj.UIFigure, exception.message, 'SPARQ');
            else
                rethrow(exception);
            end
        end

        function setBusy(obj, busy, message)
            if isempty(obj.UIFigure) || ~isvalid(obj.UIFigure)
                return;
            end
            if busy
                obj.UIFigure.Pointer = 'watch';
                if strlength(string(message)) > 0
                    obj.setStatus(message, [0.12 0.30 0.55]);
                end
                drawnow;
            else
                obj.UIFigure.Pointer = 'arrow';
            end
        end

        function setStatus(obj, message, color)
            if isempty(obj.StatusLabel) || ~isvalid(obj.StatusLabel) || ...
                    strlength(string(message)) == 0
                return;
            end
            obj.StatusLabel.Text = char(string(message));
            obj.StatusLabel.FontColor = color;
            drawnow limitrate;
        end

        function requireSession(obj)
            if isempty(obj.CurrentSession)
                error('SPARQ:App:noSession', ...
                    'Carregue uma sessao antes de continuar.');
            end
        end

        function key = currentSessionKey(obj)
            row = obj.Manifest(obj.CurrentRowIndex, :);
            key = obj.sessionKeyForRow(row);
        end

        function key = sessionKeyForRow(~, row)
            selector = row.DataSelector{1};
            if isempty(fieldnames(selector))
                selectorText = "";
            else
                selectorText = string(jsonencode(selector));
            end
            key = char(row.SourceFile + "|" + selectorText);
        end

        function applySessionParameters(obj, params)
            obj.ExcludedChannelsField.Value = strjoin( ...
                string(params.channels.excluded(:).'), ' ');
            obj.ThresholdStdField.Value = params.detection.thresholdStd;
            obj.MinChannelsField.Value = ...
                params.detection.minSimultaneousChannels;
            obj.MergeGapField.Value = params.detection.mergeGapSamples;
            obj.SettleWindowField.Value = ...
                params.detection.settleWindowSamples;
            obj.SettleToleranceField.Value = ...
                params.detection.settleToleranceStd;
            obj.IncludeConcatCheckBox.Value = params.output.includeConcat;
            obj.IncludeNaNCheckBox.Value = params.output.includeNaN;
        end

        function outputPath = resultPathForRow(obj, rowIndex)
            row = obj.Manifest(rowIndex, :);
            outputDirectory = obj.outputDirectoryForRow(rowIndex);
            stem = obj.resultStemForRow(row, rowIndex);
            outputPath = string(fullfile( ...
                outputDirectory, stem + "_clean.mat"));
        end

        function assertAllDestinationsAvailable(obj)
            if obj.OverwriteCheckBox.Value
                return;
            end
            for i = 1:height(obj.Manifest)
                outputPath = obj.resultPathForRow(i);
                if isfile(outputPath)
                    error('SPARQ:App:resultExists', ...
                        ['O resultado ja existe e nenhuma sessao foi salva: %s. ' ...
                         'Habilite a substituicao para sobrescreve-lo.'], ...
                        outputPath);
                end

                row = obj.Manifest(i, :);
                stem = obj.resultStemForRow(row, i);
                imageFolder = fullfile(obj.outputDirectoryForRow(i), 'imagens');
                suffixes = ["raw", "thresholds", "noise_windows", ...
                    "saved_percentage"];
                key = obj.sessionKeyForRow(row);
                if isKey(obj.SessionParameters, key)
                    params = obj.SessionParameters(key);
                    if params.output.includeConcat
                        suffixes(end + 1) = "concat"; %#ok<AGROW>
                    end
                    if params.output.includeNaN
                        suffixes(end + 1) = "nan"; %#ok<AGROW>
                    end
                end
                for suffix = suffixes
                    imagePath = fullfile( ...
                        imageFolder, stem + "_" + suffix + ".png");
                    if isfile(imagePath)
                        error('SPARQ:main:imageExists', ...
                            ['A imagem de resultado ja existe e nenhuma ' ...
                             'sessao foi salva: %s. Habilite a substituicao ' ...
                             'para sobrescreve-la.'], imagePath);
                    end
                end
            end
        end

        function directory = outputDirectoryForRow(obj, rowIndex)
            dataRoot = char(obj.DataFolderField.Value);
            directories = strings(height(obj.Manifest), 1);
            used = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for i = 1:height(obj.Manifest)
                row = obj.Manifest(i, :);
                obj.assertSourceInsideDataRoot(row.SourceFile, dataRoot);
                baseDirectory = string(fullfile(dataRoot, 'SPARQ_results', ...
                    obj.resultFolderStemForRow(row, i, dataRoot)));
                candidate = baseDirectory;
                suffix = 2;
                while isKey(used, lower(char(candidate)))
                    candidate = baseDirectory + "__" + suffix;
                    suffix = suffix + 1;
                end
                used(lower(char(candidate))) = true;
                directories(i) = candidate;
            end
            directory = char(directories(rowIndex));
        end

        function folderStem = resultFolderStemForRow(obj, row, rowIndex, dataRoot)
            sourceFile = char(row.SourceFile);
            prefix = [dataRoot filesep];
            if numel(sourceFile) >= numel(prefix) && ...
                    strcmpi(sourceFile(1:numel(prefix)), prefix)
                relativeSource = sourceFile(numel(prefix) + 1:end);
            else
                [~, sourceName, sourceExtension] = fileparts(sourceFile);
                relativeSource = [sourceName sourceExtension];
            end
            [relativeFolder, sourceStem] = fileparts(relativeSource);
            sourceIdentity = fullfile(relativeFolder, sourceStem);
            sourceIdentity = regexprep(sourceIdentity, '[\\/]+', '__');
            sourceIdentity = obj.safePathSegment(sourceIdentity);
            sessionStem = obj.resultStemForRow(row, rowIndex);
            if strcmpi(char(sessionStem), char(obj.safePathSegment(sourceStem)))
                folderStem = sourceIdentity;
            else
                folderStem = sourceIdentity + "__" + sessionStem;
            end
        end

        function stem = resultStemForRow(obj, row, rowIndex)
            stem = obj.safePathSegment(row.SessionId);
            if strlength(stem) == 0 || ismember(stem, [".", ".."])
                [~, sourceStem] = fileparts(row.SourceFile);
                stem = obj.safePathSegment(sourceStem);
            end
            if strlength(stem) == 0 || ismember(stem, [".", ".."])
                stem = "session-" + rowIndex;
            end
        end

        function assertSourceInsideDataRoot(~, sourceFile, dataRoot)
            sourceFolder = char(fileparts(sourceFile));
            if strcmpi(sourceFolder, dataRoot)
                return;
            end
            prefix = [dataRoot filesep];
            if numel(sourceFolder) < numel(prefix) || ...
                    ~strcmpi(sourceFolder(1:numel(prefix)), prefix)
                error('SPARQ:App:pathOutsideRoot', ...
                    'A sessao esta fora da pasta de dados selecionada.');
            end
        end
    end

    methods (Static, Access = private)
        function folder = absoluteFolder(folder)
            folder = char(string(folder));
            if exist(folder, 'dir') ~= 7
                error('SPARQ:App:dataFolderNotFound', ...
                    'A pasta de dados nao existe: %s', folder);
            end
            [success, attributes] = fileattrib(folder);
            if ~success
                error('SPARQ:App:dataFolderNotFound', ...
                    'Nao foi possivel resolver a pasta: %s', folder);
            end
            folder = attributes.Name;
        end

        function labels = sessionLabels(manifest)
            labels = strings(height(manifest), 1);
            for i = 1:height(manifest)
                [~, sourceStem] = fileparts(manifest.SourceFile(i));
                label = manifest.SessionId(i);
                if strlength(label) == 0
                    label = string(sourceStem);
                end
                if strlength(manifest.Condition(i)) > 0
                    label = label + " | " + manifest.Condition(i);
                end
                labels(i) = label + " | " + string(sourceStem);
            end
            labels = cellstr(labels);
        end

        function channels = parseExcludedChannels(value, nChannels)
            textValue = strtrim(string(value));
            if strlength(textValue) == 0 || textValue == "[]"
                channels = [];
                return;
            end
            textValue = regexprep(textValue, '[\[\],;]', ' ');
            pieces = split(textValue);
            pieces = pieces(strlength(pieces) > 0);
            channels = str2double(pieces).';
            if isempty(channels) || any(~isfinite(channels)) || ...
                    any(channels ~= round(channels)) || any(channels < 1) || ...
                    any(channels > nChannels) || ...
                    numel(unique(channels)) ~= numel(channels)
                error('SPARQ:App:badExcludedChannels', ...
                    ['Informe indices unicos entre 1 e %d, separados por ' ...
                     'espaco ou virgula.'], nChannels);
            end
        end

        function value = safePathSegment(value)
            value = regexprep(string(value), '[^A-Za-z0-9_.-]', '_');
        end
    end
end
