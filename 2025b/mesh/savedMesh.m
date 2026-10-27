function result = savedMesh(action, folder, varargin)
%SAVEDMESH List, load or save named network geometry, separately from Net.
% names = savedMesh('list',folder)
% mesh = savedMesh('load',folder,name)
% file = savedMesh('save',folder,name,Ah,Av[,overwrite])
% MAT contains mesh: formatVersion=1, name, Ah, Av, areaUnit='m^2'.
switch action
    case 'list'
        files = dir(fullfile(folder,'*.mat'));
        files = files(~[files.isdir]);
        result = cell(1,numel(files));
        for fileIndex = 1:numel(files)
            [~,result{fileIndex}] = fileparts(files(fileIndex).name);
        end
        result = sort(result);
    case {'load','save'}
        name = strtrim(char(varargin{1}));
        validateName(name);
        filePath = fullfile(folder,[name '.mat']);
        if strcmp(action,'load')
            data = load(filePath,'mesh');
            if ~isfield(data,'mesh') || ~isstruct(data.mesh) || ~isscalar(data.mesh) || ...
                    ~all(isfield(data.mesh,{'formatVersion','name','Ah','Av','areaUnit'})) || ...
                    ~isequal(data.mesh.formatVersion,1) || ~strcmp(data.mesh.areaUnit,'m^2')
                error('savedMesh:Format','Файл не содержит сохранённую сеть поддерживаемого формата: %s',filePath);
            end
            validateMeshGeometry(data.mesh.Ah,data.mesh.Av);
            result = data.mesh;
            return;
        end
        Ah = varargin{2}; Av = varargin{3};
        validateMeshGeometry(Ah,Av);
        overwrite = numel(varargin) >= 4 && varargin{4};
        if isfile(filePath) && ~overwrite
            error('savedMesh:Exists','Сеть «%s» уже существует.',name);
        end
        if ~isfolder(folder)
            [success,message] = mkdir(folder);
            if ~success, error('savedMesh:CreateFolder','%s',message); end
        end
        mesh = struct('formatVersion',1,'name',name,'Ah',Ah,'Av',Av,'areaUnit','m^2');
        temporaryFile = [tempname(folder) '.tmp'];
        cleanup = onCleanup(@() deleteTemporary(temporaryFile));
        save(temporaryFile,'mesh','-mat');
        [success,message] = movefile(temporaryFile,filePath,'f');
        if ~success, error('savedMesh:WriteFailed','%s',message); end
        result = filePath;
    otherwise
        error('savedMesh:Action','Неизвестное действие: %s',action);
end
end

function validateName(name)
if isempty(name) || numel(name) > 120 || ...
        ~isempty(regexp(name,'[<>:"/\\|?*\x00-\x1F]','once')) || ...
        name(end) == '.' || ...
        ~isempty(regexpi(name,'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)','once'))
    error('savedMesh:Name','%s', ...
        'Введите название до 120 символов без <>:"/\|?* и точки в конце. Служебные имена Windows недопустимы.');
end
end

function deleteTemporary(filePath)
if isfile(filePath), delete(filePath); end
end
