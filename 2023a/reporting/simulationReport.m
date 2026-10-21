function [output, restoredNet] = simulationReport(action, Net, options, outputRoot, maxSteps)
%SIMULATIONREPORT Record states/timing and show calculation progress.
% Does not modify Net, call model/solver functions, or execute simulation steps.
% start: options is recordResults. fail: options is the original MException.
% next/finish: optional checkSteadyState monitor (outside Net).
% fail returns the last accepted Net as its second output; no model calls.
% One active reporting session; every start resets its state.
% MAT stride is consumed once from simulationStorageOptions; default is 1.
persistent session
output = [];
restoredNet = Net;
switch action
    case 'start'
        if nargin < 3, options = false; end
        recordResults = options;
        if nargin < 4
            outputRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))),'results');
        end
        if nargin < 5, maxSteps = 10000; end
        validateattributes(recordResults,{'logical'},{'scalar'});
        validateattributes(maxSteps,{'numeric'},{'scalar','integer','positive','finite'});
        saveStride = simulationStorageOptions('take');
        session = struct('recordResults',recordResults,'maxSteps',maxSteps, ...
            'parameters',Net,'lastNet',Net,'snapshots',0,'dtUsed',0,'timer',[], ...
            'lastStepComputeTime',[],'lastDtUsed',0,'lastTotalComputeTime',0, ...
            'lastSavedStep',-1,'progress',[]);
        session.result = struct('startedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
            'totalTime',0,'totalComputeTime',0,'failedComputeTime',0, ...
            'steps',0,'status','Расчёт не завершён.','directory','','pdf','', ...
            'saveStride',saveStride);
        if recordResults
            session.progress = printSimulationProgress('start',session.result,[],[],[],Net);
            if ~isfolder(outputRoot), mkdir(outputRoot); end
            baseName = ['run_' datestr(now,'yyyymmdd_HHMMSS')];
            session.result.directory = fullfile(outputRoot,baseName);
            suffix = 2;
            while isfolder(session.result.directory) || isfile(session.result.directory)
                session.result.directory = fullfile(outputRoot, ...
                    sprintf('%s_%d',baseName,suffix));
                suffix = suffix + 1;
            end
            mkdir(session.result.directory);
            parameters = Net;
            save(fullfile(session.result.directory,'parameters.mat'),'parameters');
        end
        [session.result,session.timer] = measureComputeTime('start',session.result);
    case 'snapshot'
        requireSession(session);
        [session.result,session.timer,seconds] = ...
            measureComputeTime('stop',session.result,session.timer);
        session.result.steps = session.snapshots;
        session.result.totalTime = session.result.totalTime + session.dtUsed;
        session.lastNet = Net;
        session.lastStepComputeTime = seconds;
        session.lastDtUsed = session.dtUsed;
        session.lastTotalComputeTime = session.result.totalComputeTime;
        if session.recordResults
            if mod(session.result.steps,session.result.saveStride) == 0
                session = saveLastStep(session);
            end
            saveSummary(session,Net);
        else
            drawNetwork(Net,session.result.steps > 0);
        end
        session.snapshots = session.snapshots + 1;
    case 'next'
        requireSession(session);
        confirm = nargin >= 3 && isstruct(options) && ...
            isfield(options,'confirm') && options.confirm;
        if session.recordResults && (~isfinite(Net.dt) || Net.dt <= 0) && ~confirm
            session.result.status = 'Остановка: нет конечного положительного шага dt.';
            output = 'Стоп';
        elseif session.recordResults && session.result.steps >= session.maxSteps
            session.result.status = sprintf('Остановка: достигнут лимит %d шагов.',session.maxSteps);
            output = 'Стоп';
        elseif session.recordResults || confirm
            output = 'Продолжить';
        else
            output = questdlg(sprintf('Следующий шаг\n dt = %.5e c',Net.dt), ...
                'Расчет','Продолжить','Стоп','Продолжить');
            if ~strcmp(output,'Продолжить')
                output = 'Стоп';
                session.result.status = 'Остановлено пользователем.';
            end
        end
        if strcmp(output,'Продолжить')
            if session.recordResults
                monitor = [];
                if nargin >= 3 && isstruct(options), monitor = options; end
                session.progress = printSimulationProgress('update',session.result, ...
                    session.lastStepComputeTime,session.progress,monitor,Net);
            end
            session.dtUsed = Net.dt;
            if confirm, session.dtUsed = 0; end
            [session.result,session.timer] = measureComputeTime('start',session.result);
        end
    case 'finish'
        requireSession(session);
        if nargin >= 3 && isstruct(options) && isfield(options,'stop')
            session.result.stationarity = options;
            if options.stop
                session.result.status = 'Установилось стационарное течение.';
            end
        elseif any(Net.H.State(:,end)==2)
            session.result.status = 'Вторая фаза достигла правой границы.';
        end
        if session.recordResults
            if session.snapshots > 0, session = saveLastStep(session); end
            saveSummary(session,Net);
            printSimulationProgress('finish',session.result, ...
                session.lastStepComputeTime,session.progress,[],Net);
            fprintf('Результаты: %s\n',session.result.directory);
        end
        output = session.result;
        if ~session.recordResults, disp(output.status); end
        session = [];
    case 'fail'
        requireSession(session);
        if ~isempty(session.timer)
            [session.result,session.timer] = ...
                measureComputeTime('fail',session.result,session.timer);
        end
        session.result.status = ['Ошибка расчёта: ' options.message];
        restoredNet = session.lastNet;
        if session.recordResults
            try
                if session.snapshots > 0, session = saveLastStep(session); end
                saveSummary(session,restoredNet);
                printSimulationProgress('fail',session.result, ...
                    session.lastStepComputeTime,session.progress,[],restoredNet);
                fprintf('Результаты: %s\n',session.result.directory);
            catch reportError
                % A reporting failure must not replace the original calculation error.
                warning('simulationReport:PartialResultsFailed', ...
                    'Не удалось записать итог незавершённого расчёта: %s',reportError.message);
            end
        end
        output = session.result;
        if ~session.recordResults, disp(output.status); end
        session = [];
    otherwise
        error('simulationReport:UnknownAction','Неизвестное действие: %s',action);
end
end

function requireSession(session)
if isempty(session)
    error('simulationReport:NotStarted','Сначала вызовите simulationReport(''start'',Net).');
end
end

function session = saveLastStep(session)
% The last accepted state is already cached; never write a skipped step twice.
if session.lastSavedStep == session.result.steps, return; end
result = session.result;
result.totalComputeTime = session.lastTotalComputeTime;
saveSimulationStep(session.lastNet,result,session.lastDtUsed,session.lastStepComputeTime);
session.lastSavedStep = session.result.steps;
end

function saveSummary(session,Net)
result = session.result;
parameters = session.parameters;
save(fullfile(result.directory,'summary.mat'),'result','parameters','Net');
end
