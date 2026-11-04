function pageNumber = writeResidualClusterPdf(result,pdfPath,pageNumber)
%WRITERESIDUALCLUSTERPDF Append size histogram as closing PDF pages.
% H/V columns are sums of channels in all clusters of the given size.
% Exact per-cluster H/V counts and composition frequencies are saved as CSV.
% All rows are retained; long histograms continue on subsequent closing pages.
if nargin<3, pageNumber=0; end
pageNumber=writeClusterDetails(result,pdfPath,pageNumber);
rowsPerPage=8; % Reserve the lower half for the last saturation frame.
histogram=result.distribution;
pageCount=max(1,ceil(height(histogram)/rowsPerPage));
pageSize=[595.276 841.89]; % A4, points; supported by desktop R2023a.
fig=figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','points','Position',[10 10 pageSize]);
cleanup=onCleanup(@() close(fig));
canvas=uipanel(fig,'Units','points','Position',[0 0 pageSize], ...
    'BorderType','none','BackgroundColor','white');
if isprop(canvas,'AutoResizeChildren'), canvas.AutoResizeChildren='off'; end
ax=axes('Parent',canvas,'Position',[0 0 1 1],'Visible','off', ...
    'XLim',[0 1],'YLim',[0 1]);
hold(ax,'on');
rectangle(ax,'Position',[0 0 1 1],'FaceColor','white','EdgeColor','none');
phaseName='вода';
if strcmp(result.displacedPhase,'oil'), phaseName='нефть'; end
text(ax,.07,.95,'Кластеры с остатками вытесняемой фазы', ...
    'FontName','Arial','FontSize',16,'FontWeight','bold','Interpreter','none');
text(ax,.07,.91,sprintf('Последний снимок: шаг %d; t = %.9g с. Фаза: %s.', ...
    result.step,result.elapsedTime,phaseName),'FontName','Arial','FontSize',10,'Interpreter','none');
text(ax,.07,.865,{sprintf('Кластеров: %d; каналов с остатками: %d.', ...
    height(result.clusters),height(result.channels)), ...
    sprintf('Объём учтённых остатков: %.9g м³; насыщенность: %.6g %%.', ...
    result.displacedVolume,100*result.displacedSaturation), ...
    sprintf('Без связи с выходом: %d кластеров; объём %.9g м³ (%.6g %% сети).', ...
    nnz(~result.clusters.ConnectedToOutlet),result.isolatedVolume,100*result.isolatedSaturation), ...
    sprintf('Исключено по правой границе: %d кластеров, %d каналов.', ...
    result.excludedRightConnectedClusterCount,result.excludedRightConnectedChannelCount)}, ...
    'FontName','Arial','FontSize',10,'Interpreter','none','VerticalAlignment','top');
text(ax,.07,.755,{'Размер - число каналов, содержащих вытесняемую фазу.', ...
    'H / V - сумма горизонтальных / вертикальных каналов в строке.', ...
    'Изол. - число кластеров без пути вытесняемой фазы к выходу.', ...
    'Связанные с правой границей кластеры исключены целиком.'}, ...
    'FontName','Arial','FontSize',9,'Interpreter','none','VerticalAlignment','top');
columns=[.07 .27 .47 .65 .81];
headers={'Каналов','Кластеров','H','V','Изол.'};
for col=1:5
    text(ax,columns(col),.65,headers{col},'FontName','Arial', ...
        'FontSize',10,'FontWeight','bold','Interpreter','none');
end
rowLabels=gobjects(rowsPerPage,5);
for row=1:rowsPerPage
    y=.619-(row-1)*.017;
    for col=1:5
        rowLabels(row,col)=text(ax,columns(col),y,'','FontName','Consolas', ...
            'FontSize',10,'Interpreter','none');
    end
end
emptyLabel=text(ax,.07,.61,'Нет кластеров без связи с правой границей.', ...
    'FontName','Arial','FontSize',11,'Visible','off','Interpreter','none');
text(ax,.07,.10,{'Состав каждого кластера: clusters.csv; частоты сочетаний H/V:', ...
    'cluster_composition.csv. Принадлежность каналов: cluster_channels.csv.', ...
    'Папка: analysis внутри расчёта.'}, ...
    'FontName','Arial','FontSize',9,'Interpreter','none','VerticalAlignment','top');
footer=text(ax,.07,.04,'','FontName','Arial','FontSize',9,'Interpreter','none');
drawClusterSaturation(canvas,result);
for sheet=1:pageCount
    indices=(sheet-1)*rowsPerPage+1:min(sheet*rowsPerPage,height(histogram));
    set(rowLabels,'String','');
    values=histogram{indices,:};
    for row=1:numel(indices)
        for col=1:5, rowLabels(row,col).String=sprintf('%d',values(row,col)); end
    end
    if isempty(histogram), emptyLabel.Visible='on'; end
    pageNumber=pageNumber+1;
    footer.String=sprintf('Страница %d | Распределение размеров: лист %d / %d', ...
        pageNumber,sheet,pageCount);
    drawnow;
    exportgraphics(canvas,pdfPath,'ContentType','vector','Append',isfile(pdfPath), ...
        'BackgroundColor','white');
end
end

function drawClusterSaturation(canvas,result)
% Reuse the run GIF renderer; keep only its saturation axes on this sheet.
releaseRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
previousPath=path;
pathCleanup=onCleanup(@() path(previousPath));
addpath(fullfile(releaseRoot,'visualization'),fullfile(releaseRoot,'reporting'),'-begin');
snapshot=load(result.snapshotPath);
if isfield(snapshot,'solvedNet'), Net=snapshot.solvedNet; else, Net=snapshot.Net; end
limits=[min(Net.P(:)) max(Net.P(:))];
if limits(1)==limits(2), limits=limits+[-1 1]; end
frame=drawSaturationPressureFrame(canvas,Net,snapshot,1,1,limits,true,[],[0 0 1 1]);
satAxes=ancestor(frame.water,'axes');
pressureAxes=ancestor(frame.pressure,'axes');
delete(findall(canvas,'Type','colorbar'));
delete(pressureAxes);
set(satAxes,'Units','normalized','Position',[.12 .18 .76 .28],'FontSize',9);
satAxes.Title.String=sprintf('Сатурация последнего снимка, шаг %d',result.step);
satAxes.Title.FontSize=10;
legendHandle=legend(satAxes);
legendHandle.FontSize=9;
end

function pageNumber=writeClusterDetails(result,pdfPath,pageNumber)
% Per-cluster H/V split precedes the final size-frequency table.
rowsPerPage=32;
fig=figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','points','Position',[10 10 595.276 841.89]);
cleanup=onCleanup(@() close(fig));
canvas=uipanel(fig,'Units','points','Position',[0 0 595.276 841.89], ...
    'BorderType','none','BackgroundColor','white');
if isprop(canvas,'AutoResizeChildren'), canvas.AutoResizeChildren='off'; end
ax=axes('Parent',canvas,'Position',[0 0 1 1],'Visible','off','XLim',[0 1],'YLim',[0 1]);
hold(ax,'on');
rectangle(ax,'Position',[0 0 1 1],'FaceColor','white','EdgeColor','none');
text(ax,.07,.95,'Состав кластеров вытесняемой фазы', ...
    'FontName','Arial','FontSize',16,'FontWeight','bold','Interpreter','none');
text(ax,.07,.90,sprintf('Последний снимок: шаг %d; t = %.9g с.', ...
    result.step,result.elapsedTime),'FontName','Arial','FontSize',10,'Interpreter','none');
text(ax,.07,.85,{'H / V - число горизонтальных / вертикальных каналов в кластере.', ...
    'Выход: 1 - связан с выходом; 0 - не имеет связи с выходом.', ...
    'Связь существует только через узел с вытесняемой фазой с обеих сторон.'}, ...
    'FontName','Arial','FontSize',9,'Interpreter','none','VerticalAlignment','top');
positions=[.07 .19 .33 .44 .55 .83];
headers={'ID','Каналов','H','V','Объём, м³','Выход'};
for k=1:6
    text(ax,positions(k),.75,headers{k},'FontName','Arial','FontSize',10, ...
        'FontWeight','bold','Interpreter','none');
end
labels=gobjects(rowsPerPage,6);
for row=1:rowsPerPage
    for col=1:6
        labels(row,col)=text(ax,positions(col),.72-(row-1)*.018,'', ...
            'FontName','Consolas','FontSize',9,'Interpreter','none');
    end
end
footer=text(ax,.07,.04,'','FontName','Arial','FontSize',9,'Interpreter','none');
if isempty(result.clusters)
    text(ax,.07,.70,'Нет кластеров без связи с правой границей.','FontName','Arial','FontSize',11);
end
for sheet=1:max(1,ceil(height(result.clusters)/rowsPerPage))
    indices=(sheet-1)*rowsPerPage+1:min(sheet*rowsPerPage,height(result.clusters));
    set(labels,'String','');
    for row=1:numel(indices)
        item=result.clusters(indices(row),:);
        values={sprintf('%d',item.ClusterID),sprintf('%d',item.ChannelCount), ...
            sprintf('%d',item.HorizontalCount),sprintf('%d',item.VerticalCount), ...
            sprintf('%.7g',item.DisplacedVolume),sprintf('%d',item.ConnectedToOutlet)};
        for col=1:6, labels(row,col).String=values{col}; end
    end
    pageNumber=pageNumber+1;
    footer.String=sprintf('Страница %d | Состав кластеров: лист %d',pageNumber,sheet);
    drawnow;
    exportgraphics(canvas,pdfPath,'ContentType','vector','Append',isfile(pdfPath), ...
        'BackgroundColor','white');
end
end
