classdef testSavedMesh < matlab.unittest.TestCase
    properties
        Folder
        Root
    end
    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.Root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.Root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'mesh')));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
        end
    end
    methods (Test)
        function roundTripPreservesExactAreas(testCase)
            Ah = [1 2 3;4 5 6]*1e-8; Av = [7 8;9 10;11 12]*1e-8;
            folder = fullfile(testCase.Folder,'saved_mesh');
            savedMesh('save',folder,'Сеть 1',Ah,Av);
            mesh = savedMesh('load',folder,'Сеть 1');
            testCase.verifyEqual(mesh.Ah,Ah);
            testCase.verifyEqual(mesh.Av,Av);
            testCase.verifyEqual(mesh.areaUnit,'m^2');
            testCase.verifyEqual(savedMesh('list',folder),{'Сеть 1'});
        end
        function missingLibraryIsEmpty(testCase)
            testCase.verifyEmpty(savedMesh('list',fullfile(testCase.Folder,'missing')));
        end
        function duplicateDoesNotReplaceData(testCase)
            savedMesh('save',testCase.Folder,'sample',[1 2],[3;4]);
            testCase.verifyError(@() savedMesh('save',testCase.Folder,'sample', ...
                [5 6],[7;8]),'savedMesh:Exists');
            mesh = savedMesh('load',testCase.Folder,'sample');
            testCase.verifyEqual(mesh.Ah,[1 2]);
        end
        function explicitOverwriteReplacesData(testCase)
            savedMesh('save',testCase.Folder,'sample',[1 2],[3;4]);
            savedMesh('save',testCase.Folder,'sample',[5 6],[7;8],true);
            mesh = savedMesh('load',testCase.Folder,'sample');
            testCase.verifyEqual(mesh.Ah,[5 6]);
            testCase.verifyEqual(mesh.Av,[7;8]);
        end
        function rejectsPathInName(testCase)
            testCase.verifyError(@() savedMesh('save',testCase.Folder,'../other', ...
                [1 2],[3;4]),'savedMesh:Name');
        end
        function rejectsReservedName(testCase)
            testCase.verifyError(@() savedMesh('save',testCase.Folder,'CON', ...
                [1 2],[3;4]),'savedMesh:Name');
        end
        function rejectsInconsistentDimensions(testCase)
            testCase.verifyError(@() savedMesh('save',testCase.Folder,'bad', ...
                ones(2,3),ones(2,2)),'validateMeshGeometry:SizeMismatch');
            testCase.verifyEmpty(savedMesh('list',testCase.Folder));
        end
        function rejectsDamagedMeshFile(testCase)
            mesh = struct('Ah',[1 2],'Av',[3;4]);
            save(fullfile(testCase.Folder,'bad.mat'),'mesh');
            testCase.verifyError(@() savedMesh('load',testCase.Folder,'bad'),'savedMesh:Format');
        end
        function importsNumericMWithoutExecution(testCase)
            file = fullfile(testCase.Folder,'areas.m');
            testCase.writeText(file,sprintf('%% areas in m^2\nA = [1e-8, 2D-8; ...\n 3e-8 4e-8];\n'));
            testCase.verifyEqual(readAreaMatrix(file),[1e-8 2e-8;3e-8 4e-8]);
        end
        function rejectsExecutableM(testCase)
            file = fullfile(testCase.Folder,'areas.m');
            testCase.writeText(file,'A = [1 2]; error(''must not execute'');');
            testCase.verifyError(@() readAreaMatrix(file),'readAreaMatrix:MFormat');
        end
        function rejectsRaggedM(testCase)
            file = fullfile(testCase.Folder,'areas.m');
            testCase.writeText(file,'[1 2;3]');
            testCase.verifyError(@() readAreaMatrix(file),'readAreaMatrix:MFormat');
        end
        function importsExcelFirstSheet(testCase)
            file = fullfile(testCase.Folder,'areas.xlsx');
            writematrix([1 2;3 4]*1e-8,file,'Sheet',1);
            testCase.verifyEqual(readAreaMatrix(file),[1 2;3 4]*1e-8);
        end
        function rejectsExcelHeadings(testCase)
            file = fullfile(testCase.Folder,'areas.xlsx');
            writecell({'A','B';1 2},file);
            testCase.verifyError(@() readAreaMatrix(file),'readAreaMatrix:ExcelFormat');
        end
        function missingImportHasClearError(testCase)
            testCase.verifyError(@() readAreaMatrix(fullfile(testCase.Folder,'missing.xlsx')), ...
                'readAreaMatrix:MissingFile');
        end
        function uiLoadsAndSavesExactGeometry(testCase)
            % Run an isolated copy of the real UI, with dialogs and main replaced.
            % User settings, open figures and the physical solver are not touched.
            app = fullfile(testCase.Folder,'app');
            hadInputs = isappdata(groot,'capillaryGridRunInputs');
            oldInputs = getappdata(groot,'capillaryGridRunInputs');
            testCase.addTeardown(@() testCase.restoreInputs(hadInputs,oldInputs));
            originalRng = rng;
            testCase.addTeardown(@() rng(originalRng));
            previousResult = captureBaseResult();
            testCase.addTeardown(@() restoreBaseResult(previousResult));
            mkdir(app);
            cellfun(@(name) copyfile(fullfile(testCase.Root,name),fullfile(app,name)), ...
                {'run.m','setupProject.m'});
            mkdir(fullfile(app,'mesh'));
            cellfun(@(name) copyfile(fullfile(testCase.Root,'mesh',name),fullfile(app,'mesh',name)), ...
                {'readAreaMatrix.m','validateMeshGeometry.m','savedMesh.m'});
            cellfun(@(name) mkdir(fullfile(app,name)),{'model','solver','visualization','reporting'});
            copyfile(fullfile(testCase.Root,'reporting','simulationStorageOptions.m'), ...
                fullfile(app,'reporting','simulationStorageOptions.m'));
            cellfun(@(name) copyfile(fullfile(testCase.Root,'reporting',name),fullfile(app,'reporting',name)), ...
                {'inspectLastSimulation.m','prepareSimulationResume.m','loadSimulationStep.m'});
            testCase.writeText(fullfile(app,'resetSimulationWorkspace.m'), ...
                sprintf('function resetSimulationWorkspace(varargin)\nend\n'));
            testCase.writeText(fullfile(app,'inputdlg.m'), ...
                sprintf('function a = inputdlg(varargin)\na = {getappdata(groot,''savedMeshTestName'')};\nend\n'));
            testCase.writeText(fullfile(app,'uigetfile.m'),sprintf([ ...
                'function [name,folder] = uigetfile(varargin)\n' ...
                '[folder,name,ext] = fileparts(getappdata(groot,''savedMeshTestFile''));\n' ...
                'name = [name ext];\nend\n']));
            testCase.writeText(fullfile(app,'main.m'), ...
                ['setappdata(groot,''savedMeshTestNet'',runParameters); ' ...
                 'simulationResult=struct(''directory'',pwd,''pdf'',''''); clear runParameters;']);
            testCase.writeText(fullfile(app,'visualization','writeSaturationPressureGif.m'),sprintf([ ...
                'function file = writeSaturationPressureGif(folder,unused,delay,show)\n' ...
                'setappdata(groot,''savedMeshTestGif'',struct(''delay'',delay,''show'',show));\n' ...
                'file=fullfile(folder,''saturation_pressure.gif'');\n' ...
                'fid=fopen(file,''w''); fprintf(fid,''test GIF''); fclose(fid);\nend\n']));
            testCase.writeText(fullfile(app,'reporting','writeSimulationReport.m'),sprintf([ ...
                'function [file,result] = writeSimulationReport(folder,stride,gif,options)\n' ...
                'setappdata(groot,''savedMeshTestPdf'',struct(''stride'',stride,''gif'',gif,''options'',options));\n' ...
                'file=fullfile(folder,''report.pdf''); result=struct(''directory'',folder,''pdf'',file);\n' ...
                'fid=fopen(file,''w''); fprintf(fid,''test PDF''); fclose(fid);\nend\n']));
            inputs = struct('GeometryMode','Задать новую');
            settingsFolder = fullfile(app,'results','last_settings');
            mkdir(settingsFolder);
            save(fullfile(settingsFolder,'run-settings.mat'),'inputs');
            oldPath = path;
            testCase.addTeardown(@() path(oldPath));
            oldFolder = pwd;
            testCase.addTeardown(@() cd(oldFolder));
            cd(app);
            setappdata(groot,'savedMeshTestName','Test network');
            testCase.addTeardown(@() rmappdata(groot,'savedMeshTestName'));
            existingFigures = findall(groot,'Type','figure');
            feval('run');
            fig = findall(groot,'Type','figure','Name','Параметры расчёта');
            fig = fig(~ismember(fig,existingFigures));
            testCase.addTeardown(@() delete(fig(isvalid(fig))));
            testCase.assertNumElements(fig,1);
            testCase.addTeardown(@() rmappdata(groot,'savedMeshTestGif'));
            testCase.addTeardown(@() rmappdata(groot,'savedMeshTestPdf'));
            check = findall(fig,'Tag','checkLastSimulation');
            check.ButtonPushedFcn(check,[]);
            continueControl = findall(fig,'Tag','continueLastSimulation');
            testCase.verifyTrue(strcmp(continueControl.Visible,'off'));
            testRun = fullfile(app,'results','run_20261027_120000'); mkdir(testRun);
            result = struct('status','Расчёт не завершён.');
            save(fullfile(testRun,'summary.mat'),'result');
            check.ButtonPushedFcn(check,[]);
            testCase.verifyTrue(strcmp(continueControl.Visible,'on'));
            testCase.verifyTrue(strcmp(continueControl.Enable,'off'));
            testCase.verifyEqual(continueControl.Layout.Column,check.Layout.Column);
            testCase.verifyGreaterThan(continueControl.Layout.Row,check.Layout.Row);
            solvedNet = struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2, ...
                'theta',pi/4,'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
                'coef',6.644123616564944e-4,'P_crit_width',4,'dt',0.2,'P',100);
            solvedNet.H = struct('Nx',2,'Ny',1,'P0',1500,'A',[1 1]*pi*1e-8, ...
                'Sat',[0.1 0],'State',[1 0],'Dir',[1 0],'Move',[1 0], ...
                'Regime',[3 0],'Q',[1 1]*1e-10);
            solvedNet.V = struct('Nx',1,'Ny',2,'P0',200,'A',[1;1]*pi*1e-8, ...
                'Sat',[0;0],'State',[0;0],'Dir',[0;0],'Move',[0;0], ...
                'Regime',[0;0],'Q',[0;0]);
            step = 0; elapsedTime = 0; dtUsed = 0;
            save(fullfile(testRun,'step_000000.mat'),'solvedNet','step','elapsedTime','dtUsed');
            check.ButtonPushedFcn(check,[]);
            testCase.verifyTrue(strcmp(continueControl.Enable,'on'));
            gifControl = findall(fig,'Tag','makeLastGif');
            pdfControl = findall(fig,'Tag','makeLastPdf');
            testCase.verifyTrue(strcmp(gifControl.Visible,'off'));
            testCase.verifyTrue(strcmp(pdfControl.Visible,'off'));
            result.status = 'Установилось стационарное течение.';
            save(fullfile(testRun,'summary.mat'),'result');
            check.ButtonPushedFcn(check,[]);
            testCase.verifyTrue(strcmp(continueControl.Visible,'off'));
            testCase.verifyTrue(strcmp(gifControl.Visible,'on'));
            testCase.verifyTrue(strcmp(pdfControl.Visible,'on'));
            testCase.verifyEqual(gifControl.Layout.Row,2);
            testCase.verifyEqual(pdfControl.Layout.Row,3);
            pdfControl.ButtonPushedFcn(pdfControl,[]);
            testCase.verifyTrue(isfile(fullfile(testRun,'report.pdf')));
            testCase.verifyFalse(isfile(fullfile(testRun,'saturation_pressure.gif')));
            testCase.verifyTrue(strcmp(pdfControl.Visible,'off'));
            testCase.verifyTrue(strcmp(gifControl.Visible,'on'));
            gifControl.ButtonPushedFcn(gifControl,[]);
            testCase.verifyTrue(strcmp(pdfControl.Visible,'off'));
            testCase.verifyTrue(strcmp(gifControl.Visible,'off'));
            delete(fullfile(testRun,'saturation_pressure.gif'));
            check.ButtonPushedFcn(check,[]);
            testCase.verifyTrue(strcmp(gifControl.Visible,'on'));
            testCase.verifyTrue(strcmp(pdfControl.Visible,'off'));
            delete(fullfile(testRun,'report.pdf'));
            fid = fopen(fullfile(testRun,'saturation_pressure.gif'),'w'); fclose(fid);
            check.ButtonPushedFcn(check,[]);
            testCase.verifyTrue(strcmp(gifControl.Visible,'off'));
            testCase.verifyTrue(strcmp(pdfControl.Visible,'on'));
            testCase.verifyEqual(pdfControl.Layout.Row,2);
            delete(fullfile(testRun,'saturation_pressure.gif'));
            result.status = 'Расчёт не завершён.';
            save(fullfile(testRun,'summary.mat'),'result');
            check.ButtonPushedFcn(check,[]);
            geometry = findall(fig,'Tag','GeometryMode');
            testCase.verifyEqual(geometry.Value,'Создать новую');
            areas = findall(fig,'Tag','AreaType');
            areas.Value = 'Загрузить'; areas.ValueChangedFcn(areas,[]);
            testCase.verifyTrue(strcmp(findall(fig,'Tag','importGeometryPanel').Visible,'on'));
            fileH = fullfile(testCase.Folder,'h.xlsx');
            fileV = fullfile(testCase.Folder,'v.m');
            writematrix([1 2 3;4 5 6]*1e-8,fileH);
            testCase.writeText(fileV,'Av = [7e-8 8e-8;9e-8 10e-8;11e-8 12e-8];');
            testCase.addTeardown(@() rmappdata(groot,'savedMeshTestFile'));
            setappdata(groot,'savedMeshTestFile',fileH);
            button = findall(fig,'Tag','loadHorizontalAreas'); button.ButtonPushedFcn(button,[]);
            setappdata(groot,'savedMeshTestFile',fileV);
            button = findall(fig,'Tag','loadVerticalAreas'); button.ButtonPushedFcn(button,[]);
            testCase.verifyEqual(findall(fig,'Tag','ImportedHPath').Value,fileH);
            testCase.verifyEqual(findall(fig,'Tag','ImportedVPath').Value,fileV);
            button = findall(fig,'Tag','saveMeshButton'); button.ButtonPushedFcn(button,[]);
            testCase.verifyEqual(geometry.Value,'Выбрать из сохраненных');
            selected = findall(fig,'Tag','SavedMeshName');
            testCase.verifyEqual(selected.Value,'Test network');
            mesh = savedMesh('load',fullfile(app,'mesh','saved_mesh'),selected.Value);
            testCase.verifyEqual(mesh.Ah,[1 2 3;4 5 6]*1e-8);
            testCase.verifyEqual(mesh.Av,[7e-8 8e-8;9e-8 10e-8;11e-8 12e-8]);
            testCase.addTeardown(@() rmappdata(groot,'savedMeshTestNet'));
            button = findall(fig,'Text','Сохранить и запустить');
            button.ButtonPushedFcn(button,[]);
            net = getappdata(groot,'savedMeshTestNet');
            testCase.verifyEqual(net.H.A,mesh.Ah);
            testCase.verifyEqual(net.V.A,mesh.Av);
            settings = load(fullfile(settingsFolder,'run-settings.mat'));
            testCase.verifyEqual(settings.inputs.ImportedHPath,fileH);
            testCase.verifyEqual(settings.inputs.SavedMeshName,'Test network');
            testCase.verifyEqual(settings.previousGeometry.Ah,mesh.Ah);
            % Reopening restores imported paths and the selected library entry.
            feval('run');
            fig = findall(groot,'Type','figure','Name','Параметры расчёта');
            fig = fig(~ismember(fig,existingFigures));
            testCase.addTeardown(@() delete(fig(isvalid(fig))));
            geometry = findall(fig,'Tag','GeometryMode');
            testCase.verifyEqual(geometry.Value,'Выбрать из сохраненных');
            testCase.verifyEqual(findall(fig,'Tag','SavedMeshName').Value,'Test network');
            testCase.verifyEqual(findall(fig,'Tag','ImportedHPath').Value,fileH);
            geometry.Value = 'Создать новую'; geometry.ValueChangedFcn(geometry,[]);
            visualization = findall(fig,'Tag','VisualizeSatPressure');
            visualization.Value = true; visualization.ValueChangedFcn(visualization,[]);
            pdfToggle = findall(fig,'Tag','GifCreatePdf');
            testCase.verifyTrue(strcmp(pdfToggle.Visible,'on'));
            testCase.verifyFalse(pdfToggle.Value);
            pdfToggle.Value = true;
            areas = findall(fig,'Tag','AreaType');
            areas.Value = 'Случайная'; areas.ValueChangedFcn(areas,[]);
            setappdata(groot,'savedMeshTestName','Random network');
            button = findall(fig,'Tag','saveMeshButton'); button.ButtonPushedFcn(button,[]);
            afterSaveRng = rng;
            randomMesh = savedMesh('load',fullfile(app,'mesh','saved_mesh'),'Random network');
            expectedOptions = struct('includeAadd',findall(fig,'Tag','IncludeAadd').Value, ...
                'meniscusModel',findall(fig,'Tag','MeniscusModel').Value, ...
                'showMeniscus',findall(fig,'Tag','GifShowMeniscus').Value);
            button = findall(fig,'Text','Сохранить и запустить'); button.ButtonPushedFcn(button,[]);
            net = getappdata(groot,'savedMeshTestNet');
            testCase.verifyEqual(net.H.A,randomMesh.Ah);
            testCase.verifyEqual(net.V.A,randomMesh.Av);
            testCase.verifyEqual(rng,afterSaveRng);
            pdfCall = getappdata(groot,'savedMeshTestPdf');
            testCase.verifyEqual(pdfCall.stride,1);
            testCase.verifyEqual(pdfCall.gif,fullfile(app,'saturation_pressure.gif'));
            testCase.verifyEqual(pdfCall.options,expectedOptions);
            settings = load(fullfile(settingsFolder,'run-settings.mat'));
            testCase.verifyTrue(settings.inputs.GifCreatePdf);
            evalin('base','clear runModelOptions runRecordResults');
        end
    end
    methods (Access=private)
        function restoreInputs(~,hadInputs,oldInputs)
            if hadInputs
                setappdata(groot,'capillaryGridRunInputs',oldInputs);
            elseif isappdata(groot,'capillaryGridRunInputs')
                rmappdata(groot,'capillaryGridRunInputs');
            end
        end
        function writeText(~,file,text)
            fid = fopen(file,'w','n','UTF-8');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid,'%s',text);
        end
    end
end

function state = captureBaseResult()
state.exists = evalin('base','exist(''simulationResult'',''var'') ~= 0');
state.value = [];
if state.exists, state.value = evalin('base','simulationResult'); end
end

function restoreBaseResult(state)
if state.exists
    assignin('base','simulationResult',state.value);
else
    evalin('base','clear simulationResult');
end
end
