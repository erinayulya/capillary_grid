classdef testSimulationRecovery < matlab.unittest.TestCase
    properties
        Folder
        Root
    end
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.Root = root;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'reporting')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'solver')));
        end
    end
    methods (TestMethodSetup)
        function temporaryResults(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
            clear simulationReport
            simulationStorageOptions('reset');
            testCase.addTeardown(@() clearRecoverySession());
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
        function continuationKeepsHistoryAndCounters(testCase)
            folder = testCase.createRun('run_20261027_120000','Ошибка расчёта: test',[0 3 4],3);
            resume = prepareSimulationResume(folder);
            original = testCase.bytes(resume.snapshotFile);
            N = resume.snapshot.solvedNet;
            simulationReport('resume',N,resume,testCase.Folder);
            monitor = checkSteadyState(N,resume.stationarity);
            testCase.assertEqual(simulationReport('next',N,monitor),'Продолжить');
            N.H.Sat(1) = 0.7;
            simulationReport('snapshot',N,monitor);
            result = simulationReport('finish',N,struct('stop',false));
            testCase.verifyNotEqual(result.directory,folder);
            testCase.verifyEqual(result.resumedFrom,folder);
            testCase.verifyEqual(result.steps,5);
            testCase.verifyEqual(result.totalTime,resume.snapshot.elapsedTime+resume.snapshot.solvedNet.dt);
            testCase.verifyGreaterThanOrEqual(result.totalComputeTime,resume.result.totalComputeTime);
            files = dir(fullfile(result.directory,'step_*.mat'));
            testCase.verifyEqual({files.name}, ...
                {'step_000000.mat','step_000003.mat','step_000004.mat','step_000005.mat'});
            saved = load(fullfile(result.directory,'step_000005.mat'));
            testCase.verifyEqual(saved.solvedNet,N);
            testCase.verifyEqual(saved.stationarity,monitor);
            testCase.verifyEqual(saved.dtUsed,resume.snapshot.solvedNet.dt);
            testCase.verifyEqual(testCase.bytes(resume.snapshotFile),original);
            copied = testCase.bytes(fullfile(result.directory,'step_000004.mat'));
            testCase.verifyEqual(copied,original);
            restarted = prepareSimulationResume(result.directory);
            testCase.verifyEqual(restarted.stationarity,monitor);
        end
        function snapshotKeepsStrideWithoutSummary(testCase)
            folder = fullfile(testCase.Folder,'run_20261027_120000'); mkdir(folder);
            N = recoveryNet();
            result = struct('directory',folder,'steps',0,'totalTime',0, ...
                'totalComputeTime',0,'saveStride',7);
            saveSimulationStep(N,result,0,0,[]);
            resume = prepareSimulationResume(folder);
            testCase.verifyEqual(resume.saveStride,7);
            testCase.verifyEqual(resume.maxSteps,70000);
        end
        function immediateFailurePreservesResumedState(testCase)
            folder = testCase.createRun('run_20261027_120000','Расчёт не завершён.',[0 2],2);
            resume = prepareSimulationResume(folder);
            N = resume.snapshot.solvedNet;
            simulationReport('resume',N,resume,testCase.Folder);
            [result,restored] = simulationReport('fail',N,MException('test:Fail','test failure'));
            testCase.verifyEqual(restored,N);
            testCase.verifyEqual(result.steps,2);
            testCase.verifyEqual(result.totalTime,resume.snapshot.elapsedTime);
            testCase.verifyEqual(result.totalComputeTime,resume.result.totalComputeTime);
            info = inspectLastSimulation(testCase.Folder);
            testCase.verifyTrue(info.canResume);
        end
        function mainResumeMatchesContinuousRun(testCase)
            % Execute the real main and model in a temporary project. Only the
            % reporting limit and closing of unrelated figures are substituted.
            app = fullfile(testCase.Folder,'app'); mkdir(app);
            for name = {'main.m','setupProject.m','model','solver','reporting','mesh','visualization'}
                copyfile(fullfile(testCase.Root,name{1}),fullfile(app,name{1}));
            end
            resetFile = fullfile(app,'reporting','resetSimulationWorkspace.m');
            text = fileread(resetFile);
            text = strrep(text,"delete(findall(groot,'Type','figure'));",'');
            testCase.writeText(resetFile,text);
            reportFile = fullfile(app,'reporting','simulationReport.m');
            text = fileread(reportFile);
            text = strrep(text,'= simulationReport(action','= recoveryReport(action');
            testCase.writeText(fullfile(app,'reporting','recoveryReport.m'),text);
            testCase.writeText(reportFile,sprintf([ ...
                'function varargout = simulationReport(varargin)\n' ...
                'if any(strcmp(varargin{1},{''start'',''resume''}))\n' ...
                ' data=load(fullfile(fileparts(mfilename(''fullpath'')),''test-limit.mat''));\n' ...
                ' varargin{4}=fullfile(fileparts(fileparts(mfilename(''fullpath''))),''results'');\n' ...
                ' if strcmp(varargin{1},''start''), varargin{5}=data.limit;\n' ...
                ' else, varargin{3}.maxSteps=data.limit; end\n' ...
                'end\n' ...
                '[varargout{1:nargout}]=recoveryReport(varargin{:});\nend\n']));
            oldPath = path; oldFolder = pwd;
            testCase.addTeardown(@() restoreRecoveryPath(oldFolder,oldPath));
            cd(app); clear setupProject
            setupProject;
            clear simulationReport resetSimulationWorkspace
            testCase.assertEqual(which('main'),fullfile(app,'main.m'));
            testCase.assertEqual(which('solvePressureFlow'),fullfile(app,'solver','solvePressureFlow.m'));
            N = recoveryNet(); N = rmfield(N,{'dt','P'});
            N.H = struct('P0',4000,'A',ones(1,12)*pi*1e-8);
            N.V = struct('P0',200,'A',ones(2,11)*pi*1e-8);
            limit = 6; save(fullfile(app,'reporting','test-limit.mat'),'limit');
            [continuous,expected] = executeRecoveryMain(N,'');
            limit = 3; save(fullfile(app,'reporting','test-limit.mat'),'limit');
            [~,interrupted] = executeRecoveryMain(N,'');
            checkpoint = prepareSimulationResume(interrupted.directory);
            original = testCase.bytes(checkpoint.snapshotFile);
            limit = 6; save(fullfile(app,'reporting','test-limit.mat'),'limit');
            [continued,actual] = executeRecoveryMain([],interrupted.directory);
            testCase.verifyEqual(actual.steps,6);
            testCase.verifyEqual(continued,continuous);
            testCase.verifyEqual(actual.totalTime,expected.totalTime);
            testCase.verifyEqual(actual.stationarity,expected.stationarity);
            testCase.verifyEqual(testCase.bytes(checkpoint.snapshotFile),original);
            testCase.verifyNotEqual(actual.directory,interrupted.directory);
            for step = 4:6
                name = sprintf('step_%06d.mat',step);
                a = load(fullfile(actual.directory,name));
                b = load(fullfile(expected.directory,name));
                testCase.verifyEqual(a.solvedNet,b.solvedNet);
                testCase.verifyEqual(a.stationarity,b.stationarity);
                testCase.verifyEqual(a.elapsedTime,b.elapsedTime);
            end
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
        function writeText(~,file,text)
            fid = fopen(file,'w','n','UTF-8'); cleanup = onCleanup(@() fclose(fid));
            fprintf(fid,'%s',text);
        end
    end
end

function [state,result] = executeRecoveryMain(parameters,source)
if isempty(source)
    runParameters = parameters;
    runRecordResults = true;
    runModelOptions = struct('includeAadd',false,'meniscusModel',1);
else
    runResume = source;
end
main;
state = Net;
result = simulationResult;
end

function clearRecoverySession()
clear simulationReport recoveryReport
simulationStorageOptions('reset');
end

function restoreRecoveryPath(folder,originalPath)
cd(folder); path(originalPath);
clear simulationReport recoveryReport resetSimulationWorkspace setupProject main
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
