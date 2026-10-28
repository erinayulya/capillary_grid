function gifPath = writeSaturationPressureGif(directory,gifPath,frameDelay,showMeniscus)
%WRITESATURATIONPRESSUREGIF Animate saved saturation and nodal pressure.
% gifPath = writeSaturationPressureGif(directory) reads all step_*.mat files
% in numerical step order and writes saturation_pressure.gif in that folder.
% No summary.mat, simulation workspace or model calls are required.
% With no directory, opens a folder picker. Cancel returns ''.
% Optional gifPath selects the output; frameDelay is seconds/frame (0.1).
% showMeniscus (true) controls the red markers and their legend entry.
% Every saved step gets one frame, including step 0 and the final saved step.
% Playback delay is constant; the title gives the actual model time in s.
% Left: oil black, water light blue, current menisci red; no Move/history.
% Right: Net.P at internal nodes only, Pa, with a fixed scale for all frames.
% The canvas is A4 landscape, 29.7 x 21 cm, rasterized at 120 dpi.
% Uses base MATLAB, including graphics/print and rgb2ind/imwrite (R2023a+).

if nargin < 1 || isempty(directory)
    directory = uigetdir(fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'results'),'Выберите папку с MAT-файлами расчёта');
    if isequal(directory,0), gifPath = ''; return; end
end
directory = char(directory);
if ~isfolder(directory)
    error('writeSaturationPressureGif:DirectoryNotFound', ...
        'Папка результатов не найдена: %s',directory);
end
if nargin < 2 || isempty(gifPath)
    gifPath = fullfile(directory,'saturation_pressure.gif');
end
gifPath = char(gifPath);
if nargin < 3, frameDelay = 0.1; end
if nargin < 4, showMeniscus = true; end
validateattributes(showMeniscus,{'logical','numeric'}, ...
    {'scalar','real','finite','binary'},mfilename,'showMeniscus');
validateattributes(frameDelay,{'numeric'}, ...
    {'scalar','real','finite','>=',0.01,'<=',655},mfilename,'frameDelay');
[outputFolder,~,extension] = fileparts(gifPath);
if ~strcmpi(extension,'.gif')
    error('writeSaturationPressureGif:InvalidOutput','Нужно расширение .gif.');
end
if isempty(outputFolder), outputFolder = pwd; end
if ~isfolder(outputFolder)
    error('writeSaturationPressureGif:DirectoryNotFound', ...
        'Папка для GIF не найдена: %s',outputFolder);
end

files = dir(fullfile(directory,'step_*.mat'));
tokens = regexp({files.name},'^step_(\d+)\.mat$','tokens','once');
valid = ~cellfun('isempty',tokens);
files = files(valid); tokens = tokens(valid);
numbers = cellfun(@(value) str2double(value{1}),tokens);
[~,order] = sort(numbers);
files = files(order);
if isempty(files)
    error('writeSaturationPressureGif:NoSteps', ...
        'В папке нет снимков step_*.mat: %s',directory);
end

% First pass fixes the pressure scale without keeping the history in memory.
pressureRange = [Inf -Inf];
for k = 1:numel(files)
    snapshot = readFrame(fullfile(directory,files(k).name));
    Net = snapshot.solvedNet;
    validateFrame(Net);
    currentSize = [Net.H.Ny Net.H.Nx];
    if k == 1
        networkSize = currentSize;
    elseif ~isequal(currentSize,networkSize)
        error('writeSaturationPressureGif:GeometryChanged', ...
            'Размер сети изменяется между сохранёнными шагами.');
    end
    pressureRange = [min(pressureRange(1),min(Net.P(:))), ...
        max(pressureRange(2),max(Net.P(:)))];
end
if pressureRange(1) == pressureRange(2)
    pad = max(1,abs(pressureRange(1))*0.01);
    pressureRange = pressureRange + [-pad pad];
end

% Explicit paper size makes export independent of monitor and window size.
fig = figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','centimeters', ...
    'Position',[1 1 29.7 21],'PaperUnits','centimeters', ...
    'PaperSize',[29.7 21],'PaperPosition',[0 0 29.7 21], ...
    'PaperPositionMode','manual','InvertHardcopy','off');
figureCleanup = onCleanup(@() close(fig));
frame = [];

% Commit only a complete animation; an existing GIF survives any failure.
temporaryGif = [tempname(outputFolder) '.gif'];
fileCleanup = onCleanup(@() deleteTemporary(temporaryGif));
for k = 1:numel(files)
    snapshot = readFrame(fullfile(directory,files(k).name));
    Net = snapshot.solvedNet;
    frame = drawSaturationPressureFrame(fig,Net,snapshot,k,numel(files), ...
        pressureRange,showMeniscus,frame);
    drawnow limitrate;
    rgb = print(fig,'-RGBImage','-r120');
    [indexed,palette] = rgb2ind(rgb,256,'nodither');
    if k == 1
        imwrite(indexed,palette,temporaryGif,'gif', ...
            'LoopCount',Inf,'DelayTime',frameDelay);
    else
        imwrite(indexed,palette,temporaryGif,'gif', ...
            'WriteMode','append','DelayTime',frameDelay);
    end
    if k == 1 || k == numel(files) || mod(k,50) == 0
        fprintf('GIF: %d / %d кадров\n',k,numel(files));
    end
end
[ok,message] = movefile(temporaryGif,gifPath,'f');
if ~ok, error('writeSaturationPressureGif:WriteFailed','%s',message); end
% Optional report metadata: old runs without summary remain valid GIF inputs.
summaryFile = fullfile(directory,'summary.mat');
if isfile(summaryFile)
    try
        metadata = load(summaryFile,'result');
        result = metadata.result;
        result.gifShowMeniscus = logical(showMeniscus);
        result.gifPressureRange = pressureRange;
        save(summaryFile,'result','-append');
    catch exception
        warning('writeSaturationPressureGif:MetadataFailed', ...
            'GIF создан, но его настройки не записаны в summary: %s',exception.message);
    end
end
end

function snapshot = readFrame(filename)
snapshot = loadSimulationStep(filename);
% solvedNet keeps pressure and saturation from the same accepted state,
% including legacy files whose Net/reportNet was prepared for the old PDF.
if ~isfield(snapshot,'step') || ~isfield(snapshot,'elapsedTime')
    error('writeSaturationPressureGif:InvalidSnapshot', ...
        'В снимке отсутствуют step/elapsedTime: %s',filename);
end
end

function validateFrame(Net)
validateattributes(Net.H.Nx,{'numeric'},{'scalar','integer','>=',2});
validateattributes(Net.H.Ny,{'numeric'},{'scalar','integer','positive'});
validateattributes(Net.P,{'numeric'}, ...
    {'real','finite','size',[Net.H.Ny Net.H.Nx-1]});
keys = 'HV';
expected = {[Net.H.Ny Net.H.Nx],[Net.H.Ny+1 Net.H.Nx-1]};
for j = 1:2
    part = Net.(keys(j));
    validateattributes(part.State,{'numeric'}, ...
        {'real','finite','integer','>=',0,'<=',2,'size',expected{j}});
    validateattributes(part.Sat,{'numeric'}, ...
        {'real','finite','size',expected{j}});
    validateattributes(part.Dir,{'numeric'}, ...
        {'real','finite','size',expected{j}});
end
end

function deleteTemporary(filename)
if isfile(filename), delete(filename); end
end
