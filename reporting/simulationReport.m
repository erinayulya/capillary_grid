function [output, restoredNet] = simulationReport(action, Net, options, outputRoot, maxSteps)
%SIMULATIONREPORT Record states/timing and present the continuation dialog.
% Does not modify Net, call model/solver functions, or execute simulation steps.
% start: options is recordResults. fail: options is the original MException.
% fail returns the last accepted Net as its second output; no model calls.
% One active reporting session; every start resets its state.
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
        session = struct('recordResults',recordResults,'maxSteps',maxSteps, ...
            'parameters',Net,'lastNet',Net,'snapshots',0,'dtUsed',0,'timer',[], ...
            'reportNet',[],'partialComputeTime',0);
        session.result = struct('startedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
            'totalTime',0,'totalComputeTime',0,'failedComputeTime',0, ...
            'steps',0,'status','Расчёт не завершён.','directory','','pdf','');
        if recordResults
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
    case 'capture'
        requireSession(session);
        [session.result,session.timer,session.partialComputeTime] = ...
            measureComputeTime('stop',session.result,session.timer);
        session.reportNet = Net;
        if ~session.recordResults
            drawNetwork(session.reportNet,true);
        end
        [session.result,session.timer] = measureComputeTime('start',session.result);
    case 'snapshot'
        requireSession(session);
        [session.result,session.timer,seconds] = ...
            measureComputeTime('stop',session.result,session.timer);
        seconds = seconds + session.partialComputeTime;
        session.partialComputeTime = 0;
        session.result.steps = session.snapshots;
        session.result.totalTime = session.result.totalTime + session.dtUsed;
        session.lastNet = Net;
        reportNet = session.reportNet;
        if isempty(reportNet), reportNet = Net; end
        if session.recordResults
            saveSimulationStep(Net,session.result,session.dtUsed,seconds,reportNet);
            saveSummary(session,Net);
        elseif isempty(session.reportNet)
            drawNetwork(Net,session.result.steps > 0);
        end
        session.snapshots = session.snapshots + 1;
    case 'next'
        requireSession(session);
        if session.recordResults && (~isfinite(Net.dt) || Net.dt <= 0)
            session.result.status = 'Остановка: нет конечного положительного шага dt.';
            output = 'Стоп';
        elseif session.recordResults && session.result.steps >= session.maxSteps
            session.result.status = sprintf('Остановка: достигнут лимит %d шагов.',session.maxSteps);
            output = 'Стоп';
        elseif session.recordResults
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
            session.dtUsed = Net.dt;
            session.reportNet = [];
            session.partialComputeTime = 0;
            [session.result,session.timer] = measureComputeTime('start',session.result);
        end
    case 'finish'
        requireSession(session);
        if any(Net.H.State(:,end)==2)
            session.result.status = 'Вторая фаза достигла правой границы.';
        end
        if session.recordResults
            saveSummary(session,Net);
            session.result.pdf = writeSimulationReport(session.result.directory);
            saveSummary(session,Net);
            fprintf('Результаты: %s\n',session.result.directory);
        end
        output = session.result;
        disp(output.status);
        session = [];
    case 'fail'
        requireSession(session);
        if ~isempty(session.timer)
            [session.result,session.timer] = ...
                measureComputeTime('fail',session.result,session.timer);
        end
        session.result.failedComputeTime = ...
            session.result.failedComputeTime + session.partialComputeTime;
        session.result.status = ['Ошибка расчёта: ' options.message];
        restoredNet = session.lastNet;
        if session.recordResults
            try
                saveSummary(session,restoredNet);
                session.result.pdf = writeSimulationReport(session.result.directory);
                saveSummary(session,restoredNet);
                fprintf('Результаты: %s\n',session.result.directory);
            catch reportError
                % A reporting failure must not replace the original calculation error.
                warning('simulationReport:PartialReportFailed', ...
                    'Не удалось записать частичный отчёт: %s',reportError.message);
            end
        end
        output = session.result;
        disp(output.status);
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

function saveSummary(session,Net)
result = session.result;
parameters = session.parameters;
save(fullfile(result.directory,'summary.mat'),'result','parameters','Net');
end
