function saveSimulationStep(solvedNet,result,dtUsed,stepComputeTime)
%SAVESIMULATIONSTEP Save one solved state for MAT, plots and PDF.
% The input state is not modified in the caller.
reportPhase = 'afterSolve';
Net = solvedNet;
step = result.steps;
elapsedTime = result.totalTime;
totalComputeTime = result.totalComputeTime;
% Метка версии уравнений хранится вне Net; старые MAT остаются читаемыми.
flowLaw = 'twoRegimeCurrentPressure';
save(fullfile(result.directory,sprintf('step_%06d.mat',step)), ...
    'Net','solvedNet','reportPhase','flowLaw','step','dtUsed','elapsedTime','stepComputeTime','totalComputeTime');
end
