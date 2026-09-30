function saveSimulationStep(solvedNet,result,dtUsed,stepComputeTime,reportNet)
%SAVESIMULATIONSTEP Save Net as displayed; keep the solution in solvedNet.
% Neither input state is modified in the caller.
reportPhase = 'afterSolve';
if nargin < 5
    reportNet = solvedNet;
elseif result.steps > 0
    reportPhase = 'beforeSolve';
end
Net = reportNet;
step = result.steps;
elapsedTime = result.totalTime;
totalComputeTime = result.totalComputeTime;
% Метка версии уравнений хранится вне Net; старые MAT остаются читаемыми.
flowLaw = 'twoRegimeCurrentPressure';
save(fullfile(result.directory,sprintf('step_%06d.mat',step)), ...
    'Net','solvedNet','reportPhase','flowLaw','step','dtUsed','elapsedTime','stepComputeTime','totalComputeTime');
end
