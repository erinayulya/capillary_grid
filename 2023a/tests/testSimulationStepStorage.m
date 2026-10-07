function testSimulationStepStorage()
%TESTSIMULATIONSTEPSTORAGE Check PDF/MAT identity and legacy reading.
setupProject;
root=fileparts(fileparts(mfilename('fullpath')));
if ~isfolder(fullfile(root,'tmp')), mkdir(fullfile(root,'tmp')); end
folder=tempname(fullfile(root,'tmp')); mkdir(folder);
result=struct('directory',folder,'steps',1,'totalTime',0.2,'totalComputeTime',0.03);
solved=struct('P',[11 12;13 14],'dt',0.4);
solved.H=struct('Q',[1 2;3 4]*1e-8,'Regime',[1 3;0 1]);
solved.V=struct('Q',[0 0;1 -1;0 0]*1e-8,'Regime',[0 0;3 1;0 0]);
solved.H.Move=[1 1;3 1];
solved.V.Move=[2 0;1 1;0 3];
displayed=struct('P',[1 2;3 4],'dt',0.2);
saveSimulationStep(solved,result,0.2,0.01);
path=fullfile(folder,'step_000001.mat');
saved=load(path); page=loadSimulationStep(path);
assert(isequaln(saved.Net,solved) && isequaln(page.Net,saved.Net));
assert(isequaln(saved.solvedNet,solved) && isequaln(page.solvedNet,solved));
assert(strcmp(page.reportPhase,'afterSolve') && page.dtUsed==0.2);
assert(page.stepComputeTime==0.01 && page.totalComputeTime==0.03);

result.steps=0;
saveSimulationStep(solved,result,0,0.02);
initial=loadSimulationStep(fullfile(folder,'step_000000.mat'));
assert(isequaln(initial.Net,initial.solvedNet) && strcmp(initial.reportPhase,'afterSolve'));

% Old dual-state files must render exactly as before.
legacy=saved;
legacy.Net=displayed;legacy.reportPhase='beforeSolve';
dualPath=fullfile(folder,'legacy_dual.mat');save(dualPath,'-struct','legacy');
page=loadSimulationStep(dualPath);
assert(isequaln(page.Net,displayed) && isequaln(page.solvedNet,solved));
assert(strcmp(page.reportPhase,'beforeSolve'));
legacy=rmfield(legacy,{'solvedNet','reportPhase'});
legacy.Net=solved; legacy.reportNet=displayed;
legacyPath=fullfile(folder,'legacy.mat'); save(legacyPath,'-struct','legacy');
page=loadSimulationStep(legacyPath);
assert(isequaln(page.Net,displayed) && isequaln(page.solvedNet,solved));
assert(strcmp(page.reportPhase,'beforeSolve'));
legacy=rmfield(legacy,'reportNet'); save(legacyPath,'-struct','legacy');
page=loadSimulationStep(legacyPath);
assert(isequaln(page.Net,solved) && strcmp(page.reportPhase,'afterSolve'));
fprintf('testSimulationStepStorage: all checks passed.\n');
end
