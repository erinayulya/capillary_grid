function steps = selectSimulationReportSteps(lastStep,stride)
%SELECTSIMULATIONREPORTSTEPS Include step 0, every stride-th step and the last.
% lastStep counts completed steps, excluding the initial state at t=0.
% stride defaults to 1 (all states). No simulation data is changed.
if nargin < 2, stride = 1; end
validateattributes(lastStep,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'},mfilename,'lastStep');
validateattributes(stride,{'numeric'}, ...
    {'scalar','integer','positive','finite'},mfilename,'stride');
steps = unique([0:double(stride):double(lastStep), double(lastStep)]);
end
