function saveSimulationStep(solvedNet,result,dtUsed,stepComputeTime,stationarity)
%SAVESIMULATIONSTEP Save one solved state for MAT, plots and PDF.
% The input state is not modified in the caller.
% Monitor is from before observing this solved state; main observes it once.
if nargin < 5, stationarity = []; end
reportPhase = 'afterSolve';
Net = solvedNet;
step = result.steps;
elapsedTime = result.totalTime;
totalComputeTime = result.totalComputeTime;
saveStride = 1;
if isfield(result,'saveStride'), saveStride = result.saveStride; end
% Метка версии уравнений хранится вне Net; старые MAT остаются читаемыми.
flowLaw = 'smoothMeniscusAppliedPressure';
save(fullfile(result.directory,sprintf('step_%06d.mat',step)), ...
    'Net','solvedNet','reportPhase','flowLaw','step','dtUsed','elapsedTime', ...
    'stepComputeTime','totalComputeTime','stationarity','saveStride');
end
