function mass_tests()
%MASS_TESTS Calculate all generated meshes using the default run inputs.
%   MASS_TESTS reads ../generate_lognorm_mesh/results/N_M/sigma_*_mu_*.
%   Results go to results/mass_tests_03.11.26/N_M/sigma_*_mu_*.
%   Uses the existing main script: viscous model, A_add off, MAT stride N.
%   No GIF/PDF is created. Existing case folders are skipped; case errors
%   are recorded and do not stop the remaining meshes. Call from 2025b.

project = fileparts(mfilename('fullpath'));
oldFolder = pwd;
oldPath = path;
restore = onCleanup(@() restoreSession(oldFolder,oldPath));
cd(project);
setupProject;
source = fullfile(fileparts(project),'generate_lognorm_mesh','results');
resultsRoot = fullfile(project,'results');
batchRoot = fullfile(resultsRoot,'mass_tests_03.11.26');
if ~isfolder(source)
    error('mass_tests:MissingMeshes','Нет папки сеток: %s',source);
end
sizes = dir(source);
sizes = sizes([sizes.isdir] & ...
    ~cellfun('isempty',regexp({sizes.name},'^\d+_\d+$','once')));
if isempty(sizes), error('mass_tests:NoMeshes','В %s нет папок n_m.',source); end
dimensions = sscanf(strjoin({sizes.name},' '),'%d_%d');
[~,order] = sortrows(reshape(dimensions,2,[]).',[1 2]);
sizes = sizes(order);
if ~isfolder(batchRoot), mkdir(batchRoot); end
logFile = fullfile(batchRoot,'batch_log.txt');
fprintf('Пакетный расчёт: %s\n',batchRoot);
for sizeIndex = 1:numel(sizes)
    sizeName = sizes(sizeIndex).name;
    dimensions = sscanf(sizeName,'%d_%d');
    nRows = dimensions(1); nCols = dimensions(2);
    meshes = dir(fullfile(source,sizeName,'sigma_*_mu_*'));
    meshes = meshes([meshes.isdir]);
    for meshIndex = 1:numel(meshes)
        meshName = meshes(meshIndex).name;
        inputFolder = fullfile(source,sizeName,meshName);
        destination = fullfile(batchRoot,sizeName,meshName);
        if isfolder(destination) || isfile(destination)
            fprintf('Пропуск существующего результата: %s/%s\n',sizeName,meshName);
            continue;
        end
        fprintf('\nСеть %s/%s, сохранять каждый %d-й шаг.\n',sizeName,meshName,nRows);
        try
            Ah = readAreaMatrix(fullfile(inputFolder,'horizontal_areas.xlsx'));
            Av = readAreaMatrix(fullfile(inputFolder,'vertical_areas.xlsx'));
            validateMeshGeometry(Ah,Av);
            if ~isequal(size(Ah),[nRows nCols+1]) || ...
                    ~isequal(size(Av),[nRows+1 nCols])
                error('mass_tests:MeshSize','Размеры таблиц не соответствуют папке %s.',sizeName);
            end
            simulationStorageOptions('set',2*nRows);
            storageCleanup = onCleanup(@() simulationStorageOptions('reset'));
            [result,failure] = calculateMesh(Ah,Av);
            clear storageCleanup
            % main writes a normal run_* folder; relocate only this new run.
            [parent,name] = fileparts(result.directory);
            if ~strcmpi(parent,resultsRoot) || ~startsWith(name,'run_')
                error('mass_tests:OutputPath','Неожиданный путь результата: %s',result.directory);
            end
            if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
            if isfolder(destination) || isfile(destination)
                error('mass_tests:OutputExists','Результат уже существует: %s',destination);
            end
            [success,message] = movefile(result.directory,destination);
            if ~success, error('mass_tests:MoveFailed','%s',message); end
            result.directory = destination;
            save(fullfile(destination,'summary.mat'),'result','-append');
            if ~isempty(failure), rethrow(failure); end
            writelines(string(sizeName)+"/"+meshName+": "+result.status, ...
                logFile,'WriteMode','append','Encoding','UTF-8');
            fprintf('Сохранено: %s\n',destination);
        catch exception
            clear storageCleanup
            if ~isfolder(destination), mkdir(destination); end
            details = string(getReport(exception,'extended','hyperlinks','off'));
            writelines(details,fullfile(destination,'batch_error.txt'),'Encoding','UTF-8');
            writelines(string(sizeName)+"/"+meshName+": ERROR: "+exception.message, ...
                logFile,'WriteMode','append','Encoding','UTF-8');
            warning('mass_tests:CaseFailed','%s/%s: %s',sizeName,meshName,exception.message);
        end
    end
end
fprintf('\nПакетный расчёт завершён. Результаты: %s\n',batchRoot);
clear restore
end

function [result,failure] = calculateMesh(Ah,Av)
% Same defaults and one-run handoff as run/startMain; main owns all physics.
runParameters = struct('H',struct('P0',1500,'A',Ah), ...
    'V',struct('A',Av),'VerticalBC',false,'displacingPhase','oil', ...
    'mu1',1e-3,'mu2',4.3*1e-3,'L',9e-3,'sigma',7e-2,'theta',pi/4); %#ok<NASGU>
runModelOptions = struct('includeAadd',false,'meniscusModel',1); %#ok<NASGU>
runRecordResults = true; %#ok<NASGU>
try
    main
    failure = [];
catch failure
    if ~exist('simulationResult','var'), rethrow(failure); end
end
result = simulationResult;
end

function restoreSession(folder,previousPath)
cd(folder);
path(previousPath);
end
