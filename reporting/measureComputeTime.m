function [result, timer, stepComputeTime] = measureComputeTime(action, result, timer)
%MEASURECOMPUTETIME Measure wall time only; never run or update the model.
% start: begin an interval. stop: add its seconds to totalComputeTime.
% fail: also store its seconds in failedComputeTime. Net is not an argument.
if nargin < 3, timer = []; end
stepComputeTime = 0;
switch action
    case 'start'
        timer = tic;
    case {'stop','fail'}
        if isempty(timer)
            error('measureComputeTime:NotStarted','Таймер вычислений не запущен.');
        end
        stepComputeTime = toc(timer);
        timer = [];
        result.totalComputeTime = result.totalComputeTime + stepComputeTime;
        if strcmp(action,'fail')
            result.failedComputeTime = stepComputeTime;
        end
    otherwise
        error('measureComputeTime:UnknownAction','Неизвестное действие таймера: %s',action);
end
end
