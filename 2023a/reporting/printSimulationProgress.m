function progress = printSimulationProgress(action,result,lastStepComputeTime,progress,monitor,Net)
%PRINTSIMULATIONPROGRESS Print automatic-run status at most once every 15 s.
% start returns a wall-clock timer; update checks it between accepted steps.
% finish/fail always print final counters. No timers run asynchronously.
% result is read only; progress stays outside Net and saved MAT metadata.
if nargin < 5, monitor = []; end
if nargin < 6, Net = []; end
switch action
    case 'start'
        progress = struct('timer',tic,'lastOutput',0,'interval',15);
        fprintf('Расчёт запущен. Ход расчёта: каждые 15 с между шагами.\n');
        printOilSaturation(Net);
        return
    case 'update'
        elapsed = toc(progress.timer);
        if elapsed-progress.lastOutput < progress.interval, return; end
        heading = 'Расчёт идёт';
        phase = 'расчёт сети';
        if isstruct(monitor) && isfield(monitor,'reached')
            if monitor.reached
                phase = 'проверка стационарности';
            else
                phase = 'движение второй фазы до правой границы';
            end
        end
        if isstruct(monitor) && isfield(monitor,'confirm') && monitor.confirm
            phase = 'подтверждение стационарности';
        end
    case {'finish','fail'}
        elapsed = toc(progress.timer);
        heading = 'Расчёт завершён';
        if strcmp(action,'fail'), heading = 'Расчёт прерван ошибкой'; end
        phase = result.status;
    otherwise
        error('printSimulationProgress:UnknownAction','Неизвестное действие: %s',action);
end
fprintf('[%s] %s\n',elapsedText(elapsed),heading);
fprintf('  Выполнено шагов: %d | Модельное время: %.6g с\n',result.steps,result.totalTime);
printOilSaturation(Net);
if isempty(lastStepComputeTime)
    fprintf('  Принятых решений пока нет.\n');
else
    fprintf('  Вычисления последнего принятого шага: %.3g с\n',lastStepComputeTime);
end
fprintf('  Состояние: %s\n',phase);
progress.lastOutput = toc(progress.timer);
end

function printOilSaturation(Net)
fraction=networkOilSaturation(Net);
if isfinite(fraction)
    fprintf('  Нефтенасыщенность: %.2f %%\n',100*fraction);
else
    fprintf('  Нефтенасыщенность: нет данных.\n');
end
end

function value = elapsedText(elapsed)
% Hours do not wrap at 24; this is elapsed wall time, not model time.
seconds = floor(elapsed);
value = sprintf('%02d:%02d:%02d',floor(seconds/3600), ...
    floor(mod(seconds,3600)/60),mod(seconds,60));
end
