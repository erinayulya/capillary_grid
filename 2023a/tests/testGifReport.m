classdef testGifReport < matlab.unittest.TestCase
    properties
        Folder
    end
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'reporting')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'visualization')));
        end
    end
    methods (TestMethodSetup)
        function fixture(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = folder.Folder;
            buildFixture(testCase.Folder);
        end
    end
    methods (Test)
        function everyGifFrameUsesSolvedState(testCase)
            gif = writeSaturationPressureGif(testCase.Folder,[],0.1,false);
            [pdf,result] = writeSimulationReport(testCase.Folder,2,gif);
            testCase.verifyTrue(isfile(pdf));
            testCase.verifyEqual(result.reportSteps,[0 2 4 5]);
            testCase.verifyEqual(numel(imfinfo(gif)),numel(result.reportSteps));
            testCase.verifyEqual(result.reportStride,2);
            metadata = load(fullfile(testCase.Folder,'summary.mat'));
            testCase.verifyEqual(metadata.result,result);
        end
        function mismatchedGifPreservesExistingReport(testCase)
            gif = fullfile(testCase.Folder,'one_frame.gif');
            imwrite(uint8(zeros(10,10)),[0 0 0;1 1 1],gif,'gif');
            report = fullfile(testCase.Folder,'report.pdf');
            fid = fopen(report,'w'); fprintf(fid,'previous report'); fclose(fid);
            testCase.verifyError(@() writeSimulationReport(testCase.Folder,2,gif), ...
                'writeSimulationReport:FrameCount');
            testCase.verifyEqual(fileread(report),'previous report');
        end
    end
end

function buildFixture(folder)
N = struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2, ...
    'theta',pi/4,'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
    'coef',6.644123616564944e-4,'P_crit_width',4,'dt',0.1,'P',[100 50;110 55]);
N.H = struct('Nx',3,'Ny',2,'P0',1500,'A',pi*1e-8*ones(2,3), ...
    'Sat',zeros(2,3),'State',zeros(2,3),'Dir',zeros(2,3), ...
    'Move',zeros(2,3),'Regime',zeros(2,3),'Q',reshape(1:6,2,3)*1e-10);
N.V = struct('Nx',2,'Ny',3,'P0',200,'A',pi*1e-8*ones(3,2), ...
    'Sat',zeros(3,2),'State',zeros(3,2),'Dir',zeros(3,2), ...
    'Move',zeros(3,2),'Regime',zeros(3,2),'Q',reshape(-3:2,3,2)*1e-10);
N.H.State(:,1)=1; N.H.Dir(:,1)=1; N.H.Move(:,1)=1; N.H.Regime(:,1)=3;
parameters = N;
result = struct('startedAt','2026-10-27 12:00:00','steps',5,'totalTime',0.5, ...
    'totalComputeTime',0.06,'status','Тестовый расчёт.','saveStride',2, ...
    'directory',folder,'pdf','');
save(fullfile(folder,'parameters.mat'),'parameters');
for step = [0 2 4 5]
    N.H.Sat(:,1)=0.1+0.05*step;
    current = result; current.steps=step; current.totalTime=step*0.1;
    saveSimulationStep(N,current,0.1,0.01);
    % Legacy display fields deliberately differ from the GIF's solved state.
    snapshot = load(fullfile(folder,sprintf('step_%06d.mat',step)));
    snapshot.Net.P(:)=-999;
    save(fullfile(folder,sprintf('step_%06d.mat',step)),'-struct','snapshot');
end
Net=N;
save(fullfile(folder,'summary.mat'),'result','parameters','Net');
end
