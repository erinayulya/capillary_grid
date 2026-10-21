function fig = showSimulationReportDialog(result)
%SHOWSIMULATIONREPORTDIALOG Choose PDF states after a recorded simulation.
% Closing this window leaves all saved MAT files available without a PDF.
% Report generation reads saved states; no model/solver functions are called.
fig = uifigure('Name','Формирование отчёта', ...
    'Position',[400 300 620 355],'Resize','off');
caption = uilabel(fig,'Position',[25 275 570 65],'FontSize',16, ...
    'Text',{sprintf('Симуляция завершилась за %d шагов.',result.steps), ...
    'Сколько шагов использовать для визуализации?'});
if ~strcmp(result.status,'Вторая фаза достигла правой границы.')
    uilabel(fig,'Position',[25 235 570 40], ...
        'Text',result.status,'WordWrap','on');
end
choices = uibuttongroup(fig,'Position',[25 135 570 100], ...
    'BorderType','none','SelectionChangedFcn',@changeSelection);
allSteps = uiradiobutton(choices,'Position',[0 65 120 25], ...
    'Text','Все','Value',true,'FontSize',15);
everyNth = uiradiobutton(choices,'Position',[0 20 130 25], ...
    'Text','Каждый N','FontSize',15);
interval = uieditfield(choices,'numeric','Position',[145 17 120 30], ...
    'Value',2,'Limits',[1 Inf],'Enable','off','FontSize',15);
uilabel(fig,'Position',[25 83 570 45],'WordWrap','on', ...
    'Text','Начальное состояние (t=0) и последний шаг всегда включаются в отчёт.');
button = uibutton(fig,'Position',[405 25 190 45], ...
    'Text','Сформировать','FontSize',15,'ButtonPushedFcn',@generate);

    function changeSelection(~,~)
        if choices.SelectedObject == everyNth
            interval.Enable = 'on';
        else
            interval.Enable = 'off';
        end
    end

    function generate(~,~)
        stride = 1;
        if choices.SelectedObject == everyNth, stride = interval.Value; end
        if ~isfinite(stride) || stride < 1 || stride ~= fix(stride)
            uialert(fig,'N должно быть положительным целым числом.','Ошибка');
            return
        end
        button.Enable = 'off';
        button.Text = 'Формирование…';
        allSteps.Enable = 'off';
        everyNth.Enable = 'off';
        interval.Enable = 'off';
        drawnow;
        try
            [pdfPath,updatedResult] = writeSimulationReport(result.directory,stride);
            % Only update the workspace result belonging to this saved run.
            if evalin('base','exist(''simulationResult'',''var'')')
                currentResult = evalin('base','simulationResult');
                if isstruct(currentResult) && isfield(currentResult,'directory') && ...
                        strcmp(currentResult.directory,result.directory)
                    assignin('base','simulationResult',updatedResult);
                end
            end
            fprintf('Отчёт: %s\n',pdfPath);
        catch exception
            if isvalid(fig)
                button.Enable = 'on';
                button.Text = 'Сформировать';
                allSteps.Enable = 'on';
                everyNth.Enable = 'on';
                changeSelection([],[]);
                uialert(fig,{ ...
                    'Не удалось сформировать отчёт. Результаты расчёта сохранены.', ...
                    exception.message},'Ошибка формирования отчёта');
            end
            return
        end
        if isvalid(fig)
            caption.Text = {'Отчёт сформирован.', ...
                'PDF сохранён в папке результатов.'};
            button.Text = 'Закрыть';
            button.Enable = 'on';
            button.ButtonPushedFcn = @(~,~) delete(fig);
        end
    end
end
