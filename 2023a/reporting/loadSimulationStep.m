function snapshot = loadSimulationStep(path)
%LOADSIMULATIONSTEP Read current or legacy MAT: Net is always the PDF state.
% solvedNet holds the accepted solution; reportPhase identifies the Net phase.
snapshot = load(path);
if ~isfield(snapshot,'solvedNet')
    snapshot.solvedNet = snapshot.Net;
    snapshot.reportPhase = 'afterSolve';
    if isfield(snapshot,'reportNet')
        snapshot.Net = snapshot.reportNet;
        if snapshot.step > 0, snapshot.reportPhase = 'beforeSolve'; end
    end
end
end
