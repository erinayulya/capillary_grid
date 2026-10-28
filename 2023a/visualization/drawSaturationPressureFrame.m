function frame = drawSaturationPressureFrame(parent,Net,snapshot,frameIndex,frameCount,pressureRange,showMeniscus,frame,region,pageSizePoints)
%DRAWSATURATIONPRESSUREFRAME Shared vector artwork for GIF and PDF.
% parent is a figure/panel. An optional frame reuses existing graphics handles.
% Reads solved Net only. Coordinates and phase lengths match drawNetwork.
if nargin < 8, frame = []; end
if nargin < 9, region = []; end
networkSize = [Net.H.Ny Net.H.Nx];
stacked = size(region,1) == 2;
if stacked
    fitted = reportNetworkLayout(Net.H.Nx,Net.H.Ny,region,pageSizePoints);
end
if isempty(frame)
if isempty(region)
    tiles = tiledlayout(parent,1,2,'Padding','loose','TileSpacing','loose');
    satAxes = nexttile(tiles,1);
    pressureAxes = nexttile(tiles,2);
    heading = title(tiles,'','Interpreter','none','FontSize',14);
else
    % All PDF axes share one parent. Adjacent nested containers cannot be
    % exported with exportgraphics in desktop MATLAB R2025a and later.
    if stacked
        satAxes = axes(parent,'Units','normalized','Position',fitted.axesPositions(1,:));
        pressureAxes = axes(parent,'Units','normalized','Position',fitted.axesPositions(2,:));
    else
    satAxes = axes(parent,'Units','normalized','Position', ...
        regionPosition(region,[.05 .16 .37 .76]));
    pressureAxes = axes(parent,'Units','normalized','Position', ...
        regionPosition(region,[.50 .16 .37 .76]));
    end
    heading = text(satAxes,0,0,'','Visible','off');
end
hold(satAxes,'on');
capillaryWidth = 3; % points; shared by capillaries and current meniscus diameter
water = plot(satAxes,NaN,NaN,'Color',[0.25 0.75 1],'LineWidth',capillaryWidth);
oil = plot(satAxes,NaN,NaN,'Color',[0 0 0],'LineWidth',capillaryWidth);
closed = plot(satAxes,NaN,NaN,'Color',[0.65 0.65 0.65],'LineWidth',capillaryWidth);
menisci = plot(satAxes,NaN,NaN,'ro','LineStyle','none', ...
    'MarkerSize',capillaryWidth,'MarkerFaceColor','r','MarkerEdgeColor','none');
if showMeniscus
    saturationLegend = legend(satAxes,[oil water menisci],{'Нефть','Вода','Мениск'}, ...
        'Location','southoutside','Orientation','horizontal','AutoUpdate','off');
else
    menisci.Visible = 'off';
    saturationLegend = legend(satAxes,[oil water],{'Нефть','Вода'}, ...
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
if ~isempty(region)
    % Reserve a separate strip for the colorbar so it cannot shrink pressure.
    saturationLegend.FontSize = 11;
    if stacked
        barPosition = fitted.colorbarPosition;
        satPosition = fitted.axesPositions(1,:);
        pressurePosition = fitted.axesPositions(2,:);
    else
        barPosition = regionPosition(region,[.89 .16 .016 .76]);
        satPosition = regionPosition(region,[.05 .16 .37 .76]);
        pressurePosition = regionPosition(region,[.50 .16 .37 .76]);
    end
    set(bar,'Units','normalized','FontSize',11, ...
        'Position',barPosition);
    bar.AxisLocation = 'out';
    bar.Label.FontSize = 11;
    set(bar.Label,'Units','normalized','Position',[5.2 .5 0], ...
        'Rotation',90,'HorizontalAlignment','center','VerticalAlignment','middle');
    set(satAxes,'PositionConstraint','innerposition', ...
        'Position',satPosition);
    set(pressureAxes,'PositionConstraint','innerposition', ...
        'Position',pressurePosition);
    if stacked
        set(bar,'Position',fitted.colorbarPosition);
        satAxes.Title.FontSize = 12;
        pressureAxes.Title.FontSize = 12;
        set(satAxes,'Position',fitted.axesPositions(1,:),'Clipping','on');
        set(pressureAxes,'Position',fitted.axesPositions(2,:),'Clipping','on');
        pressure.SizeData = fitted.nodeDiameterPoints^2;
        set([water oil closed],'LineWidth',fitted.lineWidthPoints);
        menisci.MarkerSize = fitted.meniscusDiameterPoints;
    end
end
frame = struct('water',water,'oil',oil,'closed',closed,'menisci',menisci, ...
    'pressure',pressure,'heading',heading);
end
water = frame.water; oil = frame.oil; closed = frame.closed;
menisci = frame.menisci; pressure = frame.pressure; heading = frame.heading;
    [waterXY,oilXY,meniscusXY,closedXY] = phaseSegments(Net);
    set(water,'XData',waterXY(1,:),'YData',waterXY(2,:));
    set(oil,'XData',oilXY(1,:),'YData',oilXY(2,:));
    set(menisci,'XData',meniscusXY(1,:),'YData',meniscusXY(2,:));
    set(closed,'XData',closedXY(1,:),'YData',closedXY(2,:));
    pressure.CData = Net.P(:);
    oilFraction = networkOilSaturation(Net);
    heading.String = {sprintf('Шаг %d   |   t = %.6g с   |   Кадр %d / %d', ...
        snapshot.step,snapshot.elapsedTime,frameIndex,frameCount), ...
        sprintf('Нефтенасыщенность %.2f %%',100*oilFraction)};
end

function position = regionPosition(region,part)
position = [region(1:2)+part(1:2).*region(3:4),part(3:4).*region(3:4)];
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

