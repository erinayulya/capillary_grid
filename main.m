clear all
%% ---------------- Параметры ----------------
if ~exist('Net', 'var')

    Net.H.P0 = 1500;        % Давление на левой границе, Па
    Net.VerticalBC = false; % Верхняя и нижняя границы проницаемы
    Net.V.P0 = 200;         % Па
    
    Net.mu1 = 1e-3;        % Вязкость воды, Па*с
    Net.mu2 = 4.3*Net.mu1; % Вязкость нефти, Па*
    
    Net.L = 9e-3;          % Длина одного капилляра, м
    
    Net.sigma = 7e-2;      % Поверхностное натяжение, Н/м
    Net.theta = pi/4;      % Угол смачивания, рад
    
    %% ----------- Площади капилляров ------------
    
    coef = pi*(100e-6)^2;
    Net.H.A = coef*[... % Площади горизонтальных капилляров, м2
        1 1 1 1;
        1 2 1 1;
        1 3 1 1];

    Net.V.A = coef*[... % Площади вертикальных капилляров, м2
        1 1 1;
        1 1 1;
        1 1 1;
        1 1 1];
end

Net.kdyn = 2;
Net.bound = 2;

%% ---------- Размер сети --------------------
Net.H.Nx = size(Net.H.A, 2);
Net.H.Ny = size(Net.H.A, 1);

Net.V.Nx = size(Net.V.A, 2);
Net.V.Ny = size(Net.V.A, 1);

%% ---------- Начальные сатурации ------------

Net.H.Sat = zeros(size(Net.H.A));
Net.V.Sat = zeros(size(Net.V.A));

%% ---------- Начальные состояния ------------

Net.H.State = zeros(size(Net.H.A));
Net.V.State = zeros(size(Net.V.A));

Net.H.State(:,1)=1;

%% ---------- Начальные move ------------------

Net.H.Move = zeros(size(Net.H.A));
Net.V.Move = zeros(size(Net.V.A));

Net.H.Move(:,1)=1;

%% ---------- Начальные направления ------------------

Net.H.Dir = zeros(size(Net.H.A));
Net.V.Dir = zeros(size(Net.V.A));

Net.H.Dir(:,1)=1;

%% ---------- Начальные режимы ----------------

Net.H.Regime = zeros(size(Net.H.A));
Net.V.Regime = zeros(size(Net.V.A));

Net.H.Regime(:,1) = 3;

%% ---------- Первый расчет ------------------

Net = updatePressureFlow(Net);

Net = calcTimeStep(Net);

drawNetwork(Net);

%% ---------- Основной цикл ------------------

while true

    if any(Net.H.State(:,end)==2)

        disp('Вторая фаза достигла правой границы.')
        break

    end    

    answer = questdlg(...
        sprintf('Следующий шаг\n dt = %.5e c',Net.dt),...
        'Расчет',...
        'Продолжить','Стоп','Продолжить');

    if strcmp(answer,'Стоп')
        break
    end

    % Значения с предыдущего шага для графиков
    Net.H.Sat_prev = Net.H.Sat;
    Net.V.Sat_prev = Net.V.Sat;
    Net.H.State_prev = Net.H.State;
    Net.V.State_prev = Net.V.State;

    % Основной расчет
    Net = calcSaturation(Net);

    Net = calcState(Net);

    Net = updatePressureFlow(Net);

    Net = calcTimeStep(Net);

    drawNetwork(Net,true);

end
