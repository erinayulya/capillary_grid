function run

%% ============================================================
% Окно
% ============================================================

fig = uifigure( ...
    'Name', 'Параметры расчёта', ...
    'Position', [400 50 700 850]);


%% ============================================================
% Параметры модели
% ============================================================

uilabel(fig, ...
    'Position', [40 800 400 30], ...
    'Text', 'Параметры модели', ...
    'FontSize', 20, ...
    'FontWeight', 'bold');


% ------------------------------------------------------------
% Вязкость воды
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 750 380 30], ...
    'Text', 'Вязкость воды μ₁, Па·с', ...
    'FontSize', 15);

mu1 = uieditfield(fig, 'numeric', ...
    'Position', [480 750 170 30], ...
    'Value', 1e-3, ...
    'FontSize', 15);


% ------------------------------------------------------------
% Отношение вязкостей
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 700 400 45], ...
    'Text', {'Во сколько раз вязкость нефти', ...
             'больше вязкости воды μ₂ / μ₁'}, ...
    'FontSize', 15);

muRatio = uieditfield(fig, 'numeric', ...
    'Position', [480 705 170 30], ...
    'Value', 4.3, ...
    'FontSize', 15);


% ------------------------------------------------------------
% Длина капилляра
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 650 380 30], ...
    'Text', 'Длина капилляра L, м', ...
    'FontSize', 15);

L = uieditfield(fig, 'numeric', ...
    'Position', [480 650 170 30], ...
    'Value', 9e-3, ...
    'FontSize', 15);


% ------------------------------------------------------------
% Поверхностное натяжение
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 600 400 30], ...
    'Text', 'Поверхностное натяжение σ, Н/м', ...
    'FontSize', 15);

sigma = uieditfield(fig, 'numeric', ...
    'Position', [480 600 170 30], ...
    'Value', 7e-2, ...
    'FontSize', 15);


% ------------------------------------------------------------
% Угол смачивания
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 550 380 30], ...
    'Text', 'Угол смачивания θ, рад', ...
    'FontSize', 15);

theta = uieditfield(fig, 'numeric', ...
    'Position', [480 550 170 30], ...
    'Value', pi/4, ...
    'FontSize', 15);


%% ============================================================
% Граничные условия
% ============================================================

uilabel(fig, ...
    'Position', [40 495 400 30], ...
    'Text', 'Граничные условия', ...
    'FontSize', 20, ...
    'FontWeight', 'bold');


% ------------------------------------------------------------
% Давление на левой границе
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 445 400 30], ...
    'Text', 'Давление на левой границе P₀, Па', ...
    'FontSize', 15);

H_P0 = uieditfield(fig, 'numeric', ...
    'Position', [480 445 170 30], ...
    'Value', 100, ...
    'FontSize', 15);


% ------------------------------------------------------------
% Верхняя и нижняя границы
% ------------------------------------------------------------

VerticalBC = uicheckbox(fig, ...
    'Position', [40 395 600 30], ...
    'Text', 'Верхняя и нижняя граница проницаемы', ...
    'Value', false, ...
    'FontSize', 15);


%% ============================================================
% Геометрия сети
% ============================================================

uilabel(fig, ...
    'Position', [40 345 400 30], ...
    'Text', 'Геометрия сети', ...
    'FontSize', 20, ...
    'FontWeight', 'bold');


% ------------------------------------------------------------
% Способ задания площади
% ------------------------------------------------------------

uilabel(fig, ...
    'Position', [40 300 300 30], ...
    'Text', 'Площадь капилляров', ...
    'FontSize', 15);

AreaType = uidropdown(fig, ...
    'Position', [480 300 170 30], ...
    'Items', {'Одинакова', 'Случайная', 'Матрица значений'}, ...
    'Value', 'Одинакова', ...
    'FontSize', 15, ...
    'ValueChangedFcn', @changeAreaType);


%% ============================================================
% Одинаковая площадь
% ============================================================

SamePanel = uipanel(fig, ...
    'Position', [30 90 640 190], ...
    'BorderType', 'none');


% Площадь капилляра

uilabel(SamePanel, ...
    'Position', [10 135 400 30], ...
    'Text', 'Площадь капилляра A, м²', ...
    'FontSize', 15);

SameA = uieditfield(SamePanel, 'numeric', ...
    'Position', [450 135 170 30], ...
    'Value', 1e-6, ...
    'FontSize', 15);


% Число горизонтальных рядов

uilabel(SamePanel, ...
    'Position', [10 85 400 30], ...
    'Text', 'Число горизонтальных рядов капилляров', ...
    'FontSize', 15);

SameN_rows = uieditfield(SamePanel, 'numeric', ...
    'Position', [450 85 170 30], ...
    'Value', 3, ...
    'FontSize', 15);


% Число вертикальных рядов

uilabel(SamePanel, ...
    'Position', [10 35 400 30], ...
    'Text', 'Число вертикальных рядов капилляров', ...
    'FontSize', 15);

SameN_cols = uieditfield(SamePanel, 'numeric', ...
    'Position', [450 35 170 30], ...
    'Value', 3, ...
    'FontSize', 15);


%% ============================================================
% Случайная площадь
% ============================================================

RandomPanel = uipanel(fig, ...
    'Position', [30 90 640 190], ...
    'BorderType', 'none', ...
    'Visible', 'off');


% Диапазон площадей

uilabel(RandomPanel, ...
    'Position', [10 135 400 30], ...
    'Text', 'Диапазон площадей [от, до], м²', ...
    'FontSize', 15);

RandomMin = uieditfield(RandomPanel, 'numeric', ...
    'Position', [450 135 80 30], ...
    'Value', 0.5e-6, ...
    'FontSize', 15);

RandomMax = uieditfield(RandomPanel, 'numeric', ...
    'Position', [540 135 80 30], ...
    'Value', 1.5e-6, ...
    'FontSize', 15);


% Число горизонтальных рядов

uilabel(RandomPanel, ...
    'Position', [10 85 400 30], ...
    'Text', 'Число горизонтальных рядов капилляров', ...
    'FontSize', 15);

RandomN_rows = uieditfield(RandomPanel, 'numeric', ...
    'Position', [450 85 170 30], ...
    'Value', 3, ...
    'FontSize', 15);


% Число вертикальных рядов

uilabel(RandomPanel, ...
    'Position', [10 35 400 30], ...
    'Text', 'Число вертикальных рядов капилляров', ...
    'FontSize', 15);

RandomN_cols = uieditfield(RandomPanel, 'numeric', ...
    'Position', [450 35 170 30], ...
    'Value', 3, ...
    'FontSize', 15);


%% ============================================================
% Матрицы площадей
% ============================================================

MatrixPanel = uipanel(fig, ...
    'Position', [20 50 660 230], ...
    'BorderType', 'none', ...
    'Visible', 'off');


% Горизонтальные капилляры

uilabel(MatrixPanel, ...
    'Position', [10 175 300 45], ...
    'Text', {'Матрица площадей', ...
             'горизонтальных капилляров A, м²'}, ...
    'FontSize', 14);

H_A = uitextarea(MatrixPanel, ...
    'Position', [10 65 280 100], ...
    'Value', { ...
        '[1 1 1 1;', ...
        ' 1 2 1 1;', ...
        ' 1 1 1 1]*1e-6'}, ...
    'FontSize', 13);


% Вертикальные капилляры

uilabel(MatrixPanel, ...
    'Position', [350 175 300 45], ...
    'Text', {'Матрица площадей', ...
             'вертикальных капилляров A, м²'}, ...
    'FontSize', 14);

V_A = uitextarea(MatrixPanel, ...
    'Position', [350 65 280 100], ...
    'Value', { ...
        '[1 1 1;', ...
        ' 1 1 1;', ...
        ' 1 5 1;', ...
        ' 1 1 1]*1e-6'}, ...
    'FontSize', 13);


%% ============================================================
% Кнопки
% ============================================================

uibutton(fig, ...
    'Position', [80 10 250 45], ...
    'Text', 'Нарисовать', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @previewNetwork);


uibutton(fig, ...
    'Position', [370 10 250 45], ...
    'Text', 'Задать и запустить', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @startMain);


%% ============================================================
% Изменение способа задания площади
% ============================================================

function changeAreaType(~, ~)

    switch AreaType.Value

        case 'Одинакова'

            SamePanel.Visible = 'on';
            RandomPanel.Visible = 'off';
            MatrixPanel.Visible = 'off';

        case 'Случайная'

            SamePanel.Visible = 'off';
            RandomPanel.Visible = 'on';
            MatrixPanel.Visible = 'off';

        case 'Матрица значений'

            SamePanel.Visible = 'off';
            RandomPanel.Visible = 'off';
            MatrixPanel.Visible = 'on';

    end

end


%% ============================================================
% Формирование Ah и Av
% ============================================================

function [Ah, Av, ok] = getGeometry()

    ok = false;

    switch AreaType.Value

        % ====================================================
        % Одинаковая площадь
        % ====================================================

        case 'Одинакова'

            A = SameA.Value;

            N_rows = SameN_rows.Value;
            N_cols = SameN_cols.Value;


            % Проверка площади

            if ~isfinite(A) || A <= 0

                uialert(fig, ...
                    'Площадь капилляра должна быть положительным числом.', ...
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


            % Геометрия сети:
            %
            % Ah = N_rows × (N_cols + 1)
            % Av = (N_rows + 1) × N_cols

            Ah = A * ones(N_rows, N_cols + 1);

            Av = A * ones(N_rows + 1, N_cols);


        % ====================================================
        % Случайная площадь
        % ====================================================

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
        % Матрица значений
        % ====================================================

        case 'Матрица значений'

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

    switch AreaType.Value

        case 'Одинакова'

            N_rows = SameN_rows.Value;
            N_cols = SameN_cols.Value;


        case 'Случайная'

            N_rows = RandomN_rows.Value;
            N_cols = RandomN_cols.Value;


        case 'Матрица значений'

            [Ah, Av, ok] = getGeometry();

            if ~ok
                return;
            end

            % Определяем размеры сети из матриц

            N_rows = size(Ah, 1);
            N_cols = size(Av, 2);

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

function startMain(~, ~)

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
            theta.Value < 0 || theta.Value > pi

        uialert(fig, ...
            'Угол смачивания должен быть от 0 до π рад.', ...
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


    %% Параметры Net

    Net.H.P0 = H_P0.Value;

    Net.VerticalBC = VerticalBC.Value;

    Net.mu1 = mu1.Value;
    Net.mu2 = muRatio.Value * Net.mu1;

    Net.L = L.Value;

    Net.sigma = sigma.Value;
    Net.theta = theta.Value;


    %% Геометрия

    Net.H.A = Ah;
    Net.V.A = Av;


    %% Передача Net в основной workspace

    assignin('base', 'Net', Net);


    %% Запуск main

    evalin('base', 'main');


    %% Закрытие окна

    delete(fig);

end

end