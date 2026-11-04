classdef residualClusterReportTest < matlab.unittest.TestCase
    properties
        Folder
    end
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'reporting')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'visualization')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'analysis','residual_saturation_analysis')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'analysis','front_analysis')));
        end
    end
    methods (TestMethodSetup)
        function fixture(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;
            buildRun(fixture.Folder);
        end
    end
    methods (Test)
        function enabledUsesLastSnapshotAndAddsClosingPages(testCase)
            before=path;
            [pdf,result]=writeSimulationReport(testCase.Folder,10,'', ...
                struct('savedFrames',true,'analyzeClusters',true));
            saved=load(fullfile(result.clusterAnalysis.outputDirectory,'residual_saturation.mat'));
            testCase.verifyEqual(path,before);
            testCase.verifyTrue(isfile(pdf));
            testCase.verifyEqual(result.clusterAnalysis.step,10);
            testCase.verifyEqual(result.clusterAnalysis.firstPage,6);
            testCase.verifyEqual(result.clusterAnalysis.lastPage,7);
            testCase.verifyEqual(result.reportPageCount,7);
            testCase.verifyEqual(saved.residualAnalysis.clusters{1,2:4},[2 1 1]);
        end
        function disabledKeepsOriginalPageCount(testCase)
            [~,result]=writeSimulationReport(testCase.Folder,10,'',struct('savedFrames',true));
            testCase.verifyFalse(result.clusterAnalysis.enabled);
            testCase.verifyEqual(result.reportPageCount,5);
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder,'analysis')));
        end
        function regenerationDoesNotDuplicateClusterPages(testCase)
            options=struct('savedFrames',true,'analyzeClusters',true);
            [~,first]=writeSimulationReport(testCase.Folder,10,'',options);
            [~,second]=writeSimulationReport(testCase.Folder,10,'',options);
            testCase.verifyEqual(first.reportPageCount,second.reportPageCount);
            testCase.verifyEqual(second.clusterAnalysis.lastPage,second.reportPageCount);
        end
        function dialogsExposeExplicitClusterChoice(testCase)
            data=load(fullfile(testCase.Folder,'summary.mat'),'result');
            report=showSimulationReportDialog(data.result);
            testCase.addTeardown(@() deleteIfValid(report));
            testCase.verifyEmpty(findall(report,'Tag','reportAnalyzeClusters'));
            front=showFrontAnalysisDialog();
            testCase.addTeardown(@() deleteIfValid(front));
            choice=findall(front,'Tag','frontAnalyzeClusters');
            testCase.verifyEqual(numel(choice),1);
            testCase.verifyFalse(choice.Value);
            delete(front);
            dialog=showResidualAnalysisDialog(testCase.Folder);
            testCase.addTeardown(@() deleteIfValid(dialog));
            source=findall(dialog,'Tag','residualSourceDirectory');
            choice=findall(dialog,'Tag','residualAnalyzeClusters');
            generate=findall(dialog,'Tag','residualGenerate');
            choice.Value=false;
            generate.ButtonPushedFcn(generate,[]);
            testCase.verifyEqual(dialog.UserData.sourceDirectory,source.Value);
            testCase.verifyFalse(dialog.UserData.analyzeClusters);
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder,'analysis')));
        end
        function frontReportIncludesClustersInFlatAnalysisFolder(testCase)
            previousPath=path;
            result=analyzeMeniscusFront(testCase.Folder,[],.1, ...
                struct('createGif',false,'createPdf',true,'analyzeClusters',true));
            testCase.verifyEqual(path,previousPath);
            testCase.verifyEqual(result.outputDirectory,fullfile(testCase.Folder,'analysis'));
            testCase.verifyTrue(isfile(result.pdfPath));
            testCase.verifyEqual(result.pdfPageCount,3);
            testCase.verifyEqual(result.residualAnalysis.step,10);
            testCase.verifyEqual(result.residualAnalysis.clusters{1,2:4},[2 1 1]);
            testCase.verifyTrue(isfile(fullfile(result.outputDirectory,'cluster_sizes.csv')));
            testCase.verifyFalse(isfolder(fullfile(result.outputDirectory,'front_analysis')));
            testCase.verifyFalse(isfolder(fullfile(result.outputDirectory,'residual_saturation_analysis')));
        end
        function frontWithoutClusterOptionDoesNotAnalyzeClusters(testCase)
            result=analyzeMeniscusFront(testCase.Folder,[],.1, ...
                struct('createGif',false,'createPdf',false));
            testCase.verifyFalse(result.analyzeClusters);
            testCase.verifyEmpty(result.residualAnalysis);
            testCase.verifyFalse(isfile(fullfile(result.outputDirectory,'cluster_sizes.csv')));
        end
    end
end

function deleteIfValid(fig)
if isgraphics(fig), delete(fig); end
end

function buildRun(folder)
N=struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2, ...
    'theta',pi/4,'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
    'coef',6.644123616564944e-4,'P_crit_width',4,'dt',0.1,'P',[100 50;110 55]);
N.H=struct('Nx',3,'Ny',2,'P0',1500,'A',pi*1e-8*ones(2,3), ...
    'Sat',ones(2,3),'State',2*ones(2,3),'Dir',zeros(2,3), ...
    'Move',zeros(2,3),'Regime',zeros(2,3),'Q',zeros(2,3));
N.V=struct('Nx',2,'Ny',3,'P0',200,'A',pi*1e-8*ones(3,2), ...
    'Sat',ones(3,2),'State',2*ones(3,2),'Dir',zeros(3,2), ...
    'Move',zeros(3,2),'Regime',zeros(3,2),'Q',zeros(3,2));
N.H.State(1,1)=1; N.H.Sat(1,1)=.5; N.H.Dir(1,1)=1; N.H.Move(1,1)=2;
N.V.State(2,1)=1; N.V.Sat(2,1)=.5; N.V.Dir(2,1)=-1; N.V.Move(2,1)=2;
parameters=N;
result=struct('startedAt','2026-11-03 12:00:00','steps',10,'totalTime',1, ...
    'totalComputeTime',.02,'status','Тестовый расчёт.','saveStride',10, ...
    'directory',folder,'pdf','');
save(fullfile(folder,'parameters.mat'),'parameters');
initial=result; initial.steps=0; initial.totalTime=0;
saveSimulationStep(N,initial,0,.01);
saveSimulationStep(N,result,.1,.01);
Net=N;
save(fullfile(folder,'summary.mat'),'result','parameters','Net');
end
