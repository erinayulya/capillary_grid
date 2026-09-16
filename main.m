setupProject;
%% -------- Режим расчёта --------------------
recordResults = false; % true: посчитать без диалогов и записать PDF и MAT
% Кнопка интерфейса задаёт режим только для текущего запуска.
if exist('runRecordResults','var')
    recordResults = runRecordResults;
    clear runRecordResults
end
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

if ~isfield(Net.V,'P0')
    Net.V.P0 = 200; % Давление сверху при открытых границах, Па
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
[Net, simulationResult] = simulateNetwork(Net, recordResults);
