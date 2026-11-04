function pageCount = writeFrontCoefficientPdf(result,pdfPath,append)
%WRITEFRONTCOEFFICIENTPDF Selectable numeric tables at the end of front PDF.
% Two blocks per sheet: a1..a10 and b1..b10, indexed by elapsed seconds.
% Filtered tables exclude t=0 and unavailable coefficients in MAT/CSV/TSV.
% Long runs use multiple closing sheets rather than shrinking or losing rows.
rowCount = height(result.harmonicCosTable);
rowsPerPage = 22;
pageCount = max(1,ceil(rowCount/rowsPerPage));
pageSize = [36 25.5];
fig = figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','centimeters', ...
    'Position',[1 1 pageSize],'PaperUnits','centimeters','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual','InvertHardcopy','off');
figureCleanup = onCleanup(@() close(fig));
canvas = uipanel(fig,'Units','points','Position',[0 0 pageSize/2.54*72], ...
    'BorderType','none','BackgroundColor','white');
if isprop(canvas,'AutoResizeChildren'), canvas.AutoResizeChildren = 'off'; end
ax = axes('Parent',canvas,'Position',[0 0 1 1],'Visible','off', ...
    'XLim',[0 1],'YLim',[0 1]);
heading = text(ax,.035,.965,'','Interpreter','none','FontName','Arial', ...
    'FontSize',13,'VerticalAlignment','top');
text(ax,.035,.915,'x(y) = a0 + sum[a_n*cos(2*pi*n*u) + b_n*sin(2*pi*n*u)]', ...
    'Interpreter','none','FontName','Consolas','FontSize',9);
text(ax,.035,.88,'Time_s: время, с. a_n/b_n: доля ширины сети. Исключены t=0 и неопределённые коэффициенты.', ...
    'Interpreter','none','FontName','Arial','FontSize',9);
text(ax,.035,.835,'Коэффициенты косинуса a_n', ...
    'Interpreter','none','FontName','Arial','FontSize',10,'FontWeight','bold');
cosText = text(ax,.035,.81,'','Interpreter','none','FontName','Consolas', ...
    'FontSize',8,'VerticalAlignment','top');
text(ax,.035,.435,'Коэффициенты синуса b_n', ...
    'Interpreter','none','FontName','Arial','FontSize',10,'FontWeight','bold');
sinText = text(ax,.035,.41,'','Interpreter','none','FontName','Consolas', ...
    'FontSize',8,'VerticalAlignment','top');
text(ax,.035,.035,'Для копирования в Excel: harmonic_coefficients.tsv (табуляция) или .csv.', ...
    'Interpreter','none','FontName','Arial','FontSize',9);
times = seconds(result.harmonicCosTable.Time);
for page = 1:pageCount
    indices = (page-1)*rowsPerPage+1:min(page*rowsPerPage,rowCount);
    heading.String = sprintf('Численные коэффициенты 10 гармоник | Таблица %d / %d',page,pageCount);
    cosText.String = tableLines(times(indices),result.harmonicCosTable{indices,:},'a');
    sinText.String = tableLines(times(indices),result.harmonicSinTable{indices,:},'b');
    drawnow;
    exportgraphics(canvas,pdfPath,'ContentType','vector', ...
        'Append',append || page>1,'BackgroundColor','white');
end
end

function lines = tableLines(times,values,prefix)
lines = cell(numel(times)+2,1);
header = sprintf('%-13s','Time_s');
for n = 1:10
    header = [header sprintf(' %12s',sprintf('%s%d',prefix,n))]; %#ok<AGROW>
end
lines{1} = header;
lines{2} = repmat('-',1,numel(header));
if isempty(times)
    lines{3} = 'Нет подходящих строк.';
end
for k = 1:numel(times)
    lines{k+2} = [sprintf('%-13.7g',times(k)) sprintf(' %12.7g',values(k,:))];
end
end
