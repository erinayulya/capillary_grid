classdef testDisplacingPhase < matlab.unittest.TestCase
    % Physical phases, saved metadata and the actual run -> main path.
    properties (TestParameter)
        modelChoice = struct('viscous',1,'plateau',2)
        phaseCase = struct( ...
            'oil',struct('code','oil','name','Нефть','mu1',1e-3,'mu2',4.3e-3, ...
                'theta',pi/4,'oilFraction',7/12,'initialOil',0,'finalOil',1, ...
                'waterX',[0 1 1.25 2],'oilX',[1 1.25 2 3],'state0Color',[0 .447 .741]), ...
            'water',struct('code','water','name','Вода','mu1',4.3e-3,'mu2',1e-3, ...
                'theta',3*pi/4,'oilFraction',5/12,'initialOil',1,'finalOil',0, ...
                'waterX',[1 1.25 2 3],'oilX',[0 1 1.25 2],'state0Color',[0 0 0]))
    end
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            originalPath = path;
            originalFolder = pwd;
            testCase.addTeardown(@() path(originalPath));
            testCase.addTeardown(@() cd(originalFolder));
            cd(root);
            setupProject;
        end
    end
    methods (Test)
        function legacyFilesStillMeanOil(testCase)
            N = exampleNet();
            phases = displacementPhases(N);
            testCase.verifyEqual(phases.displacingName,'Нефть');
            testCase.verifyEqual(networkOilSaturation(N),7/12,'AbsTol',1e-14);
        end
        function physicalOilVolume(testCase,phaseCase)
            N = exampleNet(); N.displacingPhase = phaseCase.code;
            [fraction,oil,total] = networkOilSaturation(N);
            testCase.verifyEqual(fraction,phaseCase.oilFraction,'AbsTol',1e-14);
            testCase.verifyEqual(oil/total,phaseCase.oilFraction,'AbsTol',1e-14);
            testCase.verifyEqual(total,6*pi*1e-8*N.L,'AbsTol',1e-20);
        end
        function graphicsUsePhysicalLiquids(testCase,phaseCase)
            N = exampleNet(); N.displacingPhase = phaseCase.code;
            fig = figure('Visible','off');
            testCase.addTeardown(@() close(fig));
            snapshot = struct('step',1,'elapsedTime',.2);
            frame = drawSaturationPressureFrame(fig,N,snapshot,1,1,[0 1500],true);
            testCase.verifyEqual(sort(frame.water.XData(isfinite(frame.water.XData))), ...
                phaseCase.waterX,'AbsTol',1e-14);
            testCase.verifyEqual(sort(frame.oil.XData(isfinite(frame.oil.XData))), ...
                phaseCase.oilX,'AbsTol',1e-14);
            testCase.verifyEqual(frame.water.Color,[.25 .75 1],'AbsTol',1e-14);
            testCase.verifyEqual(frame.oil.Color,[0 0 0],'AbsTol',1e-14);
            testCase.verifySubstring(frame.heading.String{2}, ...
                sprintf('%.2f',100*phaseCase.oilFraction));
            ax = ancestor(frame.water,'axes');
            testCase.verifyEqual(ax.Legend.String{1},phaseCase.name);
            % Reusing a GIF frame must retain the same physical segments.
            updated = drawSaturationPressureFrame(fig,N,snapshot,1,1,[0 1500],true,frame);
            testCase.verifyEqual(updated.water.XData,frame.water.XData);
        end
        function interactivePlotUsesSelectedPhase(testCase,phaseCase)
            N = exampleNet(); N.displacingPhase = phaseCase.code;
            fig = figure('Visible','off'); ax = axes(fig);
            testCase.addTeardown(@() close(fig));
            drawNetwork(N,false,ax);
            testCase.verifyEqual(segmentColor(ax,[0 1]),phaseCase.state0Color,'AbsTol',1e-14);
            testCase.verifyEqual(ax.Legend.String{1},phaseCase.name);
            testCase.verifySubstring(ax.Title.String,phaseCase.name);
        end
        function reportNamesMatchViscosityRoles(testCase,phaseCase)
            N = exampleNet(); N.displacingPhase = phaseCase.code;
            presentation = simulationReportPresentation(N,struct());
            testCase.verifySubstring(strjoin(presentation.modelLines,newline),phaseCase.name);
            testCase.verifyEqual(presentation.phases.displacingName,phaseCase.name);
        end
        function waterInjectionRequiresOilOutlet(testCase)
            N = exampleNet(); N.displacingPhase = 'water';
            N.H.State = [2 1 0]; N.H.Sat = [1 .25 0];
            N.H.Dir = [0 1 0]; N.H.Move = [0 1 0];
            allowed = calcCanMove(N);
            N.H.State(3) = 2; N.H.Sat(3) = 1;
            blocked = calcCanMove(N);
            testCase.verifyEqual(allowed.H.Move(2),1);
            testCase.verifyEqual(blocked.H.Move(2),2);
        end
        function plateauKeepsSameWettingLiquidAfterSwap(testCase)
            oil = exampleNet();
            water = oil; water.displacingPhase = 'water';
            water.mu1 = oil.mu2; water.mu2 = oil.mu1; water.theta = pi-oil.theta;
            oilFlow = capillaryEquation(oil,5,0,pi*1e-8,.25,1,0,1);
            waterFlow = capillaryEquation(water,5,0,pi*1e-8,.25,1,0,1);
            testCase.verifyLessThan(waterFlow,0);
            testCase.verifyEqual(waterFlow,oilFlow,'AbsTol',1e-25);
        end
        function waterSnapshotsExportGifAndPdf(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            N = exampleNet(); N.displacingPhase = 'water';
            N.mu1 = 4.3e-3; N.mu2 = 1e-3; N.theta = 3*pi/4; N.dt = .1;
            N.H.Q = zeros(size(N.H.A)); N.V.Q = zeros(size(N.V.A));
            N.H.Regime = zeros(size(N.H.A)); N.V.Regime = zeros(size(N.V.A));
            parameters = N;
            result = struct('directory',fixture.Folder,'steps',0,'totalTime',0, ...
                'totalComputeTime',.01,'startedAt','2026-11-03 12:00:00', ...
                'status','Тест вытеснения нефти водой.','pdf','');
            saveSimulationStep(N,result,0,.01);
            N.H.Sat(2) = .75;
            result.steps = 1; result.totalTime = .1;
            saveSimulationStep(N,result,.1,.01);
            save(fullfile(fixture.Folder,'parameters.mat'),'parameters');
            save(fullfile(fixture.Folder,'summary.mat'),'parameters','result');
            gif = writeSaturationPressureGif(fixture.Folder,[],.1,true);
            [pdf,report] = writeSimulationReport(fixture.Folder,1,gif);
            metadata = load(fullfile(fixture.Folder,'summary.mat'),'parameters');
            testCase.verifyTrue(isfile(pdf));
            testCase.verifyEqual(numel(imfinfo(gif)),2);
            testCase.verifyEqual(report.reportSteps,[0 1]);
            testCase.verifyEqual(metadata.parameters.displacingPhase,'water');
        end
        function windowSavesAndRunsSelectedPhase(testCase,phaseCase,modelChoice)
            root = fileparts(fileparts(mfilename('fullpath')));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            settings = fullfile(root,'results','last_settings','run-settings.mat');
            restore = backupSettings(settings,fixture.Folder);
            testCase.addTeardown(restore);
            testCase.addTeardown(@() closeRunWindow());
            run;
            fig = findall(groot,'Type','figure','Name','Параметры расчёта');
            phase = findobj(fig,'Tag','DisplacingPhase');
            testCase.verifyEqual(phase.Items,{'Нефть','Вода'});
            testCase.verifyEqual(phase.Layout.Row,1);
            testCase.verifyEqual(findobj(fig,'Tag','mu1').Layout.Row,2);
            phase.Value = phaseCase.code;
            setInput(fig,'mu1',1e-3); setInput(fig,'muRatio',4.3);
            setInput(fig,'theta',phaseCase.theta);
            setInput(fig,'MeniscusModel',modelChoice);
            setInput(fig,'IncludeAadd',true);
            setInput(fig,'GeometryMode','Создать новую');
            control = findobj(fig,'Tag','GeometryMode');
            feval(control.ValueChangedFcn,control,[]);
            setInput(fig,'AreaType','Матрица площадей');
            setInput(fig,'H_A',{'[1 1]*pi*1e-8'});
            setInput(fig,'V_A',{'[1;1]*pi*1e-8'});
            setInput(fig,'H_P0',1500);
            setInput(fig,'SaveStepsMode','Все');
            setInput(fig,'VisualizeSatPressure',false);
            start = findobj(fig,'Text','Сохранить и запустить');
            feval(start.ButtonPushedFcn,start,[]);
            N = evalin('base','Net');
            result = evalin('base','simulationResult');
            testCase.addTeardown(@() relocateTestRun(result.directory,root,fixture.Folder));
            saved = load(settings,'inputs');
            parameters = load(fullfile(result.directory,'parameters.mat'),'parameters');
            first = loadSimulationStep(fullfile(result.directory,'step_000000.mat'));
            last = loadSimulationStep(fullfile(result.directory,sprintf('step_%06d.mat',result.steps)));
            resume = prepareSimulationResume(result.directory);
            testCase.verifyEqual(saved.inputs.DisplacingPhase,phaseCase.code);
            testCase.verifyEqual(N.displacingPhase,phaseCase.code);
            testCase.verifyEqual([N.mu1 N.mu2],[phaseCase.mu1 phaseCase.mu2],'AbsTol',1e-15);
            testCase.verifyEqual(N.theta,phaseCase.theta,'AbsTol',1e-15);
            testCase.verifyGreaterThan(N.xi,0); % A_add действительно включён.
            testCase.verifyEqual(N.coef==0,modelChoice==1);
            testCase.verifyEqual(N.P_crit_width==0,modelChoice==1);
            testCase.verifyEqual(parameters.parameters.displacingPhase,phaseCase.code);
            testCase.verifyEqual(networkOilSaturation(first.solvedNet),phaseCase.initialOil,'AbsTol',1e-14);
            testCase.verifyEqual(networkOilSaturation(last.solvedNet),phaseCase.finalOil,'AbsTol',1e-14);
            testCase.verifyEqual(resume.snapshot.solvedNet.displacingPhase,phaseCase.code);
            testCase.verifyEqual(result.status,'Установилось стационарное течение.');
            % Reopening reads the phase from the saved window settings.
            run;
            reopened = findall(groot,'Type','figure','Name','Параметры расчёта');
            testCase.verifyEqual(findobj(reopened,'Tag','DisplacingPhase').Value,phaseCase.code);
        end
    end
end

function N = exampleNet()
N = struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2,'theta',pi/4, ...
    'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
    'coef',6.644123616564944e-4,'P_crit_width',4,'P',[1000 500]);
N.H = struct('Nx',3,'Ny',1,'P0',1500,'A',pi*1e-8*[1 2 3], ...
    'Sat',[.8 .25 .1],'State',[0 1 2],'Dir',[0 1 0],'Move',[0 1 0]);
N.V = struct('Nx',2,'Ny',2,'P0',200,'A',pi*1e-8*ones(2,2), ...
    'Sat',zeros(2),'State',zeros(2),'Dir',zeros(2),'Move',zeros(2));
end

function color = segmentColor(ax,ends)
lines = findall(ax,'Type','line'); color = [];
for index = 1:numel(lines)
    if isequal(lines(index).XData,ends) && isequal(lines(index).YData,[0 0])
        color = lines(index).Color;
        return
    end
end
end

function setInput(fig,tag,value)
control = findobj(fig,'Tag',tag);
control.Value = value;
end

function restore = backupSettings(settings,folder)
existed = isfile(settings);
backup = fullfile(folder,'original-settings.mat');
if existed, copyfile(settings,backup); end
hadCache = isappdata(groot,'capillaryGridRunInputs'); cache = [];
if hadCache, cache = getappdata(groot,'capillaryGridRunInputs'); end
restore = @() restoreSettings(settings,backup,existed,hadCache,cache);
end

function restoreSettings(settings,backup,existed,hadCache,cache)
if existed
    copyfile(backup,settings,'f');
elseif isfile(settings)
    delete(settings);
end
if hadCache
    setappdata(groot,'capillaryGridRunInputs',cache);
elseif isappdata(groot,'capillaryGridRunInputs')
    rmappdata(groot,'capillaryGridRunInputs');
end
end

function closeRunWindow()
delete(findall(groot,'Type','figure','Name','Параметры расчёта'));
end

function relocateTestRun(directory,root,folder)
% Move only this method's freshly created result, inside the known results root.
expected = fullfile(root,'results');
if strcmp(fileparts(directory),expected) && isfolder(directory)
    movefile(directory,fullfile(folder,'test-run'));
end
end
