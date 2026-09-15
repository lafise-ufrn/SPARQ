classdef test_guiWorkflow < matlab.uitest.TestCase
% test_guiWorkflow  Contrato reativo e de seguranca da interface grafica.

    methods (Test)
        function launcherCreatesTheInteractiveApp(testCase)
            app = SPARQ_GUI('Visible', 'off');
            cleanupObject = onCleanup(@() delete(app));

            testCase.verifyClass(app, 'SPARQ.App');
            testCase.verifyTrue(isvalid(app.UIFigure));
        end

        function startsMaximized(testCase)
            app = SPARQ_GUI('Visible', 'on');
            cleanupObject = onCleanup(@() delete(app));
            drawnow;
            testCase.verifyEqual(app.UIFigure.WindowState, 'maximized');
        end

        function fixedDefaultDoesNotReadFs(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            fixture = load(sourceFile, 'LFP');
            fs = 250;
            LFP = fixture.LFP;
            save(sourceFile, 'LFP', 'fs');
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            session = app.getCurrentSession();
            testCase.verifyEqual(session.samplingRateHz, 1000);
            testCase.verifyEqual(session.time(end), 399/1000);
        end

        function explicitFrequencyVariableIsRespected(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            fixture = load(sourceFile, 'LFP');
            fs = 250;
            LFP = fixture.LFP;
            save(sourceFile, 'LFP', 'fs');
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder, ...
                'LoaderOptions', struct('samplingRateVariable', "fs"));
            appCleanup = onCleanup(@() delete(app));
            session = app.getCurrentSession();
            testCase.verifyEqual(session.samplingRateHz, 250);
        end

        function summaryAppearsOnlyAfterProcessing(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            summary = findobj(app.UIFigure, 'Tag', 'SPARQAppSummaryPanel');
            testCase.assertNotEmpty(summary);
            testCase.verifyEqual(summary.Visible, matlab.lang.OnOffSwitchState.off);
            testCase.verifyEqual(summary.Parent.RowHeight, {'1x', 0});
            signal = findobj(app.UIFigure, 'Tag', 'SPARQAppSignalAxes');
            testCase.verifyEqual(signal.Layout.Row, 1);
            testCase.verifyEqual(signal.Layout.Column, [1 2]);
            app.setReferenceSeconds([0 0.099]);
            testCase.verifyEqual(summary.Visible, matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual(summary.Parent.RowHeight, {'1x', 150});
            testCase.verifyEqual(summary.Layout.Column, 2);
            bars = findobj(summary, 'Type', 'bar');
            result = app.getCurrentResult();
            testCase.verifyEqual(bars.YData, ...
                [result.noise.percentSaved result.noise.percentNoise]);
            app.selectSession(1);
            testCase.verifyEqual(numel(findobj(summary, 'Type', 'bar')), 1);
        end

        function parameterChangeUpdatesMaskThroughScientificCore(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));

            testCase.verifyTrue(app.isAwaitingReferenceSelection());
            testCase.verifyNotEmpty(app.UIFigure.WindowButtonDownFcn);

            app.setReferenceSeconds([0 0.099]);
            testCase.verifyFalse(app.isAwaitingReferenceSelection());
            firstResult = app.getCurrentResult();
            directResult = SPARQ.processSession(app.getCurrentSession(), ...
                firstResult.referenceIdx, app.getCurrentParameters());

            testCase.verifyEqual(firstResult.cleanSignals.noiseMask, ...
                directResult.cleanSignals.noiseMask);
            testCase.verifyEqual(app.getDisplayedMask(), ...
                firstResult.cleanSignals.noiseMask);
            testCase.verifyGreaterThan(nnz( ...
                firstResult.cleanSignals.noiseMask), 0);

            app.setDetectionParameters(struct('thresholdStd', 100));
            secondResult = app.getCurrentResult();

            testCase.verifyNotEqual(secondResult.cleanSignals.noiseMask, ...
                firstResult.cleanSignals.noiseMask);
            testCase.verifyEqual(app.getDisplayedMask(), ...
                secondResult.cleanSignals.noiseMask);
            testCase.verifyEqual(nnz(secondResult.cleanSignals.noiseMask), 0);
        end

        function excludedChannelsPersistWhenSessionChanges(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            fixture = load(sourceFile, 'LFP', 'fs');
            LFP = repmat(fixture.LFP, 2, 1);
            fs = fixture.fs;
            save(sourceFile, 'LFP', 'fs');
            copyfile(sourceFile, fullfile(folder, 'recording-2.mat'));
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));

            app.setExcludedChannels(8);
            app.selectSession(2);

            testCase.verifyEqual( ...
                app.getCurrentParameters().channels.excluded, 8);
        end

        function clickingLoadedSignalSelectsReferenceWithoutExtraButton(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            app = SPARQ.App('Visible', 'on', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            signalAxes = findobj(app.UIFigure, 'Tag', 'SPARQAppSignalAxes');
            verticalCenter = mean(ylim(signalAxes));

            testCase.press(signalAxes, [0.01 verticalCenter]);
            testCase.verifyTrue(app.isAwaitingReferenceSelection());
            testCase.press(signalAxes, [0.09 verticalCenter]);

            testCase.verifyFalse(app.isAwaitingReferenceSelection());
            testCase.verifyNotEmpty(app.getCurrentResult());
            testCase.verifyNotEmpty(app.getDisplayedMask());
        end

        function parameterEditsReuseBaseTracesAndPreserveInput(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            original = app.getCurrentSession();
            axesHandle = findobj(app.UIFigure, 'Tag', 'SPARQAppSignalAxes');
            baseLines = findobj(axesHandle, 'Type', 'line');
            app.setReferenceSeconds([0 0.099]);
            app.setDetectionParameters(struct('thresholdStd', 100));
            testCase.verifyTrue(all(isgraphics(baseLines)));
            testCase.verifyEqual(app.getCurrentSession(), original);
        end

        function savingResultPreservesRawFileBytesSizeAndTime(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            bytesBefore = readFileBytes(sourceFile);
            metadataBefore = dir(sourceFile);
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            app.setReferenceSeconds([0 0.099]);

            outputPath = app.saveCurrentResult();

            metadataAfter = dir(sourceFile);
            testCase.verifyTrue(isfile(outputPath));
            testCase.verifyEqual(string(fileparts(outputPath)), ...
                string(fullfile(folder, 'SPARQ_results', 'recording')));
            testCase.verifyEqual(readFileBytes(sourceFile), bytesBefore);
            testCase.verifyEqual(metadataAfter.bytes, metadataBefore.bytes);
            testCase.verifyEqual(metadataAfter.datenum, metadataBefore.datenum);
            saved = load(outputPath, 'SPARQ_result');
            testCase.verifyEqual(saved.SPARQ_result.noiseMask, ...
                app.getCurrentResult().cleanSignals.noiseMask);
        end

        function savingResultAlsoSavesAllPlotImages(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            previousVisibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off');
            figureCleanup = onCleanup(@() cleanUpPlotFigures( ...
                previousVisibility));
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            app.setReferenceSeconds([0 0.099]);

            app.saveCurrentResult();

            imageFiles = dir(fullfile( ...
                folder, 'SPARQ_results', 'recording', 'imagens', ...
                'recording_*.png'));
            testCase.verifyNumElements(imageFiles, 4);
            testCase.verifyTrue(all([imageFiles.bytes] > 0));
            testCase.verifyEqual(sort(string({imageFiles.name})), sort([ ...
                "recording_raw.png", ...
                "recording_thresholds.png", ...
                "recording_noise_windows.png", ...
                "recording_saved_percentage.png"]));
        end

        function guiSavesTopLevelOptionalSignalsAndImages(testCase)
            [folder, cleanupObject] = temporaryRecording(); %#ok<ASGLU>
            previousVisibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off');
            figureCleanup = onCleanup(@() cleanUpPlotFigures( ...
                previousVisibility));
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            app.setReferenceSeconds([0 0.099]);
            setCheckBox(app, 'Salvar sinal concatenado', true);
            setCheckBox(app, 'Salvar sinal com NaN', true);
            inMemory = app.getCurrentResult().cleanSignals;

            outputPath = app.saveCurrentResult();

            loaded = load(outputPath, 'SPARQ_result');
            testCase.verifyEqual(loaded.SPARQ_result.concat, inMemory.concat);
            testCase.verifyEqual(loaded.SPARQ_result.nan, inMemory.nan);
            testCase.verifyEqual(loaded.SPARQ_result.channels, ...
                inMemory.channels);
            imageFiles = dir(fullfile(folder, 'SPARQ_results', 'recording', ...
                'imagens', 'recording_*.png'));
            testCase.verifyNumElements(imageFiles, 6);
            testCase.verifyTrue(all([imageFiles.bytes] > 0));
            testCase.verifyEqual(sort(string({imageFiles.name})), sort([ ...
                "recording_raw.png", ...
                "recording_thresholds.png", ...
                "recording_noise_windows.png", ...
                "recording_saved_percentage.png", ...
                "recording_concat.png", ...
                "recording_nan.png"]));

            setCheckBox(app, 'Salvar sinal concatenado', false);
            result = app.getCurrentResult();
            SPARQ.internal.plotProcessingResult(app.getCurrentSession(), ...
                result, app.getCurrentParameters(), 1000);
            tags = SPARQ.internal.figureTags();
            testCase.verifyEmpty(findall(groot, 'Type', 'figure', ...
                'Tag', tags.concat));
            testCase.verifyNotEmpty(findall(groot, 'Type', 'figure', ...
                'Tag', tags.nan));
        end

        function saveAllRequiresAReferenceForEverySession(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            copyfile(sourceFile, fullfile(folder, 'recording-2.mat'));
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            app.setReferenceSeconds([0 0.099]);

            testCase.verifyError(@() app.saveAllResults(), ...
                'SPARQ:App:missingReferences');
            testCase.verifyFalse(isfolder(fullfile(folder, 'SPARQ_results')));
        end

        function saveAllUsesOneUniqueFolderPerSession(testCase)
            [folder, cleanupObject, sourceFile] = temporaryRecording(); %#ok<ASGLU>
            secondFolder = fullfile(folder, 'nested');
            mkdir(secondFolder);
            secondSource = fullfile(secondFolder, 'recording.mat');
            copyfile(sourceFile, secondSource);
            sourceFiles = [string(sourceFile); string(secondSource)];
            bytesBefore = cellfun(@readFileBytes, cellstr(sourceFiles), ...
                'UniformOutput', false);
            metadataBefore = cellfun(@dir, cellstr(sourceFiles));
            previousVisibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off');
            figureCleanup = onCleanup(@() cleanUpPlotFigures( ...
                previousVisibility));
            app = SPARQ.App('Visible', 'off', 'DataFolder', folder);
            appCleanup = onCleanup(@() delete(app));
            saveAllButton = findobj(app.UIFigure, 'Type', 'uibutton', ...
                'Text', 'Salvar resultados de todas as sessoes');
            testCase.verifyNotEmpty(saveAllButton);
            testCase.verifyEqual(saveAllButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);

            app.setReferenceSeconds([0 0.099]);
            app.setDetectionParameters(struct('thresholdStd', 5));
            firstParameters = app.getCurrentParameters();
            app.selectSession(2);
            app.setReferenceSeconds([0.01 0.109]);
            app.setDetectionParameters(struct('thresholdStd', 6));
            secondSession = app.getCurrentSession();

            outputPaths = app.saveAllResults();

            testCase.verifySize(outputPaths, [2 1]);
            testCase.verifyTrue(all(isfile(outputPaths)));
            outputFolders = string(fileparts(outputPaths));
            testCase.verifyEqual(numel(unique(lower(outputFolders))), 2);
            testCase.verifyTrue(all(string(fileparts(outputFolders)) == ...
                string(fullfile(folder, 'SPARQ_results'))));
            [~, outputFolderNames] = fileparts(outputFolders);
            testCase.verifyEqual(sort(outputFolderNames), ...
                sort(["recording"; "nested__recording"]));
            testCase.verifyEqual(app.getCurrentSession(), secondSession);
            app.selectSession(1);
            testCase.verifyEqual( ...
                app.getCurrentParameters().detection.thresholdStd, ...
                firstParameters.detection.thresholdStd);
            for i = 1:numel(outputPaths)
                imageFiles = dir(fullfile(outputFolders(i), 'imagens', '*.png'));
                testCase.verifyNumElements(imageFiles, 4);
                testCase.verifyTrue(all([imageFiles.bytes] > 0));
                metadataAfter = dir(sourceFiles(i));
                testCase.verifyEqual(readFileBytes(sourceFiles(i)), ...
                    bytesBefore{i});
                testCase.verifyEqual(metadataAfter.bytes, metadataBefore(i).bytes);
                testCase.verifyEqual(metadataAfter.datenum, ...
                    metadataBefore(i).datenum);
            end
        end
    end
end

% ------------------------------------------------------------------------
function setCheckBox(app, label, value)
    checkBox = findobj(app.UIFigure, 'Type', 'uicheckbox', 'Text', label);
    if isempty(checkBox)
        error('SPARQ:tests:missingCheckBox', ...
            'Caixa de selecao nao encontrada: %s', label);
    end
    checkBox.Value = value;
    feval(checkBox.ValueChangedFcn, checkBox, []);
end

% ------------------------------------------------------------------------
function [folder, cleanupObject, sourceFile] = temporaryRecording()
    folder = tempname;
    mkdir(folder);
    cleanupObject = onCleanup(@() removeTemporaryFolder(folder));
    sourceFile = fullfile(folder, 'recording.mat');
    fs = 1000;
    time = (0:399) / fs;
    LFP = [sin(2*pi*8*time); cos(2*pi*10*time); ...
        sin(2*pi*12*time); cos(2*pi*6*time)];
    LFP(:, 250:270) = LFP(:, 250:270) + 10;
    save(sourceFile, 'LFP', 'fs');
end

% ------------------------------------------------------------------------
function bytes = readFileBytes(filePath)
    fileId = fopen(filePath, 'rb');
    if fileId < 0
        error('SPARQ:tests:fileOpenFailed', ...
            'Nao foi possivel abrir o arquivo: %s', filePath);
    end
    cleanupObject = onCleanup(@() fclose(fileId));
    bytes = fread(fileId, Inf, '*uint8');
end

% ------------------------------------------------------------------------
function removeTemporaryFolder(folder)
    if exist(folder, 'dir') == 7
        rmdir(folder, 's');
    end
end

% ------------------------------------------------------------------------
function cleanUpPlotFigures(previousVisibility)
    tags = SPARQ.internal.figureTags();
    tagFields = fieldnames(tags);
    for i = 1:numel(tagFields)
        figures = findall(groot, 'Type', 'figure', ...
            'Tag', tags.(tagFields{i}));
        delete(figures);
    end
    set(groot, 'DefaultFigureVisible', previousVisibility);
end
