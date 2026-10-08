classdef testTwoRegimeFlow < matlab.unittest.TestCase
    % Проверка новой физики, гладкого перехода и целой последовательности.
    properties (TestParameter)
        previousMove = {1,3}
        direction = {1,-1}
        excessFraction = {0.25,0.99,1,1.01,2}
        transitionOffset = {-2,0,2}
        contactAngle = {pi/4,pi/2,3*pi/4}
        damagedField = {'flow','move','regime'}
    end
    methods (TestClassSetup)
        function paths(testCase)
            savedPath = path;
            testCase.addTeardown(@() path(savedPath));
            setupProject;
        end
    end
    methods (Test)
        function connectivityDoesNotReadPressure(testCase)
            N=smallNet(1,3);
            N.V.State(1)=1;N.V.Dir(1)=1;N.V.Move(1)=3;
            % No P at all: eligibility must depend only on topology/state.
            C=calcCanMove(N);
            testCase.verifyEqual(C.H.Move,[1 0]);
            testCase.verifyEqual(C.V.Move,[2;0]);
            N.H.Move(1)=2;
            C=calcCanMove(N);
            testCase.verifyEqual(C.H.Move,[2 0]);
        end
        function solvedMoveStoredWithPressure(testCase)
            N=smallNet(1,3);[pc,~]=thresholds(N);
            root=fileparts(fileparts(mfilename('fullpath')));
            if ~isfolder(fullfile(root,'tmp')),mkdir(fullfile(root,'tmp'));end
            folder=tempname(fullfile(root,'tmp'));mkdir(folder);
            % Both cases enter solver with topology-eligible Move=1.
            for inlet=[0,1000]
                N.H.P0=inlet;C=calcCanMove(N);
                testCase.verifyEqual(C.H.Move(1),1);
                S=solvePressureFlow(C);S=calcTimeStep(S);
                margin=S.H.P0-S.P(1)-pc;
                expected=3;if margin>0,expected=1;end
                testCase.verifyEqual(S.H.Move(1),expected);
                result=struct('directory',folder,'steps',1,'totalTime',0,'totalComputeTime',0);
                saveSimulationStep(S,result,0,0);
                page=loadSimulationStep(fullfile(folder,'step_000001.mat'));
                testCase.verifyEqual(page.Net,S);
                testCase.verifyEqual(page.solvedNet,S);
                testCase.verifyEqual(page.reportPhase,'afterSolve');
            end
        end
        function stoppedBelowThreshold(testCase,previousMove)
            N = exampleNet(); [pc,~] = thresholds(N);
            [f,dp,dq,r,m] = capillaryEquation(N,-10,0,1e-6,0,1,3,previousMove);
            testCase.verifyEqual([f,dp,dq,r,m],[0,0,1,0,3],'AbsTol',1e-20);
        end
        function stoppedAtThreshold(testCase)
            N = exampleNet(); [pc,~] = thresholds(N);
            [f,dp,~,r,m] = capillaryEquation(N,pc,0,1e-6,0,1,1,1);
            testCase.verifyEqual([f,dp,r,m],[0,0,0,3],'AbsTol',1e-20);
        end
        function heldCanReopen(testCase,previousMove)
            N = exampleNet(); [pc,critical] = thresholds(N);
            [f,~,~,r,m] = capillaryEquation(N,pc+2*critical,0,1e-6,0,1,0,previousMove);
            testCase.verifyLessThan(f,0);
            testCase.verifyEqual([r,m],[3,1]);
        end
        function trappedDoesNotReopen(testCase)
            N = exampleNet();
            [f,dp,~,r,m] = capillaryEquation(N,1e6,0,1e-6,0,1,3,2);
            testCase.verifyEqual([f,dp,r,m],[0,0,0,2],'AbsTol',1e-20);
        end
        function continuousAtRegimeBoundary(testCase)
            N = exampleNet(); [pc,critical] = thresholds(N);
            fleft = capillaryEquation(N,pc+critical*(1-1e-10),0,1e-6,0,1,1,1);
            fright = capillaryEquation(N,pc+critical*(1+1e-10),0,1e-6,0,1,3,1);
            testCase.verifyEqual(fleft,fright,'RelTol',5e-8);
        end
        function analyticDerivative(testCase,excessFraction)
            N = exampleNet(); [pc,critical] = thresholds(N);
            pressure = pc+critical*excessFraction; h=1e-4;
            [~,dp,dq] = capillaryEquation(N,pressure,0,1e-6,0,1,0,3);
            fp = capillaryEquation(N,pressure+h,0,1e-6,0,1,0,3);
            fm = capillaryEquation(N,pressure-h,0,1e-6,0,1,0,3);
            testCase.verifyEqual(dp,(fp-fm)/(2*h),'RelTol',1e-7);
            testCase.verifyEqual(dq,1);
        end
        function networkRespectsOrientation(testCase,direction,previousMove)
            N = smallNet(direction,previousMove);
            S = solvePressureFlow(N);
            testCase.verifyGreaterThan(direction*S.H.Q(1),0);
            testCase.verifyEqual(S.H.Q(1),S.H.Q(2),'AbsTol',1e-19);
            testCase.verifyEqual(S.H.Move(1),1);
            testCase.verifyEqual(S.H.Dir,N.H.Dir);
            testCase.verifyEqual(S.H.Sat,N.H.Sat,'AbsTol',1e-15);
        end
        function networkStopsOldMovingMeniscus(testCase)
            N = smallNet(1,1); N.H.P0=0;
            S = solvePressureFlow(N);
            testCase.verifyEqual(S.H.Q,[0,0],'AbsTol',1e-19);
            testCase.verifyEqual([S.H.Move(1),S.H.Regime(1)],[3,0]);
        end
        function verticalNetworkRespectsOrientation(testCase,direction,previousMove)
            N=smallNet(1,1);N.VerticalBC=true;N.H.P0=0;N.H.State(:)=0;
            N.H.Move(:)=0;N.H.Dir(:)=0;N.H.Regime(:)=0;
            N.V.P0=direction*1000;N.V.State(1)=1;
            N.V.Dir(1)=direction;N.V.Move(1)=previousMove;
            S=solvePressureFlow(N);
            balance=S.H.Q(1)-S.H.Q(2)+S.V.Q(1)-S.V.Q(2);
            testCase.verifyGreaterThan(direction*S.V.Q(1),0);
            testCase.verifyEqual(balance,0,'AbsTol',1e-19);
            testCase.verifyEqual(S.V.Move(1),1);
            testCase.verifyEqual(S.V.Dir,N.V.Dir);
        end
        function fullSequence(testCase)
            stats = replay(exampleNet());
            testCase.verifyTrue(stats.breakthrough);
            testCase.verifyLessThan(stats.maxBalance,1e-19);
            testCase.verifyLessThan(stats.maxResidual,1e-19);
            testCase.verifyGreaterThanOrEqual(stats.minOrientedFlow,-1e-19);
            testCase.verifyEqual(stats.regime2Count,0);
            testCase.verifyEqual(stats.solveCalls,stats.steps+1);
        end
        function mainStructure(testCase)
            source = fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))),'main.m'));
            testCase.verifyEqual(numel(strfind(source,'Net = solvePressureFlow(Net);')),2);
            testCase.verifyTrue(contains(source,'Net.k = 3.29015;'));
            testCase.verifyTrue(contains(source,'Net.P_crit_width = 4;'));
        end
        function defaultGeometrySequence(testCase)
            N=exampleNet();N.H.A=N.H.A*pi*(100e-6)^2/1e-6;
            N.V.A=N.V.A*pi*(100e-6)^2/1e-6;N.H.P0=1500;
            stats=replay(N);
            testCase.verifyTrue(stats.breakthrough);
            testCase.verifyLessThan(stats.maxBalance,1e-19);
            testCase.verifyLessThan(stats.maxResidual,1e-19);
            testCase.verifyGreaterThanOrEqual(stats.minOrientedFlow,-1e-19);
        end
        function validatorAcceptsCurrentLaw(testCase)
            report=currentFixture('none');
            testCase.verifyTrue(report.allCorrect);
        end
        function validatorAcceptsHeldCurrentLaw(testCase)
            report=currentFixture('held');
            testCase.verifyTrue(report.allCorrect);
        end
        function validatorRejectsCorruption(testCase,damagedField)
            report=currentFixture(damagedField);
            testCase.verifyGreaterThan(report.errors,0);
        end
        function transitionEdgesAndCenter(testCase,transitionOffset)
            N=exampleNet(); [~,critical]=thresholds(N);
            pressure=critical+transitionOffset;
            r=sqrt(1e-6/pi);
            b=2*N.k*N.sigma/r*sin(N.theta)*(N.mu1/N.sigma)^(1/3);
            a=8*N.mu1*N.L/r^2+N.xi*(N.mu1+N.mu2)/r;
            weight=(transitionOffset+2)/4;
            expected=1e-6*((1-weight)*(pressure/b)^3+weight*pressure/a);
            f=capillaryEquation(N,pressure,0,1e-6,0,1,0,1);
            testCase.verifyEqual(-f,expected,'AbsTol',1e-20);
        end
        function wettingPhaseFromAngle(testCase,contactAngle)
            N=exampleNet(); N.theta=contactAngle;
            mu=[N.mu1,N.mu2]; mu=mu(1+(contactAngle>=pi/2));
            r=sqrt(1e-6/pi);
            b=2*N.k*N.sigma/r*sin(contactAngle)*(mu/N.sigma)^(1/3);
            f=capillaryEquation(N,1,0,1e-6,0,1,0,1);
            testCase.verifyEqual(-f,1e-6*(1/b)^3,'AbsTol',1e-20);
        end
        function widthIsFullWidthAndAdjustable(testCase)
            N=exampleNet(); N.P_crit_width=8; [~,critical]=thresholds(N);
            pressure=critical-2;
            r=sqrt(1e-6/pi);
            b=2*N.k*N.sigma/r*sin(N.theta)*(N.mu1/N.sigma)^(1/3);
            a=8*N.mu1*N.L/r^2+N.xi*(N.mu1+N.mu2)/r;
            w=0.103515625; % quintic weight at t=1/4.
            expected=1e-6*((1-w)*(pressure/b)^3+w*pressure/a);
            f=capillaryEquation(N,pressure,0,1e-6,0,1,0,1);
            testCase.verifyEqual(-f,expected,'AbsTol',1e-20);
        end
        function networkSolvesTransition(testCase,transitionOffset)
            N=smallNet(1,1); [~,critical]=thresholds(N);
            dp=critical+transitionOffset;
            flow=-capillaryEquation(N,dp,0,1e-6,0,1,0,1);
            waterResistance=8*pi*N.mu1*N.L/(1e-6)^2;
            N.H.P0=dp+flow*waterResistance;
            S=solvePressureFlow(N);
            testCase.verifyEqual(S.H.P0-S.P(1),dp,'AbsTol',1e-7);
            testCase.verifyEqual(S.H.Q,[flow,flow],'AbsTol',1e-19);
        end
        function derivativeContinuousAtEdges(testCase,transitionOffset)
            N=exampleNet(); [~,critical]=thresholds(N);
            pressure=critical+transitionOffset;
            [~,left]=capillaryEquation(N,pressure-1e-7,0,1e-6,0,1,0,1);
            [~,right]=capillaryEquation(N,pressure+1e-7,0,1e-6,0,1,0,1);
            testCase.verifyEqual(left,right,'RelTol',1e-5,'AbsTol',1e-20);
        end
        function viscousResistanceUsesLengthsAndXi(testCase)
            N=exampleNet(); N.mu1=0.00096; N.mu2=0.00419;
            area=pi*(0.0005)^2;
            % L=9 mm, Sat=1/2: A_class=741.6; A_add=309.8172195053.
            expected=area*20/(741.6+309.8172195053289);
            f=capillaryEquation(N,20,0,area,0.5,1,0,1);
            testCase.verifyEqual(-f,expected,'AbsTol',1e-20);
        end
        function nonmonotoneDerivativeRemainsExact(testCase)
            N=exampleNet(); N.mu1=0.00096; N.mu2=0.00419;
            radius=5e-6; area=pi*radius^2;
            pressure=N.coef*radius^(-5/4); h=1e-4;
            [~,derivative]=capillaryEquation(N,pressure,0,area,0.5,1,0,1);
            fp=capillaryEquation(N,pressure+h,0,area,0.5,1,0,1);
            fm=capillaryEquation(N,pressure-h,0,area,0.5,1,0,1);
            testCase.verifyGreaterThan(derivative,0); % dQ/dp<0 is not clipped.
            testCase.verifyEqual(derivative,(fp-fm)/(2*h),'RelTol',1e-6,'AbsTol',1e-20);
        end
        function invalidWidthRejected(testCase)
            N=exampleNet(); N.P_crit_width=0;
            testCase.verifyError(@() solvePressureFlow(N), ...
                'MATLAB:solvePressureFlow:expectedPositive');
        end
        function mainParametersNotExposedInRun(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            source=fileread(fullfile(root,'run.m'));
            testCase.verifyFalse(contains(source,'Net.k'));
            testCase.verifyFalse(contains(source,'Net.coef'));
            testCase.verifyFalse(contains(source,'Net.xi'));
            testCase.verifyFalse(contains(source,'P_crit_width'));
        end
    end
end

function report=currentFixture(damage)
root=fileparts(fileparts(mfilename('fullpath')));
if ~isfolder(fullfile(root,'tmp')),mkdir(fullfile(root,'tmp'));end
directory=tempname(fullfile(root,'tmp'));mkdir(directory);
parameters=smallNet(1,3);
if strcmp(damage,'held')
    parameters.H.P0=0;
end
Net=calcTimeStep(solvePressureFlow(calcCanMove(parameters)));
switch damage
    case 'flow',Net.H.Q(1)=Net.H.Q(1)+1e-8;
    case 'move',Net.H.Move(1)=3;
    case 'regime',Net.H.Regime(1)=2;
end
result=struct('directory',directory,'steps',0,'totalTime',0,'totalComputeTime',0, ...
    'status','Остановлено пользователем.');
save(fullfile(directory,'parameters.mat'),'parameters');
saveSimulationStep(Net,result,0,0);
save(fullfile(directory,'summary.mat'),'Net','result');
report=checkResults(directory);
end

function N = exampleNet()
N=struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',0.07, ...
    'theta',pi/4,'k',3.29015,'coef',6.644123616564944e-4, ...
    'xi',30.079341699546497,'P_crit_width',4,'VerticalBC',false);
N.H.A=1e-6*[1 1 1 1;1 2 1 1;1 1 1 1];
N.V.A=1e-6*[1 1 1;1 1 1;1 5 1;1 1 1];
N.H.P0=1000;N.V.P0=200;
N=initialize(N);
end

function N = initialize(N)
for key={'H','V'}
    name=key{1};[N.(name).Ny,N.(name).Nx]=size(N.(name).A);
    for field={'Sat','State','Move','Dir','Regime'}
        N.(name).(field{1})=zeros(size(N.(name).A));
    end
end
N.H.State(:,1)=1;N.H.Move(:,1)=1;N.H.Dir(:,1)=1;N.H.Regime(:,1)=3;
end

function N = smallNet(direction,previousMove)
N=exampleNet();N.H.A=1e-6*ones(1,2);N.V.A=1e-6*ones(2,1);N=initialize(N);
N.H.P0=direction*1000;N.H.Dir(1)=direction;N.H.Move(1)=previousMove;
end

function [pc,critical] = thresholds(N)
r=sqrt(1e-6/pi);
pc=0;critical=N.coef*r^(-5/4);
end

function stats = replay(N)
stats=struct('breakthrough',false,'maxBalance',0,'maxResidual',0, ...
    'minOrientedFlow',0,'regime2Count',0,'steps',0,'solveCalls',0);
for step=0:200
    if step>0
        N=calcSaturation(N);N=calcState(N);N=calcCanMove(N);
    end
    N=solvePressureFlow(N);stats.solveCalls=stats.solveCalls+1;
    N=calcTimeStep(N);stats.steps=step;
    balance=N.H.Q(:,1:end-1)-N.H.Q(:,2:end)+N.V.Q(1:end-1,:)-N.V.Q(2:end,:);
    stats.maxBalance=max(stats.maxBalance,max(abs(balance(:))));
    np=numel(N.P);nh=numel(N.H.Q);nv=numel(N.V.Q);
    f=calcResidualJacobian(N,[N.P(:);N.H.Q(:);N.V.Q(:)], ...
        reshape(1:np,size(N.P)),reshape(np+(1:nh),size(N.H.Q)),reshape(np+nh+(1:nv),size(N.V.Q)));
    stats.maxResidual=max(stats.maxResidual,max(abs(f)));
    for key={'H','V'}
        C=N.(key{1});q=C.Dir(C.State==1).*C.Q(C.State==1);
        stats.minOrientedFlow=min([stats.minOrientedFlow;q(:)]);
        stats.regime2Count=stats.regime2Count+nnz(C.Regime==2);
    end
    stats.breakthrough=any(N.H.State(:,end)==2);
    if stats.breakthrough || ~isfinite(N.dt),break;end
end
fprintf('Replay: steps=%d solves=%d balance=%.3g residual=%.3g minDirQ=%.3g\n', ...
    stats.steps,stats.solveCalls,stats.maxBalance,stats.maxResidual,stats.minOrientedFlow);
end
