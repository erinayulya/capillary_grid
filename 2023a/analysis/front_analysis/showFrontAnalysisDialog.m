function fig = showFrontAnalysisDialog()
%SHOWFRONTANALYSISDIALOG Configure exports; no calculation runs in callbacks.
% Caller uses uiwait, reads options from UserData after confirmation, then
% closes the dialog before analyzing. Cancel/close leaves UserData empty.
resultsDirectory = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results');
try
    initialDirectory = latestFrontAnalysisRun(resultsDirectory);
catch exception
    if ~strcmp(exception.identifier,'analyzeMeniscusFront:NoRun'), rethrow(exception); end
    initialDirectory = '';
end
fig = uifigure('Name','Анализ фронта вытеснения','Tag','frontAnalysisDialog', ...
    'Position',[350 250 700 435],'Resize','off','WindowStyle','modal', ...
    'UserData',[]);
fig.CloseRequestFcn = @(~,~) delete(fig);
layout = uigridlayout(fig,[8 2],'ColumnWidth',{'1x',135}, ...
    'RowHeight',{55,25,35,30,30,30,30,40},'Padding',[20 15 20 15], ...
    'RowSpacing',10);
caption = uilabel(layout,'WordWrap','on','FontSize',13, ...
    'Text','Выберите папку расчёта из results. Все таблицы, GIF и общий PDF анализа сохраняются в analysis внутри выбранной папки.');
caption.Layout.Row = 1; caption.Layout.Column = [1 2];
sourceLabel = uilabel(layout,'Text','Папка расчёта','FontSize',14);
sourceLabel.Layout.Row = 2; sourceLabel.Layout.Column = [1 2];
sourceField = uieditfield(layout,'text','Value',initialDirectory, ...
    'FontSize',12,'Tag','frontSourceDirectory','Tooltip',initialDirectory, ...
    'HorizontalAlignment','right','ValueChangedFcn',@updateSourceCaption);
sourceField.Layout.Row = 3; sourceField.Layout.Column = 1;
updateSourceCaption([],[]);
browse = uibutton(layout,'Text','Выбрать папку…','FontSize',13, ...
    'Tag','frontBrowseDirectory','ButtonPushedFcn',@browseDirectory);
browse.Layout.Row = 3; browse.Layout.Column = 2;
createGif = uicheckbox(layout,'Text','Сформировать гиф','Value',true, ...
    'FontSize',14,'Tag','frontCreateGif','ValueChangedFcn',@toggleGif);
createGif.Layout.Row = 4; createGif.Layout.Column = [1 2];
delayLabel = uilabel(layout,'Text','Время одного кадра, с','FontSize',14);
delayLabel.Layout.Row = 5; delayLabel.Layout.Column = 1;
frameDelay = uieditfield(layout,'numeric','Value',0.1,'Limits',[0.01 655], ...
    'FontSize',14,'Tag','frontFrameDelay');
frameDelay.Layout.Row = 5; frameDelay.Layout.Column = 2;
createPdf = uicheckbox(layout,'Text','Сформировать PDF','Value',true, ...
    'FontSize',14,'Tag','frontCreatePdf');
createPdf.Layout.Row = 6; createPdf.Layout.Column = [1 2];
analyzeClusters = uicheckbox(layout, ...
    'Text','Анализ кластеров с остаточной насыщенностью','Value',false, ...
    'FontSize',14,'Tag','frontAnalyzeClusters', ...
    'Tooltip','Последний снимок: таблицы кластеров и последние страницы общего PDF анализа.');
analyzeClusters.Layout.Row = 7; analyzeClusters.Layout.Column = [1 2];
buttons = uigridlayout(layout,[1 2],'ColumnWidth',{'1x','1x'},'Padding',0);
buttons.Layout.Row = 8; buttons.Layout.Column = [1 2];
uibutton(buttons,'Text','Отмена','FontSize',14,'Tag','frontCancel', ...
    'ButtonPushedFcn',@(~,~) delete(fig));
uibutton(buttons,'Text','Сформировать','FontSize',14,'Tag','frontGenerate', ...
    'ButtonPushedFcn',@accept);

    function toggleGif(~,~)
        heights = layout.RowHeight;
        if createGif.Value
            heights{5} = 30;
            delayLabel.Visible = 'on'; frameDelay.Visible = 'on';
        else
            heights{5} = 0;
            delayLabel.Visible = 'off'; frameDelay.Visible = 'off';
        end
        layout.RowHeight = heights;
    end

    function browseDirectory(~,~)
        selected = uigetdir(resultsDirectory,'Выберите папку расчёта из results');
        if ~isequal(selected,0)
            sourceField.Value = selected;
            updateSourceCaption([],[]);
        end
    end

    function updateSourceCaption(~,~)
        [~,folderName] = fileparts(strtrim(sourceField.Value));
        sourceLabel.Text = ['Папка расчёта: ' folderName];
        sourceField.Tooltip = sourceField.Value;
    end

    function accept(~,~)
        source = strtrim(sourceField.Value);
        if ~isfolder(source)
            uialert(fig,'Выберите существующую папку расчёта из results.','Ошибка');
            return
        end
        [~,sourceAttributes] = fileattrib(source);
        [~,rootAttributes] = fileattrib(resultsDirectory);
        source = sourceAttributes.Name;
        prefix = [rootAttributes.Name filesep];
        files = dir(fullfile(source,'step_*.mat'));
        hasSteps = any(~[files.isdir] & ...
            ~cellfun('isempty',regexp({files.name},'^step_\d+\.mat$','once')));
        if ~strncmpi(source,prefix,numel(prefix)) || ~hasSteps
            uialert(fig,'Нужна папка внутри results со снимками step_*.mat.','Ошибка');
            return
        end
        delay = frameDelay.Value;
        if createGif.Value && (~isfinite(delay) || delay<0.01 || delay>655)
            uialert(fig,'Время одного кадра должно быть от 0.01 до 655 секунд.','Ошибка');
            return
        end
        if ~createGif.Value, delay = 0.1; end
        fig.UserData = struct('createGif',createGif.Value, ...
            'createPdf',createPdf.Value,'analyzeClusters',analyzeClusters.Value, ...
            'frameDelay',delay,'sourceDirectory',source);
        uiresume(fig);
    end
end
