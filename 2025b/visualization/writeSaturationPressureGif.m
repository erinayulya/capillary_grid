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
tiles = tiledlayout(fig,1,2,'Padding','loose','TileSpacing','loose');
satAxes = nexttile(tiles,1);
pressureAxes = nexttile(tiles,2);
heading = title(tiles,'','Interpreter','none','FontSize',14);
hold(satAxes,'on');
capillaryWidth = 3; % points; shared by capillaries and current meniscus diameter
water = plot(satAxes,NaN,NaN,'Color',[0.25 0.75 1],'LineWidth',capillaryWidth);
oil = plot(satAxes,NaN,NaN,'Color',[0 0 0],'LineWidth',capillaryWidth);
closed = plot(satAxes,NaN,NaN,'Color',[0.65 0.65 0.65],'LineWidth',capillaryWidth);
menisci = plot(satAxes,NaN,NaN,'ro','LineStyle','none', ...
    'MarkerSize',capillaryWidth,'MarkerFaceColor','r','MarkerEdgeColor','none');
if showMeniscus
    legend(satAxes,[oil water menisci],{'Нефть','Вода','Мениск'}, ...
        'Location','southoutside','Orientation','horizontal','AutoUpdate','off');
else
    menisci.Visible = 'off';
    legend(satAxes,[oil water],{'Нефть','Вода'}, ...
        'Location','southoutside','Orientation','horizontal','AutoUpdate','off');
end
title(satAxes,'Сатурация');

[nodeX,nodeY] = meshgrid(1:networkSize(2)-1,networkSize(1)-1:-1:0);
markerSize = 4*max(8,min(150,2200/prod(networkSize))); % scatter area: double diameter
pressure = scatter(pressureAxes,nodeX(:),nodeY(:),markerSize, ...
    zeros(numel(nodeX),1),'filled');
colormap(pressureAxes,parula(256));
set(pressureAxes,'CLim',pressureRange);
bar = colorbar(pressureAxes);
bar.Label.String = 'Давление, Па';
title(pressureAxes,'Давление в узлах');
for ax = [satAxes pressureAxes]
    axis(ax,'equal');
    set(ax,'XLim',[-0.3 networkSize(2)+0.3], ...
        'YLim',[-1.3 networkSize(1)+0.3], ...
        'FontName','Arial','FontSize',11,'Box','on','Color','w');
    ax.Toolbar.Visible = 'off';
end

% Commit only a complete animation; an existing GIF survives any failure.
temporaryGif = [tempname(outputFolder) '.gif'];
fileCleanup = onCleanup(@() deleteTemporary(temporaryGif));
for k = 1:numel(files)
    snapshot = readFrame(fullfile(directory,files(k).name));
    Net = snapshot.solvedNet;
    [waterXY,oilXY,meniscusXY,closedXY] = phaseSegments(Net);
    set(water,'XData',waterXY(1,:),'YData',waterXY(2,:));
    set(oil,'XData',oilXY(1,:),'YData',oilXY(2,:));
    set(menisci,'XData',meniscusXY(1,:),'YData',meniscusXY(2,:));
    set(closed,'XData',closedXY(1,:),'YData',closedXY(2,:));
    pressure.CData = Net.P(:);
    oilFraction = networkOilSaturation(Net);
    heading.String = {sprintf('Шаг %d   |   t = %.6g с   |   Кадр %d / %d', ...
        snapshot.step,snapshot.elapsedTime,k,numel(files)), ...
        sprintf('Нефтенасыщенность %.2f %%',100*oilFraction)};
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

function [waterXY,oilXY,meniscusXY,closedXY] = phaseSegments(Net)
% Coordinates and phase lengths follow drawNetwork; no Net fields are changed.
[rowH,colH] = ndgrid(1:Net.H.Ny,1:Net.H.Nx);
[rowV,colV] = ndgrid(1:Net.H.Ny+1,1:Net.H.Nx-1);
startXY = [colH(:)'-1 colV(:)'; ...
    Net.H.Ny-rowH(:)' Net.H.Ny-rowV(:)'+1];
endXY = [colH(:)' colV(:)'; ...
    Net.H.Ny-rowH(:)' Net.H.Ny-rowV(:)'];
state = [Net.H.State(:); Net.V.State(:)]';
sat = [Net.H.Sat(:); Net.V.Sat(:)]';
direction = [Net.H.Dir(:); Net.V.Dir(:)]';
isClosed = [false(1,numel(rowH)), ...
    (~Net.VerticalBC & (rowV(:)' == 1 | rowV(:)' == Net.H.Ny+1))];
closedXY = segments(startXY(:,isClosed),endXY(:,isClosed));
reverse = direction <= 0;
savedStart = startXY(:,reverse);
startXY(:,reverse) = endXY(:,reverse);
endXY(:,reverse) = savedStart;
% Only partial capillaries use Sat. State 0/2 represents a full phase.
sat = max(0,min(1,sat));
meniscus = startXY + (endXY-startXY).*sat;
partial = state == 1 & ~isClosed;
meniscusXY = meniscus(:,partial);
waterXY = [segments(startXY(:,state == 0 & ~isClosed), ...
    endXY(:,state == 0 & ~isClosed)), ...
    segments(meniscus(:,partial),endXY(:,partial))];
oilXY = [segments(startXY(:,state == 2 & ~isClosed), ...
    endXY(:,state == 2 & ~isClosed)), ...
    segments(startXY(:,partial),meniscus(:,partial))];
end

function xy = segments(first,last)
% NaN separators batch all capillaries into one graphics object per phase.
xy = NaN(2,3*size(first,2));
xy(:,1:3:end) = first;
xy(:,2:3:end) = last;
end

function deleteTemporary(filename)
if isfile(filename), delete(filename); end
end
