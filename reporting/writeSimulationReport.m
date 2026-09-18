function pdfPath = writeSimulationReport(directory)
%WRITESIMULATIONREPORT Rebuild a PDF from saved parameters and step MAT files.
% Uses base MATLAB graphics; no Report Generator or external Python required.
data = load(fullfile(directory,'summary.mat'),'result','parameters');
result = data.result;
Net = data.parameters;
pdfPath = fullfile(directory,'report.pdf');
% Build separately so an earlier report survives an interrupted regeneration.
temporaryPdf = [tempname(directory) '.pdf'];
maxRows = max(Net.H.Ny,Net.V.Ny);
maxCols = max(Net.H.Nx,Net.V.Nx);
width = max(900, 2*(70+maxCols*105)+90);
tableHeight = 40 + 20*(maxRows+1);
height = max(1273, 490 + 7*tableHeight);
fig = figure('Visible','off','Color','w','Units','pixels', ...
    'Position',[10 10 width height],'IntegerHandle','off');
cleanup = onCleanup(@() close(fig));
canvas = page(fig,width,height);
label(canvas,40,55,'Результаты моделирования',23,true);
label(canvas,40,94,['Дата начала: ' result.startedAt],12,false);
label(canvas,40,132,sprintf('Общее модельное время (сумма dt): %.12g с', ...
    result.totalTime),15,true);
label(canvas,40,166,sprintf('Выполнено шагов: %d',result.steps),12,false);
label(canvas,40,199,result.status,11,false);
if isfield(result,'totalComputeTime')
    computeText = sprintf('Общее время вычислений (включая шаг 0): %.6g с',result.totalComputeTime);
    if isfield(result,'failedComputeTime') && result.failedComputeTime > 0
        computeText = sprintf('%s; незавершённый расчёт: %.6g с',computeText,result.failedComputeTime);
    end
else
    computeText = 'Общее время вычислений: не измерялось.';
end
label(canvas,40,226,computeText,11,true);
if Net.VerticalBC, boundary = 'открыты'; else, boundary = 'закрыты'; end
lines = {
    sprintf('Давление на левой границе, Net.H.P0: %.12g Па',Net.H.P0)
    sprintf('Давление на верхней границе, Net.V.P0: %.12g Па',Net.V.P0)
    'Давление справа и снизу: 0 Па'
    ['Верхняя и нижняя границы: ' boundary]
    sprintf('Вязкость воды, Net.mu1: %.12g Па·с',Net.mu1)
    sprintf('Вязкость нефти, Net.mu2: %.12g Па·с',Net.mu2)
    sprintf('Длина капилляра, Net.L: %.12g м',Net.L)
    sprintf('Поверхностное натяжение, Net.sigma: %.12g Н/м',Net.sigma)
    sprintf('Угол смачивания, Net.theta: %.12g рад',Net.theta)
    sprintf('Коэффициент динамической модели, Net.kdyn: %.12g',Net.kdyn)
    sprintf('Множитель границ режимов, Net.bound: %.12g',Net.bound)
    sprintf('Внутренние узлы: %d строк x %d столбцов',Net.H.Ny,Net.H.Nx-1)
    'Начальное состояние сохранено в parameters.mat; шаг 0 показан отдельно.'
    'Время вычислений не включает запись MAT, построение PDF, графики и диалоги.'};
for k=1:numel(lines), label(canvas,40,255+29*(k-1),lines{k},11,false); end
drawTable(canvas,Net.H.A,'Net.H.A - площади горизонтальных капилляров, м²', ...
    40,700,width-80,'%.6g');
drawTable(canvas,Net.V.A,'Net.V.A - площади вертикальных капилляров, м²', ...
    40,710+tableHeight,width-80,'%.6g');
label(canvas,40,height-42, ...
    'Таблицы: 6 значащих цифр. Полная точность сохранена в MAT-файлах.',10,false);
exportgraphics(fig,temporaryPdf,'ContentType','vector');

files = dir(fullfile(directory,'step_*.mat'));
[~,order] = sort({files.name});
for k = order
    snapshot = load(fullfile(directory,files(k).name));
    Net = snapshot.Net;
    canvas = page(fig,width,height);
    label(canvas,40,38,sprintf('Шаг %d',snapshot.step),20,true);
    label(canvas,40,72,sprintf('dt выполненного шага = %.12g с     t = %.12g с', ...
        snapshot.dtUsed,snapshot.elapsedTime),12,true);
    label(canvas,40,100,sprintf('Net.dt для следующего шага = %.12g с',Net.dt),10,false);
    if isfield(snapshot,'stepComputeTime') && isfield(snapshot,'totalComputeTime')
        computeText = sprintf('Вычисления шага: %.6g с; накопленное время вычислений: %.6g с', ...
            snapshot.stepComputeTime,snapshot.totalComputeTime);
    else
        computeText = 'Время вычислений шага и накопленное: не измерялось.';
    end
    label(canvas,40,126,computeText,10,true);
    ax = axes(fig,'Units','normalized', ...
        'Position',[80/width (height-410)/height (width-160)/width 260/height]);
    drawNetwork(Net,snapshot.step>0,ax);
    set(ax,'FontName','Arial','FontSize',10);
    ax.Toolbar.Visible = 'off';
    drawTable(canvas,Net.P,'Net.P - давление в узлах, Па', ...
        40,445,width-80,'%.6g');
    fields = {'Q','Dir','Sat','State','Move','Regime'};
    captions = {'расход, м³/с','направление','доля второй фазы, безразм.', ...
        'состояние','подвижность','режим'};
    for j=1:numel(fields)
        y = 445+j*tableHeight;
        for side=1:2
            orientation = 'HV'; key = orientation(side);
            titleText = sprintf('Net.%s.%s - %s',key,fields{j},captions{j});
            if ismember(fields{j},{'Q','Sat'}), format = '%.6g'; else, format = '%d'; end
            drawTable(canvas,Net.(key).(fields{j}),titleText, ...
                40+(side-1)*width/2,y,width/2-60,format);
        end
    end
    label(canvas,40,height-20,sprintf('Страница %d | Индексы строк и столбцов соответствуют MATLAB.', ...
        snapshot.step+2),9,false);
    exportgraphics(fig,temporaryPdf,'ContentType','vector','Append',true);
end
movefile(temporaryPdf,pdfPath,'f');
end

function ax = page(fig,width,height)
clf(fig);
ax = axes(fig,'Units','normalized','Position',[0 0 1 1], ...
    'XLim',[0 width],'YLim',[0 height],'YDir','reverse','Visible','off');
hold(ax,'on');
ax.Toolbar.Visible = 'off';
rectangle(ax,'Position',[0 0 width height],'FaceColor','w','EdgeColor','none');
end

function label(ax,x,y,value,fontSize,bold)
weight = 'normal';
if bold, weight = 'bold'; end
text(ax,x,y,value,'FontName','Arial','FontSize',fontSize, ...
    'FontWeight',weight,'Interpreter','none','VerticalAlignment','middle');
end

function drawTable(ax,A,titleText,x,y,width,format)
label(ax,x,y,titleText,11,true);
[rows,cols] = size(A);
cellWidth = width/(cols+1);
rowHeight = 20;
top = y+17;
headerColor = [.9 .94 .97];
rectangle(ax,'Position',[x top width rowHeight], ...
    'FaceColor',headerColor,'EdgeColor','none');
rectangle(ax,'Position',[x top cellWidth (rows+1)*rowHeight], ...
    'FaceColor',headerColor,'EdgeColor','none');
for r=0:rows+1
    line(ax,[x x+width],[top+r*rowHeight top+r*rowHeight],'Color',[.75 .8 .85]);
end
for c=0:cols+1
    line(ax,[x+c*cellWidth x+c*cellWidth],[top top+(rows+1)*rowHeight], ...
        'Color',[.75 .8 .85]);
end
for r=0:rows
    for c=0:cols
        if r==0 && c==0, value='i / j';
        elseif r==0, value=sprintf('%d',c);
        elseif c==0, value=sprintf('%d',r);
        else, value=sprintf(format,A(r,c)); end
        text(ax,x+(c+.5)*cellWidth,top+(r+.5)*rowHeight,value, ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName','Arial','FontSize',9,'Interpreter','none');
    end
end
end
