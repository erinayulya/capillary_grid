function stride = simulationStorageOptions(action,value)
%SIMULATIONSTORAGEOPTIONS Pass a one-run MAT stride from run to reporting.
% set: positive integer value. take: consume it, defaulting to 1 (all steps).
% reset: discard pending settings. State is separate from simulationReport
% so main's resetSimulationWorkspace can clear the old reporting session.
% No Net fields or calculation parameters are read or changed.
persistent pendingStride
stride = [];
switch action
    case 'set'
        validateattributes(value,{'numeric'}, ...
            {'scalar','real','finite','integer','positive'},mfilename,'stride');
        pendingStride = value;
    case 'take'
        stride = 1;
        if ~isempty(pendingStride), stride = pendingStride; end
        pendingStride = [];
    case 'reset'
        pendingStride = [];
    otherwise
        error('simulationStorageOptions:UnknownAction','Неизвестное действие: %s',action);
end
end
