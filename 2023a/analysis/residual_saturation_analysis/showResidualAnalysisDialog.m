function fig = showResidualAnalysisDialog(resultsDirectory)
%SHOWRESIDUALANALYSISDIALOG Choose source folder and common-PDF cluster option.
% This dialog does not write files or invoke the solver.
fig=uifigure('Name','Анализ остаточной насыщенности','Tag','residualAnalysisDialog', ...
    'Position',[350 300 700 280],'Resize','off','WindowStyle','modal','UserData',[]);
layout=uigridlayout(fig,[5 2],'ColumnWidth',{'1x',140}, ...
    'RowHeight',{55,25,35,35,40},'Padding',[20 15 20 15],'RowSpacing',8);
caption=uilabel(layout,'WordWrap','on','FontSize',13, ...
    'Text','Выберите папку расчёта. Будет обработан последний сохранённый снимок. Таблицы сохраняются в папке анализа внутри расчёта.');
caption.Layout.Column=[1 2];
label=uilabel(layout,'Text','Папка расчёта','FontSize',13);
label.Layout.Row=2; label.Layout.Column=[1 2];
source=uieditfield(layout,'text','Value',resultsDirectory,'Tag','residualSourceDirectory');
source.Layout.Row=3;
browse=uibutton(layout,'Text','Выбрать папку…','ButtonPushedFcn',@choose);
browse.Layout.Row=3; browse.Layout.Column=2;
enabled=uicheckbox(layout,'Text','Анализ кластеров с остаточной насыщенностью', ...
    'Value',true,'FontSize',14,'Tag','residualAnalyzeClusters', ...
    'Tooltip','Добавить распределение кластеров в конец mobile_front.pdf в analysis. Без галочки сохраняются только таблицы.');
enabled.Layout.Row=4; enabled.Layout.Column=[1 2];
buttons=uigridlayout(layout,[1 2],'Padding',0,'ColumnWidth',{'1x','1x'});
buttons.Layout.Row=5; buttons.Layout.Column=[1 2];
uibutton(buttons,'Text','Отмена','ButtonPushedFcn',@(~,~) delete(fig));
uibutton(buttons,'Text','Сформировать','Tag','residualGenerate','ButtonPushedFcn',@accept);
    function choose(~,~)
        selected=uigetdir(resultsDirectory,'Выберите папку расчёта');
        if ~isequal(selected,0), source.Value=selected; source.Tooltip=selected; end
    end
    function accept(~,~)
        folder=strtrim(source.Value);
        files=dir(fullfile(folder,'step_*.mat'));
        valid=~[files.isdir] & ~cellfun('isempty',regexp({files.name},'^step_\d+\.mat$','once'));
        if ~isfolder(folder) || ~any(valid)
            uialert(fig,'Выберите папку со снимками step_*.mat.','Ошибка'); return
        end
        fig.UserData=struct('sourceDirectory',folder,'analyzeClusters',enabled.Value);
        uiresume(fig);
    end
end
