setupProject;
resetSimulationWorkspace;
%% ---------------- Параметры ----------------
if ~exist('Net', 'var')

    Net.H.P0 = 1500;        % Давление на левой границе, Па
    Net.VerticalBC = false; % Верхняя и нижняя границы закрыты
    Net.V.P0 = 200;         % Па

    Net.mu1 = 1e-3;        % Вязкость воды, Па*с
    Net.mu2 = 4.3*Net.mu1; % Вязкость нефти, Па*

    Net.L = 9e-3;          % Длина одного капилляра, м

    Net.sigma = 7e-2;      % Поверхностное натяжение, Н/м
    Net.theta = pi/4;      % Угол смачивания, рад

    %% ----------- Площади капилляров ------------

    areaScale = pi*(100e-6)^2; % Диаметры сети: 0.2–0.447 мм
    Net.H.A = areaScale*[... % Площади горизонтальных капилляров, м2
        1 1 1 1;
        1 2 1 1;
        1 1 1 1];

    Net.V.A = areaScale*[... % Площади вертикальных капилляров, м2
        1 1 1;
        1 1 1;
        1 5 1;
        1 1 1];
end

% Параметры новой физики задаются только здесь, в том числе при запуске run.
Net.k = 3.29015;                   % Безразмерный коэффициент плато
Net.coef = 6.644123616564944e-4;    % P_crit=coef*r^(-5/4), Па*м^(5/4)
Net.xi = 30.079341699546497;        % A_add=xi*(mu1+mu2)/r, безразмерный
Net.P_crit_width = 4;              % Полная ширина переходной зоны, Па
obsoleteFields = intersect(fieldnames(Net),{'kdyn','bound'});
if ~isempty(obsoleteFields), Net = rmfield(Net,obsoleteFields); end
if ~isfield(Net.V,'P0'), Net.V.P0 = 200; end

% Область применимости физики: диаметры 0.1–1 мм включительно.
diameters = 2*sqrt([Net.H.A(:); Net.V.A(:)]/pi);
diameterTolerance = 16*eps(1e-3); % Допуск округления на границах, м
if any(diameters < 0.1e-3-diameterTolerance | diameters > 1e-3+diameterTolerance)
    warning('capillary_grid:DiameterOutOfRange', ...
        'Расчет рассчитан для капилляров диаметром от 0.1 до 1 мм');
end

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

% Направления менисков нужны текущим функциям модели.
Net.H.Dir = zeros(size(Net.H.State));
Net.V.Dir = zeros(size(Net.V.State));
Net.H.Dir(:,1) = 1;

%% ---------- Начальные режимы ----------------

Net.H.Regime = zeros(size(Net.H.State));
Net.V.Regime = zeros(size(Net.V.State));

Net.H.Regime(:,1) = 3;

%% ---------- Первый расчет ------------------
recordResults = exist('runRecordResults','var') && runRecordResults;
clear runRecordResults
simulationReport('start',Net,recordResults);

try
Net = solvePressureFlow(Net);

Net = calcTimeStep(Net);

simulationReport('snapshot',Net);

%% ---------- Основной цикл ------------------

while true

    if any(Net.H.State(:,end)==2)

        break

    end

    answer = simulationReport('next',Net);

    if strcmp(answer,'Стоп')
        break
    end

    % Значения с предыдущего шага для графиков
    Net.H.Sat_prev = Net.H.Sat;
    Net.V.Sat_prev = Net.V.Sat;
    Net.H.State_prev = Net.H.State;
    Net.V.State_prev = Net.V.State;
    Net.H.Dir_prev = Net.H.Dir;
    Net.V.Dir_prev = Net.V.Dir;

    % Основной расчет
    Net = calcSaturation(Net);

    Net = calcState(Net);

    Net = calcCanMove(Net);

    Net = solvePressureFlow(Net);

    Net = calcTimeStep(Net);

    simulationReport('snapshot',Net);

end
catch exception
    [simulationResult,Net] = simulationReport('fail',Net,exception);
    rethrow(exception);
end

simulationResult = simulationReport('finish',Net);
