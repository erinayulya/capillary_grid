function [summary,details] = auditDisplacementAdequacy(selection,outputFile)
%AUDITDISPLACEMENTADEQUACY Measure conservation and independent filling times.
% selection: chain (two capillaries, viscous and plateau), refined (smaller
% diagnostic steps), network or network-refined (last saved geometry).
% A_add is enabled in every case. No production file, user setting or result
% is changed. Diagnostic refinement divides only the local test copy's dt.
% outputFile is an optional MAT path; results stay outside Net.
if nargin<1, selection='chain'; end
if nargin<2, outputFile=''; end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root); setupProject;
cases=makeCases(root,selection);
details=cell(numel(cases),1);
for k=1:numel(cases)
    details{k}=runCase(cases(k));
    fprintf('%s | %s | model=%d | P=%g | refine=%d | %s | steps=%d | t=%.9g | oil=%.5f | phaseErr/PV=%.6g\n', ...
        cases(k).geometry,cases(k).phase,cases(k).model,cases(k).pressure, ...
        cases(k).refinement,details{k}.metrics.status,details{k}.metrics.steps, ...
        details{k}.metrics.time,details{k}.metrics.finalOil,details{k}.metrics.phaseErrorPV);
end
rows=cellfun(@(item) item.metrics,details,'UniformOutput',false);
summary=struct2table(vertcat(rows{:}));
if ~isempty(outputFile), save(outputFile,'summary','details'); end
end

function cases=makeCases(root,selection)
base=struct('geometry','chain','phase','oil','model',1,'pressure',1500, ...
    'refinement',1,'Ah',pi*1e-8*[1 1],'Av',pi*1e-8*[1;1]);
cases=repmat(base,0,1);
switch selection
    case 'chain'
        settings=[1 1500 1;2 1500 1;2 50 1];
    case 'refined'
        settings=[1 1500 10;1 1500 100;2 50 10];
    case {'network','network-refined'}
        data=load(fullfile(root,'results','last_settings','run-settings.mat'));
        base.geometry='saved6x6'; base.Ah=data.previousGeometry.Ah;
        base.Av=data.previousGeometry.Av;
        if isfield(data.inputs,'GeometryMode') && ...
                strcmp(data.inputs.GeometryMode,'Выбрать из сохраненных')
            mesh=savedMesh('load',fullfile(root,'mesh','saved_mesh'),data.inputs.SavedMeshName);
            base.Ah=mesh.Ah; base.Av=mesh.Av;
        end
        settings=[1 data.inputs.H_P0 1;2 data.inputs.H_P0 1];
        if strcmp(selection,'network-refined'), settings(:,3)=10; end
    otherwise
        error('auditDisplacementAdequacy:Selection','Unknown selection.');
end
for index=1:size(settings,1)
    for phase={'oil','water'}
        item=base; item.phase=phase{1}; item.model=settings(index,1);
        item.pressure=settings(index,2); item.refinement=settings(index,3);
        cases(end+1,1)=item; %#ok<AGROW>
    end
end
end

function result=runCase(c)
N=initialize(c); initial=N;
reference=referenceTime(N,c);
timer=tic; elapsed=0; steps=0; monitor=[]; status='step limit';
injected=0; exported=0; clipping=0; outletCrossing=0; maxStepMass=0; maxResidual=0;
maxBalance=0; minPressure=Inf; maxPressure=-Inf; minSat=Inf; maxSat=-Inf;
plateau=0; viscous=0; transition=0; connectivityErrors=0; trappedFlow=0;
nodeSource=0; maxPhaseNodeBalance=0;
initialVolume=invadingVolume(N); history=zeros(20001,7); historyCount=0;
try
    N=solvePressureFlow(N); N=calcTimeStep(N);
    while steps<=20000
        [residual,balance]=hydraulicErrors(N);
        phaseBalance=phaseNodeBalance(N);
        maxPhaseNodeBalance=max(maxPhaseNodeBalance,max(abs(phaseBalance(:))));
        maxResidual=max(maxResidual,residual); maxBalance=max(maxBalance,balance);
        minPressure=min(minPressure,min(N.P(:))); maxPressure=max(maxPressure,max(N.P(:)));
        sat=[N.H.Sat(:);N.V.Sat(:)]; state=[N.H.State(:);N.V.State(:)];
        move=[N.H.Move(:);N.V.Move(:)]; q=[N.H.Q(:);N.V.Q(:)];
        minSat=min(minSat,min(sat)); maxSat=max(maxSat,max(sat));
        regimes=[N.H.Regime(:);N.V.Regime(:)]; active=state==1 & move==1;
        plateau=plateau+nnz(active & regimes==1);
        viscous=viscous+nnz(active & regimes==3);
        dp=orientedPressure(N); radii=sqrt([N.H.A(:);N.V.A(:)]/pi);
        transition=transition+nnz(active & abs(dp-N.coef*radii.^(-5/4))<N.P_crit_width/2);
        connectivityErrors=connectivityErrors+independentConnectivityErrors(N);
        trappedFlow=max([trappedFlow;abs(q(state==1 & move==2))]);
        volume=invadingVolume(N); pore=poreVolume(N);
        historyCount=historyCount+1;
        history(historyCount,:)=[elapsed,networkOilSaturation(N),volume, ...
            injected,exported,(volume-initialVolume)-(injected-exported),balance];
        if strcmp(c.geometry,'chain') && all(N.H.State(:)==2)
            status='filled'; break
        end
        monitor=checkSteadyState(N,monitor);
        if monitor.stop, status='stationary'; break; end
        if toc(timer)>50, status='wall time limit'; break; end
        if ~isfinite(N.dt) && ~monitor.confirm, status='no finite dt'; break; end
        dtUsed=0;
        if isfinite(N.dt), dtUsed=N.dt/c.refinement; end
        [inflow,outflow]=boundaryPhaseFlux(N);
        nodeSource=nodeSource-sum(phaseBalance(:))*dtUsed;
        injected=injected+inflow*dtUsed; exported=exported+outflow*dtUsed;
        fractions=roleFraction(N); volumes=capillaryVolumes(N);
        excess=zeros(size(volumes));
        excess(active)=volumes(active).*max(0, ...
            fractions(active)+abs(q(active))*dtUsed./volumes(active)-1);
        clipping=clipping+sum(excess);
        % Give outlet overshoot the most favourable interpretation: material
        % leaving after the front crosses the outlet within this frozen-Q step.
        outlet=false(size(N.H.A)); outlet(:,end)=N.H.Dir(:,end)>0;
        outlet=[outlet(:);false(numel(N.V.A),1)];
        outletCrossing=outletCrossing+sum(excess(outlet));
        oldVolume=volume;
        if isfinite(N.dt), N.dt=dtUsed; end
        N=calcSaturation(N); N=calcState(N); N=calcCanMove(N);
        nextVolume=invadingVolume(N);
        maxStepMass=max(maxStepMass,abs(nextVolume-oldVolume-(inflow-outflow)*dtUsed)/pore);
        elapsed=elapsed+dtUsed; steps=steps+1;
        N=solvePressureFlow(N); N=calcTimeStep(N);
    end
catch exception
    status=['error: ' exception.message];
end
volume=invadingVolume(N); pore=poreVolume(N);
metrics=struct('geometry',c.geometry,'phase',c.phase,'model',c.model, ...
    'pressure',c.pressure,'refinement',c.refinement,'status',status,'steps',steps, ...
    'time',elapsed,'referenceTime',reference,'timeErrorPercent',100*(elapsed/reference-1), ...
    'finalOil',networkOilSaturation(N),'phaseErrorPV', ...
    ((volume-initialVolume)-(injected-exported)+outletCrossing)/pore, ...
    'phaseErrorFrozenBoundaryPV',((volume-initialVolume)-(injected-exported))/pore, ...
    'clippingPV',clipping/pore,'internalClippingPV',(clipping-outletCrossing)/pore, ...
    'maxStepMassPV',maxStepMass, ...
    'phaseNodeSourcePV',nodeSource/pore,'maxPhaseNodeBalance',maxPhaseNodeBalance, ...
    'phaseAccountingResidualPV', ...
    ((volume-initialVolume)-(injected-exported)+clipping-nodeSource)/pore, ...
    'maxResidual',maxResidual,'maxNodeBalance',maxBalance, ...
    'minPressure',minPressure,'maxPressure',maxPressure,'minSat',minSat,'maxSat',maxSat, ...
    'plateauSamples',plateau,'viscousSamples',viscous,'transitionSamples',transition, ...
    'connectivityErrors',connectivityErrors,'trappedFlow',trappedFlow);
result=struct('metrics',metrics,'initialNet',initial,'finalNet',N, ...
    'history',history(1:historyCount,:), ...
    'historyColumns',{{'time_s','oilFraction','invadingVolume_m3','injected_m3', ...
    'exported_m3','phaseMassError_m3','nodeBalance_m3_s'}});
end

function N=initialize(c)
N=struct('displacingPhase',c.phase,'mu1',1e-3,'mu2',4.3e-3, ...
    'L',9e-3,'sigma',.07,'theta',pi/4,'VerticalBC',false, ...
    'k',3.29015,'xi',30.079341699546497,'coef',6.644123616564944e-4,'P_crit_width',4);
if strcmp(c.phase,'water'), N.mu1=4.3e-3; N.mu2=1e-3; N.theta=3*pi/4; end
if c.model==1, N.coef=0; N.P_crit_width=0; end
N.H=struct('A',c.Ah,'P0',c.pressure); N.V=struct('A',c.Av,'P0',200);
for name='HV'
    [N.(name).Ny,N.(name).Nx]=size(N.(name).A);
    for field={'Sat','State','Move','Dir','Regime'}
        N.(name).(field{1})=zeros(size(N.(name).A));
    end
end
N.H.State(:,1)=1; N.H.Move(:,1)=1; N.H.Dir(:,1)=1; N.H.Regime(:,1)=3;
end

function t=referenceTime(N,c)
t=NaN;
if ~strcmp(c.geometry,'chain'), return; end
r=sqrt(N.H.A(1)/pi);
add=N.xi*(N.mu1+N.mu2)/r;
if c.pressure==1500
    % Integrate the total two-capillary Poiseuille resistance over each front.
    t=N.L/c.pressure*(16*N.L/r^2*(N.mu1+N.mu2)+2*add);
else
    % The entire pressure is below P_crit-width/2. The active plateau law
    % is independent of S, with one single-phase capillary in series.
    wet=N.mu1; if N.theta>=pi/2, wet=N.mu2; end
    B=2*N.k*N.sigma/r*sin(N.theta)*(wet/N.sigma)^(1/3);
    resistance=8*N.L/r^2*[N.mu1 N.mu2];
    speed=zeros(1,2);
    for k=1:2
        u=fzero(@(x) resistance(k)*x^3+B*x-c.pressure,[0 c.pressure/B]);
        speed(k)=u^3;
    end
    t=sum(N.L./speed);
end
end

function fractions=roleFraction(N)
fractions=[N.H.Sat(:);N.V.Sat(:)]; state=[N.H.State(:);N.V.State(:)];
fractions(state==0)=0; fractions(state==2)=1;
end

function volumes=capillaryVolumes(N)
volumes=[N.H.A(:);N.V.A(:)]*N.L;
end

function included=includedCapillaries(N)
v=true(size(N.V.A));
if ~N.VerticalBC, v([1 end],:)=false; end
included=[true(numel(N.H.A),1);v(:)];
end

function value=invadingVolume(N)
f=roleFraction(N); volumes=capillaryVolumes(N); included=includedCapillaries(N);
value=sum(f(included).*volumes(included));
end

function value=poreVolume(N)
volumes=capillaryVolumes(N); value=sum(volumes(includedCapillaries(N)));
end

function [incoming,outgoing]=boundaryPhaseFlux(N)
left=N.H.State(:,1)==2 | (N.H.State(:,1)==1 & N.H.Dir(:,1)>0);
right=N.H.State(:,end)==2 | (N.H.State(:,end)==1 & N.H.Dir(:,end)<0);
incoming=sum(N.H.Q(:,1).*left); outgoing=sum(N.H.Q(:,end).*right);
end

function balance=phaseNodeBalance(N)
% Fluid touching each end of a meniscus, as used by the one-front model.
hf=N.H.State==2 | (N.H.State==1 & N.H.Dir>0);
hs=N.H.State==2 | (N.H.State==1 & N.H.Dir<0);
vf=N.V.State==2 | (N.V.State==1 & N.V.Dir>0);
vs=N.V.State==2 | (N.V.State==1 & N.V.Dir<0);
balance=N.H.Q(:,1:end-1).*hs(:,1:end-1)-N.H.Q(:,2:end).*hf(:,2:end) ...
    +N.V.Q(1:end-1,:).*vs(1:end-1,:)-N.V.Q(2:end,:).*vf(2:end,:);
end

function dp=orientedPressure(N)
h=[N.H.P0*ones(N.H.Ny,1),N.P]-[N.P,zeros(N.H.Ny,1)];
v=[N.V.P0*ones(1,N.V.Nx);N.P]-[N.P;zeros(1,N.V.Nx)];
dp=[h(:).*N.H.Dir(:);v(:).*N.V.Dir(:)];
end

function [residual,balance]=hydraulicErrors(N)
np=numel(N.P); nh=numel(N.H.Q); nv=numel(N.V.Q);
f=calcResidualJacobian(N,[N.P(:);N.H.Q(:);N.V.Q(:)], ...
    reshape(1:np,size(N.P)),reshape(np+(1:nh),size(N.H.Q)), ...
    reshape(np+nh+(1:nv),size(N.V.Q)));
residual=max(abs(f));
b=N.H.Q(:,1:end-1)-N.H.Q(:,2:end)+N.V.Q(1:end-1,:)-N.V.Q(2:end,:);
balance=max(abs(b(:)));
end

function count=independentConnectivityErrors(N)
% Node-based reachability, independent of the production capillary BFS.
nodes=reshape(1:numel(N.P),size(N.P));
hf=[zeros(N.H.Ny,1),nodes]; hs=[nodes,zeros(N.H.Ny,1)];
vf=[zeros(1,N.V.Nx);nodes]; vs=[nodes;zeros(1,N.V.Nx)];
first=[hf(:);vf(:)]; second=[hs(:);vs(:)];
full=([N.H.Sat(:);N.V.Sat(:)]==0) & includedCapillaries(N);
seed=false(size(N.H.A)); seed(:,end)=true;
seed=[seed(:);false(numel(N.V.A),1)] & full;
connected=false(numel(nodes),1);
endpoints=[first(seed);second(seed)]; connected(endpoints(endpoints>0))=true;
for iteration=1:numel(nodes)
    lookup=[false;connected];
    edges=full & (lookup(first+1) | lookup(second+1));
    endpoints=[first(edges);second(edges)];
    expanded=connected; expanded(endpoints(endpoints>0))=true;
    if isequal(expanded,connected), break; end
    connected=expanded;
end
direction=[N.H.Dir(:);N.V.Dir(:)]; ahead=second; ahead(direction<0)=first(direction<0);
lookup=[false;connected]; allowed=lookup(ahead+1);
% The only open direct outlet in these closed-vertical-boundary fixtures.
direct=false(size(N.H.A)); direct(:,end)=N.H.Dir(:,end)>0;
allowed=allowed | [direct(:);false(numel(N.V.A),1)];
state=[N.H.State(:);N.V.State(:)]; move=[N.H.Move(:);N.V.Move(:)];
count=nnz(state==1 & move==1 & ~allowed);
end
