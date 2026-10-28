function resume = prepareSimulationResume(directory)
%PREPARESIMULATIONRESUME Read the latest valid solved snapshot without writes.
% Returns the original state/parameters, cumulative counters, saved stride and
% a fresh step budget. Does not run the model or change the source results.
directory = char(directory);
metadata = struct();
try
    metadata = load(fullfile(directory,'summary.mat'),'result','parameters');
catch
    % A crash may leave summary.mat incomplete; step files remain independent.
end
files = dir(fullfile(directory,'step_*.mat'));
tokens = regexp({files.name},'^step_(\d+)\.mat$','tokens','once');
valid = ~cellfun('isempty',tokens);
files = files(valid); tokens = tokens(valid);
numbers = cellfun(@(token) str2double(token{1}),tokens);
[numbers,order] = sort(numbers,'descend'); files = files(order);
skipped = {};
selected = [];
for index = 1:numel(files)
    file = fullfile(directory,files(index).name);
    try
        snapshot = loadSimulationStep(file);
        validateSnapshot(snapshot,numbers(index));
        selected = index;
        break;
    catch
        skipped{end+1} = files(index).name; %#ok<AGROW>
    end
end
if isempty(selected)
    error('prepareSimulationResume:NoSnapshot', ...
        'В последнем расчёте нет исправного снимка с полным состоянием сети.');
end
if isfield(metadata,'parameters') && isstruct(metadata.parameters)
    parameters = metadata.parameters;
else
    try
        original = load(fullfile(directory,'parameters.mat'),'parameters');
        parameters = original.parameters;
    catch
        parameters = snapshot.solvedNet;
    end
end
result = struct();
if isfield(metadata,'result') && isstruct(metadata.result) && isscalar(metadata.result)
    result = metadata.result;
end
saveStride = 1;
if isfield(snapshot,'saveStride') && validStride(snapshot.saveStride)
    saveStride = snapshot.saveStride;
elseif isfield(result,'saveStride') && validStride(result.saveStride)
    saveStride = result.saveStride;
else
    positive = sort(numbers(numbers > 0 & numbers <= snapshot.step));
    if numel(positive) > 1, saveStride = positive(1); end
end
result.steps = snapshot.step;
result.totalTime = snapshot.elapsedTime;
result.totalComputeTime = 0;
if isfield(snapshot,'totalComputeTime') && isnumeric(snapshot.totalComputeTime) && ...
        isscalar(snapshot.totalComputeTime) && isreal(snapshot.totalComputeTime) && ...
        isfinite(snapshot.totalComputeTime) && snapshot.totalComputeTime >= 0
    result.totalComputeTime = snapshot.totalComputeTime;
end
result.saveStride = saveStride;
stationarity = [];
if isfield(snapshot,'stationarity') && isstruct(snapshot.stationarity) && ...
        isscalar(snapshot.stationarity) && ...
        all(isfield(snapshot.stationarity,{'reached','justReached','stop','confirm', ...
        'time','previousDt','breakthroughTime','reference','referenceTime','stableSteps', ...
        'saturationChange','pressureChange','saturationTolerance', ...
        'pressureAbsoluteTolerance','pressureRelativeTolerance','minimumTime','minimumSteps'}))
    stationarity = snapshot.stationarity;
end
maxSteps = snapshot.step+10000*saveStride;
validateattributes(maxSteps,{'numeric'},{'scalar','real','finite','integer','positive'});
history = files(numbers <= snapshot.step);
[~,historyOrder] = sort(numbers(numbers <= snapshot.step));
resume = struct('directory',directory,'snapshotFile',fullfile(directory,files(selected).name), ...
    'snapshot',snapshot,'parameters',parameters,'result',result, ...
    'stationarity',stationarity,'saveStride',saveStride,'maxSteps',maxSteps, ...
    'historyFiles',{ {history(historyOrder).name} },'skippedSnapshots',{skipped});
end

function yes = validStride(value)
yes = isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) && ...
    value >= 1 && value == fix(value);
end

function validateSnapshot(snapshot,number)
if ~all(isfield(snapshot,{'solvedNet','step','elapsedTime','dtUsed'}))
    error('prepareSimulationResume:Snapshot','Неполный снимок расчёта.');
end
validateattributes(snapshot.step,{'numeric'},{'scalar','real','finite','integer','nonnegative'});
assert(snapshot.step == number,'prepareSimulationResume:Step','Номер снимка не совпадает с именем файла.');
validateattributes(snapshot.elapsedTime,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(snapshot.dtUsed,{'numeric'},{'scalar','real','finite','nonnegative'});
N = snapshot.solvedNet;
required = {'H','V','P','dt','mu1','mu2','L','sigma','theta','VerticalBC','k','xi','coef','P_crit_width'};
assert(isstruct(N) && isscalar(N) && all(isfield(N,required)), ...
    'prepareSimulationResume:Model','Снимок не содержит состояние текущей расчётной модели.');
for field = {'mu1','mu2','L','sigma','k'}
    validateattributes(N.(field{1}),{'numeric'},{'scalar','real','finite','positive'});
end
for field = {'xi','coef','P_crit_width'}
    validateattributes(N.(field{1}),{'numeric'},{'scalar','real','finite','nonnegative'});
end
validateattributes(N.theta,{'numeric'},{'scalar','real','finite','>',0,'<',pi});
validateattributes(N.VerticalBC,{'numeric','logical'},{'scalar','real','finite','binary'});
validateattributes(N.dt,{'numeric'},{'scalar','real','positive'});
assert(~isnan(N.dt),'prepareSimulationResume:TimeStep','Некорректный dt в снимке.');
for key = 'HV'
    C = N.(key);
    assert(isstruct(C) && isscalar(C) && ...
        all(isfield(C,{'A','Nx','Ny','P0','Sat','State','Dir','Move','Regime','Q'})), ...
        'prepareSimulationResume:Capillaries','Неполные данные капилляров.');
    validateattributes(C.A,{'numeric'},{'real','2d','nonempty','finite','positive'});
    assert(isequal(size(C.A),[C.Ny C.Nx]),'prepareSimulationResume:Size','Неверные размеры сети.');
    validateattributes(C.P0,{'numeric'},{'scalar','real','finite'});
    validateattributes(C.Sat,{'numeric'},{'real','finite','size',size(C.A),'>=',0,'<=',1});
    validateattributes(C.State,{'numeric'},{'real','finite','integer','size',size(C.A),'>=',0,'<=',2});
    validateattributes(C.Move,{'numeric'},{'real','finite','integer','size',size(C.A),'>=',0,'<=',3});
    validateattributes(C.Dir,{'numeric'},{'real','finite','integer','size',size(C.A),'>=',-1,'<=',1});
    validateattributes(C.Regime,{'numeric'},{'real','finite','integer','size',size(C.A),'>=',0,'<=',3});
    validateattributes(C.Q,{'numeric'},{'real','finite','size',size(C.A)});
end
assert(N.V.Ny == N.H.Ny+1 && N.H.Nx == N.V.Nx+1, ...
    'prepareSimulationResume:Size','Матрицы горизонтальных и вертикальных капилляров не согласованы.');
validateattributes(N.P,{'numeric'},{'real','finite','size',[N.H.Ny N.V.Nx]});
end
