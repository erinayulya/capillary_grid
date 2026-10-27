classdef testSimulationReportModes < matlab.unittest.TestCase
    % Recording is independent of PDF generation; selection keeps endpoints.
    properties (TestParameter)
        selection = struct( ...
            'all',struct('last',5,'stride',1,'expected',0:5), ...
            'everySecond',struct('last',5,'stride',2,'expected',[0 2 4 5]), ...
            'everyThird',struct('last',5,'stride',3,'expected',[0 3 5]), ...
            'divisible',struct('last',6,'stride',3,'expected',[0 3 6]), ...
            'greaterThanRun',struct('last',5,'stride',10,'expected',[0 5]), ...
            'initialOnly',struct('last',0,'stride',3,'expected',0), ...
            'oneStep',struct('last',1,'stride',2,'expected',[0 1]))
    end
    properties
        Folder
    end
    methods (TestClassSetup)
        function reportingPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
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
            simulationStorageOptions('reset');
            testCase.addTeardown(@() clearReportingSession());
        end
    end
    methods (Test)
        function selectedStates(testCase,selection)
            actual = selectSimulationReportSteps(selection.last,selection.stride);
            testCase.verifyEqual(actual,selection.expected);
        end
        function rejectsZeroInterval(testCase)
            testCase.verifyError(@() selectSimulationReportSteps(5,0), ...
                'MATLAB:selectSimulationReportSteps:expectedPositive');
        end
        function rejectsFractionalInterval(testCase)
            testCase.verifyError(@() selectSimulationReportSteps(5,1.5), ...
                'MATLAB:selectSimulationReportSteps:expectedInteger');
        end
        function finishSavesEveryStateWithoutPdf(testCase)
            Net = struct('H',struct('State',[0 0]),'dt',0.2);
            simulationReport('start',Net,true,testCase.Folder);
            simulationReport('snapshot',Net);
            testCase.verifyEqual(simulationReport('next',Net),'Продолжить');
            simulationReport('snapshot',Net);
            result = simulationReport('finish',Net);
            saved = load(fullfile(result.directory,'summary.mat'));
            testCase.verifyEqual(result.steps,1);
            testCase.verifyEqual(saved.result,result);
            testCase.verifyEqual(saved.Net,Net);
            testCase.verifyEqual(numel(dir(fullfile(result.directory,'step_*.mat'))),2);
            testCase.verifyTrue(isfile(fullfile(result.directory,'parameters.mat')));
            testCase.verifyEmpty(result.pdf);
            testCase.verifyFalse(isfile(fullfile(result.directory,'report.pdf')));
        end
        function failureKeepsAcceptedStateWithoutPdf(testCase)
            Net = struct('H',struct('State',[0 0]),'dt',0.2);
            simulationReport('start',Net,true,testCase.Folder);
            simulationReport('snapshot',Net);
            simulationReport('next',Net);
            damaged = Net; damaged.dt = -1;
            [result,restored] = simulationReport('fail',damaged, ...
                MException('test:CalculationFailed','Test calculation failure.'));
            saved = load(fullfile(result.directory,'summary.mat'));
            testCase.verifyEqual(restored,Net);
            testCase.verifyEqual(saved.Net,Net);
            testCase.verifyEqual(result.steps,0);
            testCase.verifyGreaterThanOrEqual(result.failedComputeTime,0);
            testCase.verifySubstring(result.status,'Test calculation failure.');
            testCase.verifyFalse(isfile(fullfile(result.directory,'report.pdf')));
        end
        function finishKeepsLastStepOutsideStride(testCase,selection)
            simulationStorageOptions('set',selection.stride);
            [Net,before,dtUsed] = testCase.recordAcceptedStates(selection.last,10000);
            testCase.verifyStepNumbers(before.result.directory,0:selection.stride:selection.last);

            result = simulationReport('finish',Net,struct('stop',false));

            testCase.verifyStepNumbers(result.directory,selection.expected);
            testCase.verifyLastState(result,Net,before,dtUsed);
        end
        function failureKeepsLastStepOutsideStride(testCase,selection)
            simulationStorageOptions('set',selection.stride);
            [Net,before,dtUsed] = testCase.recordAcceptedStates(selection.last,10000);
            testCase.verifyStepNumbers(before.result.directory,0:selection.stride:selection.last);
            simulationReport('next',Net);
            damaged = Net; damaged.dt = -1;

            [result,restored] = simulationReport('fail',damaged, ...
                MException('test:CalculationFailed','Test calculation failure.'));

            testCase.verifyStepNumbers(result.directory,selection.expected);
            testCase.verifyEqual(restored,Net);
            testCase.verifyLastState(result,Net,before,dtUsed);
            testCase.verifySubstring(result.status,'Test calculation failure.');
            testCase.verifyEqual(result.totalComputeTime, ...
                before.result.totalComputeTime+result.failedComputeTime,'AbsTol',1e-12);
        end
        function stepLimitKeepsLastStepOutsideStride(testCase)
            simulationStorageOptions('set',3);
            [Net,before,dtUsed] = testCase.recordAcceptedStates(2,2);

            testCase.verifyEqual(simulationReport('next',Net),'Стоп');
            result = simulationReport('finish',Net,struct('stop',false));

            testCase.verifyStepNumbers(result.directory,[0 2]);
            testCase.verifyLastState(result,Net,before,dtUsed);
            testCase.verifySubstring(result.status,'лимит 2 шагов');
        end
        function invalidDtKeepsLastStepOutsideStride(testCase)
            simulationStorageOptions('set',3);
            [Net,before,dtUsed] = testCase.recordAcceptedStates(2,10000,Inf);

            testCase.verifyEqual(simulationReport('next',Net),'Стоп');
            result = simulationReport('finish',Net,struct('stop',false));

            testCase.verifyStepNumbers(result.directory,[0 2]);
            testCase.verifyLastState(result,Net,before,dtUsed);
            testCase.verifySubstring(result.status,'нет конечного положительного шага dt');
        end
        function closingDialogKeepsResultsWithoutPdf(testCase)
            Net = struct('H',struct('State',[0 2]),'dt',0.2);
            simulationReport('start',Net,true,testCase.Folder);
            simulationReport('snapshot',Net);
            result = simulationReport('finish',Net);
            fig = showSimulationReportDialog(result);
            testCase.addTeardown(@() closeDialog(fig));
            group = findall(fig,'Type','uibuttongroup');
            interval = findall(fig,'Type','uinumericeditfield');
            everyNth = findall(group,'Text','Каждый N');
            testCase.verifyEqual(char(interval.Enable),'off');
            group.SelectedObject = everyNth;
            group.SelectionChangedFcn(group,[]);
            testCase.verifyEqual(char(interval.Enable),'on');
            delete(fig);
            saved = load(fullfile(result.directory,'summary.mat'));
            testCase.verifyEqual(saved.result,result);
            testCase.verifyFalse(isfile(fullfile(result.directory,'report.pdf')));
        end
    end
    methods (Access=private)
        function [Net,before,dtUsed] = recordAcceptedStates(testCase,lastStep,maxSteps,lastDt)
            Net = struct('H',struct('State',[0 0]),'dt',0.2);
            simulationReport('start',Net,true,testCase.Folder,maxSteps);
            simulationReport('snapshot',Net);
            dtUsed = 0;
            for step = 1:lastStep
                testCase.assertEqual(simulationReport('next',Net),'Продолжить');
                dtUsed = Net.dt;
                Net.dt = step+0.2;
                if nargin >= 4 && step == lastStep, Net.dt = lastDt; end
                simulationReport('snapshot',Net);
            end
            folders = dir(fullfile(testCase.Folder,'run_*'));
            testCase.assertNumElements(folders,1);
            before = load(fullfile(testCase.Folder,folders(1).name,'summary.mat'));
        end
        function verifyStepNumbers(testCase,folder,expected)
            files = dir(fullfile(folder,'step_*.mat'));
            actual = arrayfun(@(file) sscanf(file.name,'step_%d.mat'),files);
            testCase.verifyEqual(sort(actual(:))',expected);
        end
        function verifyLastState(testCase,result,Net,before,dtUsed)
            last = load(fullfile(result.directory,sprintf('step_%06d.mat',result.steps)));
            summary = load(fullfile(result.directory,'summary.mat'));
            testCase.verifyEqual(result.steps,before.result.steps);
            testCase.verifyEqual(last.step,result.steps);
            testCase.verifyEqual(last.Net,Net);
            testCase.verifyEqual(last.solvedNet,Net);
            testCase.verifyEqual(summary.Net,Net);
            testCase.verifyEqual(summary.result,result);
            testCase.verifyEqual(last.dtUsed,dtUsed,'AbsTol',1e-12);
            testCase.verifyEqual(last.elapsedTime,before.result.totalTime,'AbsTol',1e-12);
            testCase.verifyEqual(result.totalTime,before.result.totalTime,'AbsTol',1e-12);
            testCase.verifyEqual(last.totalComputeTime,before.result.totalComputeTime,'AbsTol',1e-12);
            testCase.verifyGreaterThanOrEqual(last.stepComputeTime,0);
            testCase.verifyLessThanOrEqual(last.stepComputeTime,last.totalComputeTime);
            testCase.verifyFalse(isfile(fullfile(result.directory,'report.pdf')));
        end
    end
end

function clearReportingSession()
clear simulationReport
simulationStorageOptions('reset');
end

function closeDialog(fig)
if isvalid(fig), delete(fig); end
end
