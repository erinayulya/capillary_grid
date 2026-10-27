classdef testSimulationRecovery < matlab.unittest.TestCase
    properties
        Folder
    end
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'reporting')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'solver')));
        end
    end
    methods (TestMethodSetup)
        function temporaryResults(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
        end
    end
    methods (Test)
        function noSavedRuns(testCase)
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyFalse(info.found);
            testCase.verifyFalse(info.canResume);
        end
        function completedLatestDoesNotSelectOlderFailure(testCase)
            testCase.createRun('run_20261027_120000','Ошибка расчёта: test',0,1);
            folder = testCase.createRun('run_20261027_120001','Установилось стационарное течение.',0,1);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyEqual(info.directory,folder);
            testCase.verifyTrue(info.completed);
            testCase.verifyFalse(info.canResume);
        end
        function legacyCompletion(testCase)
            testCase.createRun('run_20261027_120000','Вторая фаза достигла правой границы.',0,1);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.completed);
            testCase.verifyFalse(info.canResume);
        end
        function numericFolderSuffix(testCase)
            testCase.createRun('run_20261027_120000_2','Расчёт не завершён.',0,1);
            folder = testCase.createRun('run_20261027_120000_10','Расчёт не завершён.',0,1);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyEqual(info.directory,folder);
            testCase.verifyTrue(info.canResume);
        end
        function missingSummaryCanUseSnapshot(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',[0 2],2);
            delete(fullfile(folder,'summary.mat'));
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.canResume);
            testCase.verifyEqual(info.step,2);
        end
        function corruptedSummaryCanUseSnapshot(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',0,1);
            testCase.damage(fullfile(folder,'summary.mat'));
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.canResume);
        end
        function damagedLastSnapshotFallsBackWithinLatestRun(testCase)
            folder = testCase.createRun('run_20261027_120000','Ошибка расчёта: test',[0 2],2);
            testCase.damage(fullfile(folder,'step_000002.mat'));
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.canResume);
            testCase.verifyEqual(info.step,0);
            testCase.verifyEqual(info.resume.skippedSnapshots,{'step_000002.mat'});
        end
        function wrongStepNumberIsRejected(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',[0 2],2);
            file = fullfile(folder,'step_000002.mat');
            step = 99; save(file,'step','-append');
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyEqual(info.step,0);
        end
        function missingStateIsRejected(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',[0 2],2);
            file = fullfile(folder,'step_000002.mat');
            data = load(file); data.solvedNet.H = rmfield(data.solvedNet.H,'Sat');
            save(file,'-struct','data');
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyEqual(info.step,0);
        end
        function lastSavedCountersAndStateArePreserved(testCase)
            folder = testCase.createRun('run_20261027_120000','Остановка: достигнут лимит 4 шагов.',[0 3 4],3);
            file = fullfile(folder,'step_000004.mat');
            snapshot = load(file);
            result = struct('steps',99,'totalTime',99,'totalComputeTime',99,'saveStride',3);
            save(fullfile(folder,'summary.mat'),'result','-append');
            resume = prepareSimulationResume(folder);
            testCase.verifyEqual(resume.snapshot.solvedNet,snapshot.solvedNet);
            testCase.verifyEqual(resume.result.steps,4);
            testCase.verifyEqual(resume.result.totalTime,snapshot.elapsedTime);
            testCase.verifyEqual(resume.result.totalComputeTime,snapshot.totalComputeTime);
            testCase.verifyEqual(resume.saveStride,3);
            testCase.verifyEqual(resume.maxSteps,30004);
            testCase.verifyEqual(resume.historyFiles,{'step_000000.mat','step_000003.mat','step_000004.mat'});
        end
        function noSnapshotDoesNotFallBackToOlderRun(testCase)
            testCase.createRun('run_20261027_120000','Ошибка расчёта: test',0,1);
            folder = testCase.createRun('run_20261027_120001','Ошибка расчёта: test',[],1);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyEqual(info.directory,folder);
            testCase.verifyFalse(info.canResume);
            testCase.verifyFalse(info.completed);
        end
        function inspectionDoesNotWriteToSource(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',[0 2],2);
            file = fullfile(folder,'step_000002.mat');
            before = testCase.bytes(file);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.canResume);
            testCase.verifyEqual(testCase.bytes(file),before);
        end
        function stationarityIsRestoredWhenPresent(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',0,1);
            data = load(fullfile(folder,'step_000000.mat'));
            stationarity = checkSteadyState(data.solvedNet,[]);
            save(fullfile(folder,'step_000000.mat'),'stationarity','-append');
            resume = prepareSimulationResume(folder);
            testCase.verifyEqual(resume.stationarity,stationarity);
        end
    end
    methods (Access=private)
        function folder = createRun(testCase,name,status,steps,stride)
            folder = fullfile(testCase.Folder,name); mkdir(folder);
            N = recoveryNet(); parameters = N;
            result = struct('status',status,'steps',max([0 steps]),'totalTime',0, ...
                'saveStride',stride,'startedAt','2026-10-27 12:00:00');
            save(fullfile(folder,'parameters.mat'),'parameters');
            save(fullfile(folder,'summary.mat'),'result','parameters');
            for step = steps
                solvedNet = N; solvedNet.H.Sat(1) = 0.1+0.01*step;
                Net = solvedNet; elapsedTime = step*0.2; dtUsed = 0.2;
                totalComputeTime = step*0.01;
                save(fullfile(folder,sprintf('step_%06d.mat',step)), ...
                    'Net','solvedNet','step','elapsedTime','dtUsed','totalComputeTime');
            end
        end
        function damage(~,file)
            fid = fopen(file,'w'); cleanup = onCleanup(@() fclose(fid));
            fprintf(fid,'interrupted MAT write');
        end
        function content = bytes(~,file)
            fid = fopen(file,'rb'); cleanup = onCleanup(@() fclose(fid));
            content = fread(fid,Inf,'*uint8');
        end
    end
end

function N = recoveryNet()
N = struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2,'theta',pi/4, ...
    'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
    'coef',6.644123616564944e-4,'P_crit_width',4,'dt',0.2,'P',100);
N.H = struct('Nx',2,'Ny',1,'P0',1500,'A',[1 1]*pi*1e-8, ...
    'Sat',[0.1 0],'State',[1 0],'Dir',[1 0],'Move',[1 0], ...
    'Regime',[3 0],'Q',[1 1]*1e-10);
N.V = struct('Nx',1,'Ny',2,'P0',200,'A',[1;1]*pi*1e-8, ...
    'Sat',[0;0],'State',[0;0],'Dir',[0;0],'Move',[0;0], ...
    'Regime',[0;0],'Q',[0;0]);
end
