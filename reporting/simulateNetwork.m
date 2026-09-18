function [Net, result] = simulateNetwork(Net, recordResults, outputRoot, maxSteps)
%SIMULATENETWORK Run an initialized network interactively or save a report.
% dtUsed is the accepted elapsed interval; Net.dt is the NEXT interval.
if nargin < 3
    outputRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))),'results');
end
if nargin < 4
    maxSteps = 10000;
end
validateattributes(maxSteps, {'numeric'}, {'scalar','integer','positive','finite'});
result = struct('startedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
    'totalTime',0,'totalComputeTime',0,'failedComputeTime',0, ...
    'steps',0,'status','','directory','','pdf','');
parameters = Net;
if recordResults
    if ~isfolder(outputRoot), mkdir(outputRoot); end
    [~,uniqueName] = fileparts(tempname(outputRoot));
    result.directory = fullfile(outputRoot, ...
        ['run_' datestr(now,'yyyymmdd_HHMMSS') '_' uniqueName]);
    mkdir(result.directory);
    save(fullfile(result.directory,'parameters.mat'),'parameters');
end
failure = [];
computeTimer = [];
try
    computeTimer = tic;
    Net = solvePressureFlow(Net);
    Net = calcTimeStep(Net);
    stepComputeTime = toc(computeTimer);
    computeTimer = [];
    result.totalComputeTime = stepComputeTime;
    if recordResults
        saveStep(Net,result,0,stepComputeTime);
    else
        drawNetwork(Net);
    end
    while true
        if any(Net.H.State(:,end)==2)
            result.status = 'Вторая фаза достигла правой границы.';
            break
        end
        if recordResults && (~isfinite(Net.dt) || Net.dt <= 0)
            result.status = 'Остановка: нет конечного положительного шага dt.';
            break
        end
        if recordResults && result.steps >= maxSteps
            result.status = sprintf('Остановка: достигнут лимит %d шагов.',maxSteps);
            break
        end
        if ~recordResults
            answer = questdlg(sprintf('Следующий шаг\n dt = %.5e c',Net.dt), ...
                'Расчет','Продолжить','Стоп','Продолжить');
            if ~strcmp(answer,'Продолжить')
                result.status = 'Остановлено пользователем.';
                break
            end
        end
        computeTimer = tic;
        dtUsed = Net.dt;
        candidate = Net;
        for orientation = {'H','V'}
            key = orientation{1};
            candidate.(key).Sat_prev = Net.(key).Sat;
            candidate.(key).State_prev = Net.(key).State;
            candidate.(key).Dir_prev = Net.(key).Dir;
        end
        candidate = calcSaturation(candidate);
        candidate = calcState(candidate);
        candidate = calcCanMove(candidate);
        candidate = calcRegime(candidate);
        candidate = solvePressureFlow(candidate);
        candidate = calcTimeStep(candidate);
        Net = candidate;
        stepComputeTime = toc(computeTimer);
        computeTimer = [];
        result.totalComputeTime = result.totalComputeTime + stepComputeTime;
        result.steps = result.steps + 1;
        result.totalTime = result.totalTime + dtUsed;
        if recordResults
            saveStep(Net,result,dtUsed,stepComputeTime);
        else
            drawNetwork(Net,true);
        end
    end
catch exception
    if ~isempty(computeTimer)
        result.failedComputeTime = toc(computeTimer);
        result.totalComputeTime = result.totalComputeTime + result.failedComputeTime;
    end
    if ~recordResults, rethrow(exception); end
    result.status = ['Ошибка расчёта: ' exception.message];
    failure = exception;
end
if recordResults
    save(fullfile(result.directory,'summary.mat'),'result','parameters','Net');
    result.pdf = writeSimulationReport(result.directory);
    save(fullfile(result.directory,'summary.mat'),'result','parameters','Net');
    fprintf('Результаты: %s\n',result.directory);
end
disp(result.status);
if ~isempty(failure), rethrow(failure); end
end

function saveStep(Net,result,dtUsed,stepComputeTime)
step = result.steps;
elapsedTime = result.totalTime;
totalComputeTime = result.totalComputeTime;
save(fullfile(result.directory,sprintf('step_%06d.mat',step)), ...
    'Net','step','dtUsed','elapsedTime','stepComputeTime','totalComputeTime');
end
