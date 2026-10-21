function monitor = checkSteadyState(Net, monitor)
%CHECKSTEADYSTATE Observe accepted solutions; never modify Net or run the model.
% Monitoring starts at right-boundary breakthrough. Time is in seconds,
% saturation is dimensionless and pressure is in Pa. Data stay outside Net.
if nargin < 2 || isempty(monitor)
    monitor = struct('reached',false,'justReached',false,'stop',false, ...
        'confirm',false,'time',0,'previousDt',0,'breakthroughTime',NaN, ...
        'reference',[],'referenceTime',0,'stableSteps',0, ...
        'saturationChange',Inf,'pressureChange',Inf, ...
        'saturationTolerance',1e-10,'pressureAbsoluteTolerance',1e-5, ...
        'pressureRelativeTolerance',1e-8,'minimumTime',1,'minimumSteps',3);
end
if isfinite(monitor.previousDt) && monitor.previousDt > 0
    monitor.time = monitor.time + monitor.previousDt;
end
monitor.previousDt = Net.dt;
monitor.justReached = false;
monitor.stop = false;
monitor.confirm = false;
if ~monitor.reached
    if ~any(Net.H.State(:,end)==2), return; end
    monitor.reached = true;
    monitor.justReached = true;
    monitor.breakthroughTime = monitor.time;
end

current = struct('Sat',[Net.H.Sat(:);Net.V.Sat(:)], ...
    'State',[Net.H.State(:);Net.V.State(:)], ...
    'Dir',[Net.H.Dir(:);Net.V.Dir(:)], ...
    'Move',[Net.H.Move(:);Net.V.Move(:)], ...
    'P',[Net.P(:);Net.H.P0;Net.V.P0]);
active = current.State==1 & current.Move==1;
% With no moving menisci, calcSaturation is a no-op even for dt=Inf.
% One further solve at the same model time checks pending births and pressure.
monitor.confirm = Net.dt==Inf && ~any(active);
if isempty(monitor.reference)
    monitor.reference = current;
    monitor.referenceTime = monitor.time;
    return
end

reference = monitor.reference;
monitor.saturationChange = max(abs(current.Sat-reference.Sat));
samePhase = isequal(current.State,reference.State) && ...
    isequal(current.Dir,reference.Dir) && isequal(current.Move,reference.Move);
% Small time steps must not hide a moving meniscus (including the plateau).
areas = [Net.H.A(:);Net.V.A(:)];
flows = [Net.H.Q(:);Net.V.Q(:)];
rate = max([0;abs(flows(active))./(areas(active)*Net.L)]);
phaseStable = samePhase && ...
    monitor.saturationChange <= monitor.saturationTolerance && ...
    rate*monitor.minimumTime <= monitor.saturationTolerance;
monitor.pressureChange = Inf;
pressureStable = false;
if phaseStable
    monitor.pressureChange = max(abs(current.P-reference.P));
    pressureScale = max([1;abs(current.P);abs(reference.P)]);
    pressureStable = monitor.pressureChange <= ...
        monitor.pressureAbsoluteTolerance + ...
        monitor.pressureRelativeTolerance*pressureScale;
end
if ~phaseStable || ~pressureStable
    monitor.reference = current;
    monitor.referenceTime = monitor.time;
    monitor.stableSteps = 0;
    return
end
monitor.stableSteps = monitor.stableSteps + 1;
monitor.stop = monitor.confirm || ...
    (monitor.stableSteps >= monitor.minimumSteps && ...
    monitor.time-monitor.referenceTime >= monitor.minimumTime);
end
