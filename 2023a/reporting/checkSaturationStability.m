function observation = checkSaturationStability(Net,observation,time,breakthroughTime)
%CHECKSATURATIONSTABILITY Observe bulk oil saturation after breakthrough.
% Stop after two consecutive, nonoverlapping model-time windows whose
% max-minus-min saturation is <0.001 (0.1 percentage point). Each window
% lasts at least 5% of the time to breakthrough. Oil and water fractions
% have the same range. Net is read only; no model/solver calls are made.
if isempty(observation)
    observation = struct('tolerance',0.001,'windowFraction',0.05, ...
        'requiredWindows',2,'windowDuration',NaN,'windowStart',NaN, ...
        'minimum',NaN,'maximum',NaN,'fraction',NaN,'change',Inf, ...
        'stableWindows',0,'reached',false);
end
observation.reached = false;
observation.fraction = networkOilSaturation(Net);
observation.windowDuration = observation.windowFraction*breakthroughTime;
if ~isfinite(observation.fraction) || ~isfinite(time) || ...
        ~isfinite(observation.windowDuration) || observation.windowDuration<=0
    % No positive time scale or valid saturation: retain the strict criterion.
    observation.windowStart = NaN;
    observation.minimum = NaN;
    observation.maximum = NaN;
    observation.change = Inf;
    observation.stableWindows = 0;
    return
end
if ~isfinite(observation.windowStart)
    observation.windowStart = time;
    observation.minimum = observation.fraction;
    observation.maximum = observation.fraction;
    return
end
observation.minimum = min(observation.minimum,observation.fraction);
observation.maximum = max(observation.maximum,observation.fraction);
observation.change = observation.maximum-observation.minimum;
if time-observation.windowStart < observation.windowDuration, return; end
if observation.change < observation.tolerance
    observation.stableWindows = observation.stableWindows+1;
else
    observation.stableWindows = 0;
end
observation.reached = observation.stableWindows >= observation.requiredWindows;
% Restart at this accepted state; one large dt never counts as two windows.
observation.windowStart = time;
observation.minimum = observation.fraction;
observation.maximum = observation.fraction;
end
