clear all
%% ---------------- Параметры ----------------

Net.P0 = 200;          % Па

Net.mu1 = 1e-3;        % Па*с
Net.k   = 4.3;
Net.mu2 = Net.k*Net.mu1;

Net.L = 9e-3;          % м

Net.sigma = 7e-2;      % Н/м
Net.theta = pi/4;      % рад

Net.kdyn = 2;

%% ----------- Площади капилляров ------------

Net.Ah = [...
    5 1 1 0.1;
    1 0.1 5 1;
    0.1 1 1 5]*1e-3;

Net.Av = [...
    10 1 1;
    1 0.1 1]*1e-3;

%Net.Ah = [...
%    1 1 1 1 1;
%    1 0.1 1 1 10;
%    1 0.1 1 1 1;
%    10 1 1 1 1]*1e-3;

%Net.Av = [...
%    1 1 1 10;
%    0.1 0.1 1 1;
%    1 1 1 1]*1e-3;

%Net.Ah = 1e-3*(1+rand(7, 8));
%Net.Av = 1e-3*(1+rand(6, 7));

%% ---------- Размер сети --------------------

[Ny,Nx] = size(Net.Ah);

Net.Nx = Nx;
Net.Ny = Ny;

%% ---------- Начальные сатурации ------------

Net.SatH = zeros(size(Net.Ah));
Net.SatV = zeros(size(Net.Av));

%% ---------- Начальные состояния ------------

Net.StateH = zeros(size(Net.Ah));
Net.StateV = zeros(size(Net.Av));

Net.StateH(:,1)=1;

%% ---------- Начальные move ------------------

Net.MoveH = zeros(size(Net.StateH));
Net.MoveV = zeros(size(Net.StateV));

Net.MoveH(:,1)=1;

%% ---------- Начальные режимы ----------------

Net.RegimeH = zeros(size(Net.StateH));
Net.RegimeV = zeros(size(Net.StateV));

Net.RegimeH(:,1) = 1;

%% ---------- Первый расчет ------------------

Net = solvePressureFlow(Net);

Net = calcRegime(Net);

Net = calcCanMove(Net);

Net = calcTimeStep(Net);

drawNetwork(Net);

%% ---------- Основной цикл ------------------

while true

    if any(Net.StateH(:,end)==2)

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
    Net.SatH_prev = Net.SatH;
    Net.SatV_prev = Net.SatV;
    Net.StateH_prev = Net.StateH;
    Net.StateV_prev = Net.StateV;

    % Основной расчет
    Net = calcSaturation(Net);

    Net = calcState(Net);

    Net = calcRegime(Net);

    Net = solvePressureFlow(Net);

    Net = calcCanMove(Net);

    Net = calcTimeStep(Net);

    drawNetwork(Net);

    Net.Qh

    Net.Qv

end