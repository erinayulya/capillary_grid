clear all
%% ---------------- Параметры ----------------

Net.H.P0 = 200;          % Па
Net.V.P0 = 0;          % Па

Net.mu1 = 1e-3;        % Па*с
Net.mu2 = 4.3*Net.mu1;

Net.L = 9e-3;          % м

Net.sigma = 7e-2;      % Н/м
Net.theta = pi/4;      % рад

Net.kdyn = 2;

%% ----------- Площади капилляров ------------

Net.H.A = [...
    5 1 1 0.1;
    1 0.1 5 1;
    0.1 1 1 5]*1e-3;

Net.V.A = [...
    10 1 1;
    10 1 1;
    10 1 1;
    1 0.1 1]*1e-3;

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

Net.H.Move = zeros(size(Net.H.State));
Net.V.Move = zeros(size(Net.V.State));

Net.H.Move(:,1)=1;

%% ---------- Начальные режимы ----------------

Net.H.Regime = zeros(size(Net.H.State));
Net.V.Regime = zeros(size(Net.V.State));

Net.H.Regime(:,1) = 1;

%% ---------- Первый расчет ------------------

Net = solvePressureFlow(Net);

Net = calcRegime(Net);

Net = calcCanMove(Net);

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

    Net = calcRegime(Net);

    Net = solvePressureFlow(Net);

    Net = calcCanMove(Net);

    Net = calcTimeStep(Net);

    drawNetwork(Net);

end