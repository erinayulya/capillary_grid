function phases = displacementPhases(Net)
%DISPLACEMENTPHASES Physical phase names for role-based calculation fields.
% Net.displacingPhase is 'oil' or 'water'; missing means legacy oil injection.
% mu1/State=0 are the displaced phase; mu2/State=2 and Sat are the invading phase.
% Reads metadata only; never changes Net, viscosities, angle or connectivity.
value = 'oil';
if isfield(Net,'displacingPhase'), value = Net.displacingPhase; end
if ~((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value)))
    error('displacementPhases:InvalidPhase','Вытесняющая фаза должна быть oil или water.');
end
switch char(value)
    case 'oil'
        phases = struct('waterDisplacing',false, ...
            'displacingName','Нефть','displacedName','Вода');
    case 'water'
        phases = struct('waterDisplacing',true, ...
            'displacingName','Вода','displacedName','Нефть');
    otherwise
        error('displacementPhases:InvalidPhase','Вытесняющая фаза должна быть oil или water.');
end
end
