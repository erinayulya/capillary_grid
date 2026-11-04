function pageCount = writeFrontFourierPdf(result,mobileParts,pdfPath)
%WRITEFRONTFOURIERPDF Nonempty snapshots, then numeric coefficient tables.
% Left: selected menisci and linear front. Right: numeric ten-harmonic
% formula above a 2-by-2 grid of partial sums for 1, 3, 6, 10 harmonics.
% Reads result.fourierFits and tables only; does not modify Net or snapshots.
% Point-sized canvas and guarded AutoResizeChildren support desktop R2023a.
pageSize = [36 25.5]; % centimeters; canvas dimensions are points below
fig = figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','centimeters', ...
    'Position',[1 1 pageSize],'PaperUnits','centimeters','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual', ...
    'InvertHardcopy','off');
figureCleanup = onCleanup(@() close(fig));
canvas = uipanel(fig,'Units','points', ...
    'Position',[0 0 pageSize/2.54*72], ...
    'BorderType','none','BackgroundColor','white');
if isprop(canvas,'AutoResizeChildren'), canvas.AutoResizeChildren = 'off'; end
pageAx = axes('Parent',canvas,'Position',[0 0 1 1],'Visible','off', ...
    'XLim',[0 1],'YLim',[0 1]);
heading = text(pageAx,.035,.965,'','FontName','Arial','FontSize',12, ...
    'Interpreter','none','VerticalAlignment','top');
text(pageAx,.49,.965,'Первые 10 гармоник линейного фронта x(y)', ...
    'FontName','Arial','FontSize',11,'Interpreter','none', ...
    'VerticalAlignment','top');
text(pageAx,.49,.647,'Точки: мениски; линия: сумма гармоник + среднее.', ...
    'FontName','Arial','FontSize',8.5,'Interpreter','none');
ax = axes('Parent',canvas,'Position',[.06 .18 .36 .68]);
hold(ax,'on');
curve = plot(ax,NaN,NaN,'--','Color',[0 .35 .75],'LineWidth',1.5);
points = plot(ax,NaN,NaN,'o','LineStyle','none', ...
    'MarkerFaceColor',[1 .3 .15],'MarkerEdgeColor','w','MarkerSize',4);
axis(ax,'equal'); xlim(ax,[0 1]); ylim(ax,[0 1]);
grid(ax,'on'); box(ax,'on');
set(ax,'FontName','Arial','FontSize',10,'XTick',0:.2:1,'YTick',0:.2:1);
xlabel(ax,'x / ширина сети'); ylabel(ax,'y / высота сети');
legend(ax,[points curve],{'Мениски: State=1, Move~=2', ...
    'Линейный фронт: среднее x при одинаковом y'}, ...
    'Location','southoutside','Interpreter','none','FontSize',8,'AutoUpdate','off');
emptyLabel = text(ax,.5,.5,'Нет менисков с Move~=2', ...
    'HorizontalAlignment','center','Visible','off','FontSize',10);
formulaAx = axes('Parent',canvas,'Position',[.49 .69 .49 .245], ...
    'Visible','off','XLim',[0 1],'YLim',[0 1]);
formula = text(formulaAx,0,1,'','VerticalAlignment','top', ...
    'Interpreter','none','FontName','Consolas','FontSize',8.5);
positions = [.55 .385 .18 .22; .79 .385 .18 .22; ...
    .55 .08 .18 .22; .79 .08 .18 .22];
counts = [1 3 6 10];
plotTitles = {'Первая гармоника','Первые 3 гармоники', ...
    'Первые 6 гармоник','Первые 10 гармоник'};
sumAxes = gobjects(4,1); sumPoints = gobjects(4,1);
sumCurves = gobjects(4,1); sumLabels = gobjects(4,1);
for j = 1:numel(counts)
    sumAxes(j) = axes('Parent',canvas,'Position',positions(j,:));
    hold(sumAxes(j),'on');
    sumPoints(j) = plot(sumAxes(j),NaN,NaN,'o','LineStyle','none', ...
        'MarkerFaceColor',[.3 .3 .3],'MarkerEdgeColor','none','MarkerSize',2.3);
    sumCurves(j) = plot(sumAxes(j),NaN,NaN,'Color',[.45 .08 .8],'LineWidth',1.3);
    grid(sumAxes(j),'on'); box(sumAxes(j),'on');
    set(sumAxes(j),'FontName','Arial','FontSize',7.5);
    xlabel(sumAxes(j),'y / высота сети','FontSize',7.5);
    ylabel(sumAxes(j),'x / ширина сети','FontSize',7.5);
    title(sumAxes(j),plotTitles{j},'FontSize',9);
    sumLabels(j) = text(sumAxes(j),.5,.5,'Нет разложения', ...
        'Units','normalized','HorizontalAlignment','center', ...
        'Visible','off','FontSize',8);
end
frameIndices = find(result.frames.MobileCount>0 & result.frames.Time~=0);
for pageIndex = 1:numel(frameIndices)
    k = frameIndices(pageIndex);
    menisci = mobileParts{k}; fit = result.frontFits{k};
    series = result.fourierFits{k};
    heading.String = {sprintf('Шаг %d | t = %.6g с', ...
        result.frames.Step(k),result.frames.Time(k)), ...
        sprintf('Снимок %d / %d | Менисков: %d',k,height(result.frames),height(menisci))};
    set(points,'XData',menisci.X,'YData',menisci.Y);
    if strcmp(fit.method,'linear')
        set(curve,'XData',fit.sampleX,'YData',fit.sampleY);
    else
        set(curve,'XData',NaN,'YData',NaN);
    end
    emptyLabel.Visible = 'off';
    if isempty(menisci), emptyLabel.Visible = 'on'; end
    formula.String = series.formulaLines;
    if strcmp(series.status,'ok')
        allX = [menisci.X;series.partialSums(:)];
        limits = [min(allX) max(allX)];
        padding = .05*max(diff(limits),.02);
        limits = limits+[-padding padding];
    else
        limits = [0 1];
    end
    for j = 1:4
        set(sumPoints(j),'XData',menisci.Y,'YData',menisci.X);
        sumLabels(j).Visible = 'off';
        if strcmp(series.status,'ok')
            set(sumCurves(j),'XData',series.sampleY,'YData',series.partialSums(:,j));
            xlim(sumAxes(j),series.domain);
        else
            set(sumCurves(j),'XData',NaN,'YData',NaN);
            xlim(sumAxes(j),[0 1]);
            sumLabels(j).Visible = 'on';
        end
        ylim(sumAxes(j),limits);
    end
    drawnow;
    exportgraphics(canvas,pdfPath,'ContentType','vector', ...
        'Append',pageIndex>1,'BackgroundColor','white');
    if pageIndex == 1 || pageIndex == numel(frameIndices) || mod(pageIndex,50)==0
        fprintf('PDF фронта: %d / %d снимков\n',pageIndex,numel(frameIndices));
    end
end
coefficientPages = writeFrontCoefficientPdf(result,pdfPath,~isempty(frameIndices));
pageCount = numel(frameIndices)+coefficientPages;
if isfield(result,'analyzeClusters') && result.analyzeClusters
    pageCount = writeResidualClusterPdf(result.residualAnalysis,pdfPath,pageCount);
end
end
