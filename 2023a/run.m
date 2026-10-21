function run

setupProject;
resetSimulationWorkspace(true);
projectFolder = fileparts(mfilename('fullpath'));
settingsFile = fullfile(fileparts(projectFolder),'run-settings.mat');
previousGeometry = struct();

%% Окно: раскрывающиеся группы и постоянные кнопки внизу
fig = uifigure('Name','Параметры расчёта','Visible','off', ...
    'Position',[400 100 760 820]);
layout = uigridlayout(fig,[3 1],'RowHeight',{'1x',22,42}, ...
    'ColumnWidth',{'1x'},'Padding',[12 12 12 12]);
sections = uigridlayout(layout,[6 1],'ColumnWidth',{'1x'}, ...
    'RowHeight',{36,330,36,0,36,0},'Padding',[0 0 0 0], ...
    'RowSpacing',8,'Scrollable','on');
sections.Layout.Row = 1;
groupNames = {'Физические параметры','Параметры сети','Результаты'};
groupHeights = [330 290 92];
groupPanels = gobjects(1,3);
groupHeaders = gobjects(1,3);
for groupIndex = 1:3
    groupHeaders(groupIndex) = uibutton(sections,'state', ...
        'Text',['▶ ' groupNames{groupIndex}],'Value',false, ...
        'FontSize',15,'FontWeight','bold', ...
        'Tag',sprintf('groupHeader%d',groupIndex), ...
        'ValueChangedFcn',@(src,~) toggleGroup(src));
    groupHeaders(groupIndex).Layout.Row = 2*groupIndex-1;
    groupHeaders(groupIndex).UserData = groupIndex;
    groupPanels(groupIndex) = uipanel(sections,'BorderType','none', ...
        'Visible','off','Tag',sprintf('groupPanel%d',groupIndex));
    groupPanels(groupIndex).Layout.Row = 2*groupIndex;
end

%% Физические параметры: жидкости, модель и границы
physical = uigridlayout(groupPanels(1),[8 2], ...
    'ColumnWidth',{'1x',310},'RowHeight',{30,42,30,30,30,30,30,30}, ...
    'Padding',[10 8 10 8],'RowSpacing',8);
uilabel(physical,'Text','Вязкость воды μ₁, Па·с','FontSize',14);
mu1 = uieditfield(physical,'numeric','Value',1e-3,'FontSize',14);
uilabel(physical,'Text',{'Во сколько раз вязкость нефти', ...
    'больше вязкости воды μ₂ / μ₁'},'FontSize',14);
muRatio = uieditfield(physical,'numeric','Value',4.3,'FontSize',14);
uilabel(physical,'Text','Длина капилляра L, м','FontSize',14);
L = uieditfield(physical,'numeric','Value',9e-3,'FontSize',14);
uilabel(physical,'Text','Поверхностное натяжение σ, Н/м','FontSize',14);
sigma = uieditfield(physical,'numeric','Value',7e-2,'FontSize',14);
uilabel(physical,'Text','Угол смачивания θ, рад','FontSize',14);
theta = uieditfield(physical,'numeric','Value',pi/4,'FontSize',14);
pressureLabel = uilabel(physical,'Text','Давление на левой границе P₀, Па','FontSize',14);
pressureLabel.Layout.Row = 6; pressureLabel.Layout.Column = 1;
H_P0 = uieditfield(physical,'numeric','Value',1500,'FontSize',14);
H_P0.Layout.Row = 6; H_P0.Layout.Column = 2;
uilabel(physical,'Text','Модель движения мениска','FontSize',14);
MeniscusModel = uidropdown(physical, ...
    'Items',{'Один режим (вязкий)','Два режима (плато и вязкий)'}, ...
    'ItemsData',[1 2],'Value',2,'FontSize',14);
IncludeAadd = uicheckbox(physical,'Text','Учитывать A_add в вязком режиме', ...
    'Value',true,'FontSize',14);
IncludeAadd.Layout.Row = 8; IncludeAadd.Layout.Column = [1 2];

%% Параметры сети: матрицы или настройки случайных площадей
geometryLayout = uigridlayout(groupPanels(2),[2 2], ...
    'ColumnWidth',{'1x',310},'RowHeight',{30,250}, ...
    'Padding',[0 0 0 0],'RowSpacing',4);
uilabel(geometryLayout,'Text','Геометрия сети','FontSize',14);
GeometryMode = uidropdown(geometryLayout, ...
    'Items',{'Использовать предыдущую','Задать новую'}, ...
    'Value','Задать новую','FontSize',14,'ValueChangedFcn',@changeGeometryMode);
NewGeometryPanel = uipanel(geometryLayout,'BorderType','none','Tag','newGeometryPanel');
NewGeometryPanel.Layout.Row = 2; NewGeometryPanel.Layout.Column = [1 2];
network = uigridlayout(NewGeometryPanel,[3 2], ...
    'ColumnWidth',{'1x',310},'RowHeight',{30,0,200}, ...
    'Padding',[10 8 10 8],'RowSpacing',4);
uilabel(network,'Text','Площадь капилляров','FontSize',14);
AreaType = uidropdown(network,'Items',{'Матрица площадей','Случайная'}, ...
    'Value','Матрица площадей','FontSize',14,'ValueChangedFcn',@changeAreaType);
RandomPanel = uipanel(network,'BorderType','none','Visible','off');
RandomPanel.Layout.Row = 2; RandomPanel.Layout.Column = [1 2];
randomGrid = uigridlayout(RandomPanel,[3 3], ...
    'ColumnWidth',{'1x',130,130},'RowHeight',{38,38,38}, ...
    'Padding',[0 8 0 8],'RowSpacing',12);
uilabel(randomGrid,'Text','Диапазон площадей [от, до], м²','FontSize',14);
RandomMin = uieditfield(randomGrid,'numeric','Value',pi*(0.1e-3/2)^2,'FontSize',14);
RandomMax = uieditfield(randomGrid,'numeric','Value',pi*(1e-3/2)^2,'FontSize',14);
uilabel(randomGrid,'Text','Число горизонтальных рядов капилляров','FontSize',14);
RandomN_rows = uieditfield(randomGrid,'numeric','Value',3,'FontSize',14);
RandomN_rows.Layout.Row = 2; RandomN_rows.Layout.Column = [2 3];
columnLabel = uilabel(randomGrid,'Text','Число вертикальных рядов капилляров','FontSize',14);
columnLabel.Layout.Row = 3; columnLabel.Layout.Column = 1;
RandomN_cols = uieditfield(randomGrid,'numeric','Value',3,'FontSize',14);
RandomN_cols.Layout.Row = 3; RandomN_cols.Layout.Column = [2 3];
MatrixPanel = uipanel(network,'BorderType','none');
MatrixPanel.Layout.Row = 3; MatrixPanel.Layout.Column = [1 2];
matrixGrid = uigridlayout(MatrixPanel,[2 2], ...
    'ColumnWidth',{'1x','1x'},'RowHeight',{44,'1x'},'Padding',[0 0 0 0]);
uilabel(matrixGrid,'Text',{'Матрица площадей', ...
    'горизонтальных капилляров A, м²'},'FontSize',13);
uilabel(matrixGrid,'Text',{'Матрица площадей', ...
    'вертикальных капилляров A, м²'},'FontSize',13);
H_A = uitextarea(matrixGrid,'Value',{'[1 1 1 1;',' 1 2 1 1;', ...
    ' 1 1 1 1]*pi*(100e-6)^2'},'FontSize',13);
V_A = uitextarea(matrixGrid,'Value',{'[1 1 1;',' 1 1 1;', ...
    ' 1 5 1;',' 1 1 1]*pi*(100e-6)^2'},'FontSize',13);
%% Результаты: сохраняемые шаги (не влияет на расчёт)
resultsGrid = uigridlayout(groupPanels(3),[5 2], ...
    'ColumnWidth',{'1x',310},'RowHeight',{30,0,30,0,0}, ...
    'Padding',[10 8 10 8],'RowSpacing',8);
uilabel(resultsGrid,'Text','Сколько шагов сохранять','FontSize',14);
SaveStepsMode = uidropdown(resultsGrid, ...
    'Items',{'Все','Сохранять каждый N шаг'},'Value','Все', ...
    'FontSize',14,'ValueChangedFcn',@changeSaveStepsMode);
saveEveryNLabel = uilabel(resultsGrid,'Text','N','FontSize',14,'Visible','off');
SaveEveryN = uieditfield(resultsGrid,'numeric','Value',2, ...
    'FontSize',14,'Visible','off');
VisualizeSatPressure = uicheckbox(resultsGrid, ...
    'Text','Визуализация сатурации и давления','Value',false,'FontSize',14, ...
    'ValueChangedFcn',@changeSaveStepsMode);
VisualizeSatPressure.Layout.Row = 3;
VisualizeSatPressure.Layout.Column = [1 2];
frameDelayLabel = uilabel(resultsGrid,'Text','Время одного кадра, с', ...
    'FontSize',14,'Visible','off');
frameDelayLabel.Layout.Row = 4; frameDelayLabel.Layout.Column = 1;
GifFrameDelay = uieditfield(resultsGrid,'numeric','Value',0.1, ...
    'Limits',[0.01 655],'FontSize',14,'Visible','off');
GifFrameDelay.Layout.Row = 4; GifFrameDelay.Layout.Column = 2;
GifShowMeniscus = uicheckbox(resultsGrid,'Text','Отображать мениск', ...
    'Value',true,'FontSize',14,'Visible','off');
GifShowMeniscus.Layout.Row = 5; GifShowMeniscus.Layout.Column = [1 2];

%% Кнопки и восстановление явно сохранённого ввода
statusLabel = uilabel(layout,'Text','','Tag','saveStatus','FontSize',13);
statusLabel.Layout.Row = 2;
buttons = uigridlayout(layout,[1 3],'ColumnWidth',{'1x','1x','1.5x'}, ...
    'RowHeight',{'1x'},'Padding',[0 0 0 0]);
buttons.Layout.Row = 3;
uibutton(buttons,'Text','Нарисовать','FontSize',14,'ButtonPushedFcn',@previewNetwork);
uibutton(buttons,'Text','Сохранить','FontSize',14,'ButtonPushedFcn',@saveInputs);
uibutton(buttons,'Text','Сохранить и запустить','FontSize',14, ...
    'FontWeight','bold','ButtonPushedFcn',@(~,~) startMain());
inputControls = struct('mu1',mu1,'muRatio',muRatio,'L',L, ...
    'sigma',sigma,'theta',theta,'MeniscusModel',MeniscusModel, ...
    'IncludeAadd',IncludeAadd,'H_P0',H_P0,'GeometryMode',GeometryMode, ...
    'AreaType',AreaType,'RandomMin',RandomMin,'RandomMax',RandomMax, ...
    'RandomN_rows',RandomN_rows,'RandomN_cols',RandomN_cols,'H_A',H_A,'V_A',V_A, ...
    'SaveStepsMode',SaveStepsMode,'SaveEveryN',SaveEveryN, ...
    'VisualizeSatPressure',VisualizeSatPressure,'GifFrameDelay',GifFrameDelay, ...
    'GifShowMeniscus',GifShowMeniscus);
inputNames = fieldnames(inputControls);
savedInputs = struct();
if isfile(settingsFile)
    try
        saved = load(settingsFile);
        savedInputs = saved.inputs;
        if isfield(saved,'previousGeometry')
            previousGeometry = saved.previousGeometry;
        end
    catch exception
        uialert(fig,['Не удалось прочитать сохранённые параметры: ' exception.message],'Ошибка');
    end
elseif isappdata(groot,'capillaryGridRunInputs')
    % При первом сохранении переносим ввод из прежней версии окна.
    savedInputs = getappdata(groot,'capillaryGridRunInputs');
end
for inputIndex = 1:numel(inputNames)
    inputName = inputNames{inputIndex};
    inputControls.(inputName).Tag = inputName;
    if isfield(savedInputs,inputName)
        inputControls.(inputName).Value = savedInputs.(inputName);
    end
end
if isfield(previousGeometry,'Ah') && ~isfield(savedInputs,'GeometryMode')
    GeometryMode.Value = 'Использовать предыдущую';
end
changeAreaType([],[]);
changeGeometryMode([],[]);
changeSaveStepsMode([],[]);
for groupIndex = 1:numel(groupHeaders)
    groupHeaders(groupIndex).Value = true;
    toggleGroup(groupHeaders(groupIndex));
end

% Размер окна под монитор; поля и шрифты сохраняют читаемый размер, есть прокрутка.
rootUnits = get(groot,'Units'); set(groot,'Units','pixels');
monitors = get(groot,'MonitorPositions'); pointer = get(groot,'PointerLocation');
set(groot,'Units',rootUnits);
monitorIndex = find(pointer(1)>=monitors(:,1) & pointer(1)<monitors(:,1)+monitors(:,3) & ...
    pointer(2)>=monitors(:,2) & pointer(2)<monitors(:,2)+monitors(:,4),1);
if isempty(monitorIndex), monitorIndex=1; end
screen = monitors(monitorIndex,:);
windowSize = min([760 820],screen(3:4)-[80 160]);
fig.Position = [screen(1:2)+(screen(3:4)-windowSize)/2,windowSize];
fig.Visible = 'on';

function toggleGroup(header)
    index = header.UserData;
    heights = sections.RowHeight;
    if header.Value
        heights{2*index} = groupHeights(index);
        groupPanels(index).Visible = 'on';
        header.Text = ['▼ ' groupNames{index}];
    else
        heights{2*index} = 0;
        groupPanels(index).Visible = 'off';
        header.Text = ['▶ ' groupNames{index}];
    end
    sections.RowHeight = heights;
end

function ok = saveInputs(~,~,geometryToSave)
    ok = false;
    if nargin < 3, geometryToSave = previousGeometry; end
    inputs = struct();
    for savedIndex = 1:numel(inputNames)
        savedName = inputNames{savedIndex};
        inputs.(savedName) = inputControls.(savedName).Value;
    end
    temporaryFile = [tempname(fileparts(settingsFile)) '.mat'];
    try
        settings = struct('inputs',inputs,'previousGeometry',geometryToSave);
        save(temporaryFile,'-struct','settings');
        [success,message] = movefile(temporaryFile,settingsFile,'f');
        if ~success, error('run:SaveFailed','%s',message); end
        previousGeometry = geometryToSave;
        setappdata(groot,'capillaryGridRunInputs',inputs);
        statusLabel.Text = 'Параметры сохранены.';
        ok = true;
    catch exception
        if isfile(temporaryFile), delete(temporaryFile); end
        uialert(fig,['Не удалось сохранить параметры: ' exception.message],'Ошибка');
    end
end

function changeGeometryMode(~,~)
    if strcmp(GeometryMode.Value,'Использовать предыдущую')
        NewGeometryPanel.Visible = 'off';
        geometryLayout.RowHeight = {30,0};
        groupHeights(2) = 50;
    else
        NewGeometryPanel.Visible = 'on';
        geometryLayout.RowHeight = {30,250};
        groupHeights(2) = 290;
    end
    toggleGroup(groupHeaders(2));
end

function changeAreaType(~,~)
    if strcmp(AreaType.Value,'Случайная')
        RandomPanel.Visible = 'on'; MatrixPanel.Visible = 'off';
        network.RowHeight = {30,200,0};
    else
        RandomPanel.Visible = 'off'; MatrixPanel.Visible = 'on';
        network.RowHeight = {30,0,200};
    end
end

function changeSaveStepsMode(~,~)
    if strcmp(SaveStepsMode.Value,'Сохранять каждый N шаг')
        saveEveryNLabel.Visible = 'on'; SaveEveryN.Visible = 'on';
        resultsGrid.RowHeight = {30,30,30,0,0};
        groupHeights(3) = 130;
    else
        saveEveryNLabel.Visible = 'off'; SaveEveryN.Visible = 'off';
        resultsGrid.RowHeight = {30,0,30,0,0};
        groupHeights(3) = 92;
    end
    if VisualizeSatPressure.Value
        frameDelayLabel.Visible = 'on'; GifFrameDelay.Visible = 'on';
        GifShowMeniscus.Visible = 'on';
        heights = resultsGrid.RowHeight;
        heights{4} = 30; heights{5} = 30;
        resultsGrid.RowHeight = heights;
        groupHeights(3) = groupHeights(3) + 76;
    else
        frameDelayLabel.Visible = 'off'; GifFrameDelay.Visible = 'off';
        GifShowMeniscus.Visible = 'off';
    end
    toggleGroup(groupHeaders(3));
end

%% Формирование Ah и Av

function [Ah, Av, ok] = getGeometry()

    ok = false;
    if strcmp(GeometryMode.Value,'Использовать предыдущую')
        Ah = []; Av = [];
        if ~isfield(previousGeometry,'Ah') || ~isfield(previousGeometry,'Av')
            uialert(fig,'Предыдущая сеть ещё не сохранена. Выберите «Задать новую».','Ошибка');
            return;
        end
        Ah = previousGeometry.Ah;
        Av = previousGeometry.Av;
        ok = true;
        return;
    end

    switch AreaType.Value

        case 'Случайная'

            Amin = RandomMin.Value;
            Amax = RandomMax.Value;

            N_rows = RandomN_rows.Value;
            N_cols = RandomN_cols.Value;


            % Проверка диапазона

            if ~isfinite(Amin) || ...
                    ~isfinite(Amax) || ...
                    Amin <= 0 || ...
                    Amax <= 0 || ...
                    Amin >= Amax

                uialert(fig, ...
                    ['Границы диапазона площадей должны быть ', ...
                     'положительными и удовлетворять условию от < до.'], ...
                    'Ошибка');
                return;

            end


            % Проверка N_rows

            if ~isfinite(N_rows) || ...
                    N_rows < 1 || ...
                    N_rows ~= round(N_rows)

                uialert(fig, ...
                    'Число горизонтальных рядов должно быть положительным целым числом.', ...
                    'Ошибка');
                return;

            end


            % Проверка N_cols

            if ~isfinite(N_cols) || ...
                    N_cols < 1 || ...
                    N_cols ~= round(N_cols)

                uialert(fig, ...
                    'Число вертикальных рядов должно быть положительным целым числом.', ...
                    'Ошибка');
                return;

            end


            N_rows = round(N_rows);
            N_cols = round(N_cols);


            % Геометрия сети

            Ah = Amin + ...
                (Amax - Amin) * rand(N_rows, N_cols + 1);

            Av = Amin + ...
                (Amax - Amin) * rand(N_rows + 1, N_cols);


        % ====================================================
        % Матрица площадей
        % ====================================================

        case 'Матрица площадей'

            % ------------------------------------------------
            % Чтение Ah
            % ------------------------------------------------

            try

                Ah = str2num( ...
                    strjoin(H_A.Value, ' '));

            catch

                uialert(fig, ...
                    'Не удалось прочитать матрицу горизонтальных капилляров.', ...
                    'Ошибка');
                return;

            end


            % ------------------------------------------------
            % Чтение Av
            % ------------------------------------------------

            try

                Av = str2num( ...
                    strjoin(V_A.Value, ' '));

            catch

                uialert(fig, ...
                    'Не удалось прочитать матрицу вертикальных капилляров.', ...
                    'Ошибка');
                return;

            end


            % ------------------------------------------------
            % Проверка на пустые матрицы
            % ------------------------------------------------

            if isempty(Ah)

                uialert(fig, ...
                    'Матрица горизонтальных капилляров пуста.', ...
                    'Ошибка');
                return;

            end


            if isempty(Av)

                uialert(fig, ...
                    'Матрица вертикальных капилляров пуста.', ...
                    'Ошибка');
                return;

            end


            % ------------------------------------------------
            % Проверка значений Ah
            % ------------------------------------------------

            if any(~isfinite(Ah), 'all') || ...
                    any(Ah <= 0, 'all')

                uialert(fig, ...
                    ['Все площади горизонтальных капилляров ', ...
                     'должны быть положительными конечными числами.'], ...
                    'Ошибка');
                return;

            end


            % ------------------------------------------------
            % Проверка значений Av
            % ------------------------------------------------

            if any(~isfinite(Av), 'all') || ...
                    any(Av <= 0, 'all')

                uialert(fig, ...
                    ['Все площади вертикальных капилляров ', ...
                     'должны быть положительными конечными числами.'], ...
                    'Ошибка');
                return;

            end


            % ------------------------------------------------
            % Проверка размерностей
            % ------------------------------------------------

            [N_rows_H, N_cols_H] = size(Ah);
            [N_rows_V, N_cols_V] = size(Av);


            % Av имеет на один ряд больше, чем Ah

            if N_rows_V ~= N_rows_H + 1

                uialert(fig, ...
                    ['Размеры матриц не согласованы.' newline newline ...
                     'Ah: ' num2str(N_rows_H) ' × ' ...
                     num2str(N_cols_H) newline ...
                     'Av: ' num2str(N_rows_V) ' × ' ...
                     num2str(N_cols_V) newline newline ...
                     'Должно выполняться:' newline ...
                     'size(Av,1) = size(Ah,1) + 1'], ...
                    'Ошибка');

                return;

            end


            % Ah имеет на один столбец больше, чем Av

            if N_cols_H ~= N_cols_V + 1

                uialert(fig, ...
                    ['Размеры матриц не согласованы.' newline newline ...
                     'Ah: ' num2str(N_rows_H) ' × ' ...
                     num2str(N_cols_H) newline ...
                     'Av: ' num2str(N_rows_V) ' × ' ...
                     num2str(N_cols_V) newline newline ...
                     'Должно выполняться:' newline ...
                     'size(Ah,2) = size(Av,2) + 1'], ...
                    'Ошибка');

                return;

            end

    end


    ok = true;

end


%% ============================================================
% Предварительный просмотр сети
% ============================================================

function previewNetwork(~, ~)

    if strcmp(GeometryMode.Value,'Использовать предыдущую') || ...
            strcmp(AreaType.Value,'Матрица площадей')
        [Ah, Av, ok] = getGeometry();
        if ~ok, return; end
        N_rows = size(Ah, 1);
        N_cols = size(Av, 2);
    else
        N_rows = RandomN_rows.Value;
        N_cols = RandomN_cols.Value;
    end


    % Проверка размеров

    if ~isfinite(N_rows) || ...
            N_rows < 1 || ...
            N_rows ~= round(N_rows)

        uialert(fig, ...
            'Число горизонтальных рядов должно быть положительным целым числом.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(N_cols) || ...
            N_cols < 1 || ...
            N_cols ~= round(N_cols)

        uialert(fig, ...
            'Число вертикальных рядов должно быть положительным целым числом.', ...
            'Ошибка');
        return;

    end


    N_rows = round(N_rows);
    N_cols = round(N_cols);


    % Отдельная функция отрисовки

    plotNetwork(N_cols, N_rows);

end


%% ============================================================
% Создание Net и запуск main
% ============================================================

function startMain()

    frameDelay = GifFrameDelay.Value;
    showMeniscus = GifShowMeniscus.Value;
    if VisualizeSatPressure.Value && ...
            (~isfinite(frameDelay) || frameDelay < 0.01 || frameDelay > 655)
        uialert(fig,'Время одного кадра должно быть от 0.01 до 655 секунд.','Ошибка');
        return;
    end

    saveStride = 1;
    if strcmp(SaveStepsMode.Value,'Сохранять каждый N шаг')
        saveStride = SaveEveryN.Value;
        if ~isfinite(saveStride) || saveStride < 1 || saveStride ~= fix(saveStride)
            uialert(fig,'N должно быть положительным целым числом.','Ошибка');
            return;
        end
    end

    %% Проверка параметров модели

    if ~isfinite(mu1.Value) || mu1.Value <= 0

        uialert(fig, ...
            'Вязкость воды должна быть положительным числом.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(muRatio.Value) || muRatio.Value <= 0

        uialert(fig, ...
            'Отношение вязкостей должно быть положительным числом.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(L.Value) || L.Value <= 0

        uialert(fig, ...
            'Длина капилляра должна быть положительным числом.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(sigma.Value) || sigma.Value <= 0

        uialert(fig, ...
            'Поверхностное натяжение должно быть положительным числом.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(theta.Value) || ...
            theta.Value <= 0 || theta.Value >= pi

        uialert(fig, ...
            'Для модели плато угол должен быть строго между 0 и π рад.', ...
            'Ошибка');
        return;

    end


    if ~isfinite(H_P0.Value)

        uialert(fig, ...
            'Давление на левой границе должно быть конечным числом.', ...
            'Ошибка');
        return;

    end


    %% Формирование геометрии

    [Ah, Av, ok] = getGeometry();

    if ~ok
        return;
    end
    if ~saveInputs([],[],struct('Ah',Ah,'Av',Av)), return; end


    %% Параметры Net

    Net.H.P0 = H_P0.Value;

    Net.VerticalBC = false; % В run верхняя и нижняя границы всегда закрыты.

    Net.mu1 = mu1.Value;
    Net.mu2 = muRatio.Value * Net.mu1;

    Net.L = L.Value;

    Net.sigma = sigma.Value;
    Net.theta = theta.Value;


    %% Геометрия

    Net.H.A = Ah;
    Net.V.A = Av;


    %% Передача Net в основной workspace

    assignin('base', 'runParameters', Net);
    % Только выбор пользователя; коэффициенты Net применяет сам main.
    assignin('base', 'runModelOptions', struct( ...
        'includeAadd', IncludeAadd.Value, ...
        'meniscusModel', MeniscusModel.Value));
    assignin('base', 'runRecordResults', true);


    %% Запуск main

    simulationStorageOptions('set',saveStride);
    storageCleanup = onCleanup(@() simulationStorageOptions('reset'));
    % main closes the input window: capture the checkbox before calling it.
    createVisualization = VisualizeSatPressure.Value;
    evalin('base', 'main');
    if createVisualization
        completedResult = evalin('base','simulationResult');
        try
            gifPath = writeSaturationPressureGif(completedResult.directory,[],frameDelay,showMeniscus);
            fprintf('GIF сатурации и давления: %s\n',gifPath);
        catch exception
            warning('run:VisualizationFailed', ...
                'Расчёт сохранён, но GIF не создан: %s',exception.message);
        end
    end

    %% Закрытие окна

    if isvalid(fig), delete(fig); end

end

end
