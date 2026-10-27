classdef testSteadyState < matlab.unittest.TestCase
    % Breakthrough gates observation; phase motion must not look stationary.
    properties (TestParameter)
        phaseField = {'State','Dir','Move'}
    end
    properties
        Folder
    end
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'solver')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'reporting')));
        end
    end
    methods (TestMethodSetup)
        function outputFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
            clear simulationReport
            testCase.addTeardown(@clearSession);
        end
    end
    methods (Test)
        function noObservationBeforeBreakthrough(testCase)
            N = settledNet(); N.H.State(:)=0; N.H.Sat(:)=0;
            monitor = observe(N,8);
            testCase.verifyFalse(monitor.reached);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEmpty(monitor.reference);
        end
        function breakthroughStartsFreshWindow(testCase)
            N = settledNet(); N.H.State(end)=0; N.H.Sat(end)=0;
            monitor = observe(N,8);
            N.H.State(end)=2; N.H.Sat(end)=1;
            monitor = checkSteadyState(N,monitor);
            testCase.verifyTrue(monitor.justReached);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEqual(monitor.stableSteps,0);
            testCase.verifyEqual(monitor.referenceTime,monitor.breakthroughTime,'AbsTol',1e-12);
            monitor = checkSteadyState(N,monitor);
            testCase.verifyFalse(monitor.justReached);
        end
        function stationaryFlowCanBeNonzero(testCase)
            N = settledNet();
            monitor = observe(N,5);
            testCase.verifyTrue(monitor.stop);
            testCase.verifyGreaterThan(abs(N.H.Q(1)),0);
        end
        function requiresPhysicalObservationTime(testCase)
            monitor = observe(settledNet(),4);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyGreaterThanOrEqual(monitor.stableSteps,3);
        end
        function movingPlateauDoesNotStop(testCase)
            N = movingNet();
            monitor = observe(N,8,0.01);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEqual(monitor.stableSteps,0);
        end
        function rateRejectsMotionHiddenBySmallSteps(testCase)
            N = movingNet(); N.dt=1;
            monitor = observe(N,5);
            testCase.verifyFalse(monitor.stop);
        end
        function accumulatedSmallChangesResetWindow(testCase)
            N = settledNet(); N.H.Sat(1)=0.9;
            monitor = observe(N,4,4e-11);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEqual(monitor.stableSteps,0);
        end
        function phaseCodesResetWindowWithoutSaturationChange(testCase,phaseField)
            N = settledNet(); monitor = observe(N,4);
            N.V.(phaseField)(1)=1;
            monitor = checkSteadyState(N,monitor);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEqual(monitor.stableSteps,0);
        end
        function pressureMustAlsoSettle(testCase)
            N = settledNet(); monitor = observe(N,4);
            N.P=N.P+0.1;
            monitor = checkSteadyState(N,monitor);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyGreaterThan(monitor.pressureChange,0.01);
        end
        function infiniteStepNeedsUnchangedConfirmation(testCase)
            N = settledNet(); N.dt=Inf;
            monitor = checkSteadyState(N,[]);
            testCase.verifyTrue(monitor.confirm);
            testCase.verifyFalse(monitor.stop);
            monitor = checkSteadyState(N,monitor);
            testCase.verifyTrue(monitor.stop);
            testCase.verifyEqual(monitor.time,0,'AbsTol',1e-12);
        end
        function pendingMeniscusPreventsInfiniteStepStop(testCase)
            N = settledNet(); N.dt=Inf;
            monitor = checkSteadyState(N,[]);
            N.V.State(1)=1; N.V.Dir(1)=1; N.V.Move(1)=3;
            monitor = checkSteadyState(N,monitor);
            testCase.verifyFalse(monitor.stop);
            testCase.verifyEqual(monitor.stableSteps,0);
        end
        function infiniteStepWithMovingMeniscusIsNotConfirmed(testCase)
            N = movingNet(); N.dt=Inf;
            monitor = observe(N,2);
            testCase.verifyFalse(monitor.confirm);
            testCase.verifyFalse(monitor.stop);
        end
        function confirmationDoesNotAdvanceReportedTime(testCase)
            N = settledNet(); N.dt=Inf;
            monitor = checkSteadyState(N,[]);
            simulationReport('start',N,true,testCase.Folder);
            simulationReport('snapshot',N);
            answer = simulationReport('next',N,monitor);
            simulationReport('snapshot',N);
            monitor = checkSteadyState(N,monitor);
            result = simulationReport('finish',N,monitor);
            testCase.verifyEqual(answer,'Продолжить');
            testCase.verifyEqual(result.status,'Установилось стационарное течение.');
            testCase.verifyEqual(result.steps,1);
            testCase.verifyEqual(result.totalTime,0,'AbsTol',1e-12);
        end
        function limitAfterBreakthroughKeepsItsReason(testCase)
            N = settledNet(); monitor = checkSteadyState(N,[]);
            simulationReport('start',N,true,testCase.Folder,1);
            simulationReport('snapshot',N);
            simulationReport('next',N,monitor);
            simulationReport('snapshot',N);
            answer = simulationReport('next',N,monitor);
            result = simulationReport('finish',N,monitor);
            testCase.verifyEqual(answer,'Стоп');
            testCase.verifyEqual(result.status,'Остановка: достигнут лимит 1 шагов.');
        end
    end
end

function N = settledNet()
A = pi*(100e-6)^2;
N = struct('P',750,'L',9e-3,'dt',0.25);
N.H = struct('A',[A A],'Sat',[1 1],'State',[2 2], ...
    'Dir',[0 0],'Move',[0 0],'Q',[1e-10 1e-10],'P0',1500);
N.V = struct('A',[A;A],'Sat',[0;0],'State',[0;0], ...
    'Dir',[0;0],'Move',[0;0],'Q',[0;0],'P0',200);
end

function N = movingNet()
N = settledNet(); N.H.State(1)=1; N.H.Sat(1)=0.2;
N.H.Dir(1)=1; N.H.Move(1)=1;
end

function monitor = observe(N,count,increment)
if nargin < 3, increment=0; end
monitor = [];
for k=1:count
    if k>1, N.H.Sat(1)=N.H.Sat(1)+increment; end
    monitor = checkSteadyState(N,monitor);
end
end

function clearSession()
clear simulationReport
end
