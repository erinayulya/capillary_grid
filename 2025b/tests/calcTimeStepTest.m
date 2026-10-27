classdef calcTimeStepTest < matlab.unittest.TestCase
    % Аналитическая вязкая оценка шага и прежнее продвижение по Q.
    properties (TestParameter)
        saturation = {0,0.35,0.9}
        regime = {1,3}
        blockedMove = {0,2,3}
        nonpositivePressure = {0,-100}
    end
    methods (TestClassSetup)
        function paths(testCase)
            savedPath=path;
            testCase.addTeardown(@() path(savedPath));
            setupProject;
        end
    end
    methods (Test)
        function matchesViscousIntegral(testCase,saturation)
            N=exampleNet(); N.H.Sat(1)=saturation;
            expected=travelTime(N,N.H,1,700);
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function independentOfFlowAndRegime(testCase,regime)
            N=exampleNet(); N.H.Regime(1)=regime;
            expected=travelTime(N,N.H,1,700);
            N.H.Q(:)=0;
            C=calcTimeStep(N);
            N.H.Q(:)=-1;
            D=calcTimeStep(N);
            testCase.verifyEqual([C.dt,D.dt],[expected,expected], ...
                'AbsTol',1e-12,'RelTol',1e-12);
        end
        function horizontalReverseUsesLocalPressure(testCase)
            N=exampleNet(); N.H.State=[0,1]; N.H.Move=[0,1];
            N.H.Dir=[0,-1]; N.H.P0=-1000; N.P=-300;
            expected=travelTime(N,N.H,2,300);
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function verticalInletUsesBoundaryPressure(testCase)
            N=exampleNet(); N.H.State(:)=0; N.H.Move(:)=0;
            N.VerticalBC=true; N.V.P0=1200;
            N.V.State(1)=1; N.V.Move(1)=1; N.V.Dir(1)=1;
            expected=travelTime(N,N.V,1,900);
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function verticalReverseUsesOutletPressure(testCase)
            N=exampleNet(); N.H.State(:)=0; N.H.Move(:)=0;
            N.VerticalBC=true; N.P=-300;
            N.V.State(2)=1; N.V.Move(2)=1; N.V.Dir(2)=-1;
            expected=travelTime(N,N.V,2,300);
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function choosesMinimumAcrossOrientations(testCase)
            N=exampleNet(); N.H.Sat(1)=0.7;
            N.VerticalBC=true; N.V.P0=1000; N.V.A(1)=4*N.H.A(1);
            N.V.State(1)=1; N.V.Move(1)=1; N.V.Dir(1)=1; N.V.Sat(1)=0.2;
            expected=min(travelTime(N,N.H,1,700),travelTime(N,N.V,1,700));
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function excludesBlockedMeniscus(testCase,blockedMove)
            N=exampleNet(); N.H.Move=[blockedMove,1];
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,Inf);
        end
        function excludesNonpositivePressure(testCase,nonpositivePressure)
            N=exampleNet(); N.H.P0=N.P+nonpositivePressure;
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,Inf);
        end
        function excludesCompletedMeniscus(testCase)
            N=exampleNet(); N.H.Sat(1)=1-1e-13;
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,Inf);
        end
        function finishedNetworkDoesNotWarn(testCase)
            N=exampleNet(); N.H.State=[1,2]; N.H.Move=[2,0];
            N.H.Sat=[0,1]; N.H.Dir=[1,0];
            output=evalc('C=calcTimeStep(N);');
            testCase.verifyEqual(C.dt,Inf);
            testCase.verifyEmpty(output);
        end
        function stoppedBeforeOutletStillWarns(testCase)
            N=exampleNet(); N.H.Move=[2,0];
            output=evalc('C=calcTimeStep(N);');
            testCase.verifyEqual(C.dt,Inf);
            testCase.verifyTrue(contains(output,'Подвижных капилляров нет.'));
        end
        function zeroAdditionalResistance(testCase)
            N=exampleNet(); N.xi=0;
            expected=travelTime(N,N.H,1,700);
            C=calcTimeStep(N);
            testCase.verifyEqual(C.dt,expected,'AbsTol',1e-12,'RelTol',1e-12);
        end
        function changesOnlyTimeStep(testCase)
            N=exampleNet(); C=calcTimeStep(N);
            testCase.verifyEqual(rmfield(C,'dt'),rmfield(N,'dt'));
        end
        function saturationStillUsesActualFlow(testCase)
            N=exampleNet(); N.H.Sat(1)=0.2; N.H.Q(1)=2e-12;
            C=calcTimeStep(N);
            expected=0.2+N.H.Q(1)/N.H.A(1)*C.dt/N.L;
            D=calcSaturation(C);
            testCase.verifyLessThan(expected,1);
            testCase.verifyEqual(D.H.Sat(1),expected,'AbsTol',1e-12);
        end
    end
end

function N=exampleNet()
N=struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'xi',30, ...
    'VerticalBC',false,'P',300,'dt',Inf);
N.H=struct('A',pi*(100e-6)^2*[1,2],'P0',1000,'Ny',1,'Nx',2, ...
    'State',[1,0],'Move',[1,0],'Dir',[1,0],'Sat',[0,0], ...
    'Q',[1e-9,1e-9],'Regime',[3,0]);
N.V=struct('A',pi*(100e-6)^2*[1;2],'P0',0,'Ny',2,'Nx',1, ...
    'State',[0;0],'Move',[0;0],'Dir',[0;0],'Sat',[0;0], ...
    'Q',[0;0],'Regime',[0;0]);
end

function t=travelTime(N,C,index,p)
% Независимый эталон: квадратура сопротивления, а не формула calcTimeStep.
r=sqrt(C.A(index)/pi);
drag=@(s) 8*N.L/r^2*(N.mu1*(1-s)+N.mu2*s)+N.xi*(N.mu1+N.mu2)/r;
t=N.L/p*integral(drag,C.Sat(index),1,'AbsTol',1e-12,'RelTol',1e-12);
end
