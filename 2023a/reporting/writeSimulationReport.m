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
height = max([1273, 550 + 7*tableHeight, ceil(width*1106/806)]);
fig = figure('Visible','off','Color','w','Units','pixels', ...
    'Position',[10 10 width height],'IntegerHandle','off', ...
    'WindowStyle','normal','Resize','off');
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
physicsLines = modelParameterLines(Net);
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
    physicsLines{1}
    physicsLines{2}
    sprintf('Внутренние узлы: %d строк x %d столбцов',Net.H.Ny,Net.H.Nx-1)
    'Начальное состояние сохранено в parameters.mat; шаг 0 показан отдельно.'
    'Время вычислений не включает запись MAT, построение PDF, графики и диалоги.'};
for k=1:numel(lines), label(canvas,40,255+29*(k-1),lines{k},11,false); end
[PcH,PcV] = capillaryPressures(Net);
pressureName = 'p_c';
if isfield(Net,'k'), pressureName = 'P_crit'; end
drawTable(canvas,Net.H.A,'Net.H.A - площади горизонтальных капилляров, м²', ...
    40,700,width-80,'%.6g');
drawTable(canvas,Net.V.A,'Net.V.A - площади вертикальных капилляров, м²', ...
    40,710+tableHeight,width-80,'%.6g');
drawTable(canvas,PcH,[pressureName ' горизонтальных капилляров, Па'], ...
    40,720+2*tableHeight,width-80,'%.6g');
drawTable(canvas,PcV,[pressureName ' вертикальных капилляров, Па'], ...
    40,730+3*tableHeight,width-80,'%.6g');
label(canvas,40,height-42, ...
    'Таблицы: 6 значащих цифр. Полная точность сохранена в MAT-файлах.',10,false);
exportPage(fig,temporaryPdf,width,height,false);

files = dir(fullfile(directory,'step_*.mat'));
[~,order] = sort({files.name});
for k = order
    snapshot = loadSimulationStep(fullfile(directory,files(k).name));
    Net = snapshot.Net;
    canvas = page(fig,width,height);
    label(canvas,40,38,sprintf('Шаг %d',snapshot.step),20,true);
    label(canvas,40,72,sprintf('dt выполненного шага = %.12g с     t = %.12g с', ...
        snapshot.dtUsed,snapshot.elapsedTime),12,true);
    label(canvas,40,100,sprintf('dt после решения для следующего шага = %.12g с',snapshot.solvedNet.dt),10,false);
    if isfield(snapshot,'stepComputeTime') && isfield(snapshot,'totalComputeTime')
        computeText = sprintf('Вычисления шага: %.6g с; накопленное время вычислений: %.6g с', ...
            snapshot.stepComputeTime,snapshot.totalComputeTime);
    else
        computeText = 'Время вычислений шага и накопленное: не измерялось.';
    end
    label(canvas,40,126,computeText,10,true);
    if strcmp(snapshot.reportPhase,'beforeSolve')
        phaseText = 'Перед решением: P и Q предыдущего шага; Sat, State, Move и Regime обновлены.';
    else
        phaseText = 'После решения: P, Q, Move и Regime относятся к одному принятому состоянию.';
    end
    label(canvas,40,150,phaseText,10,false);
    leftCenter = 40 + (width/2-60)/2;
    rightCenter = leftCenter + width/2;
    networkWidth = 270;
    legendWidth = 145;
    legendGap = 20;
    networkLeft = rightCenter - (networkWidth+legendGap+legendWidth)/2;
    ax = axes(canvas.Parent,'Units','normalized', ...
        'Position',[networkLeft/width (height-430)/height networkWidth/width 270/height]);
    drawNetwork(Net,snapshot.step>0,ax);
    set(ax,'FontName','Arial','FontSize',10);
    ax.Toolbar.Visible = 'off';
    % Centre the network and its narrow right-hand legend together above V.
    networkLegend = legend(ax);
    legendText = networkLegend.String;
    legendText = strrep(legendText,'Предыдущее положение',sprintf('Предыдущее\nположение'));
    legendText = strrep(legendText,'Мениск подвижен',sprintf('Мениск\nподвижен'));
    legendText = strrep(legendText,'Мениск заблокирован',sprintf('Мениск\nзаблокирован'));
    legendText = strrep(legendText,'Мениск временно неподвижен',sprintf('Мениск временно\nнеподвижен'));
    set(networkLegend,'Units','normalized','NumColumns',1,'FontSize',7, ...
        'String',legendText,'ItemTokenSize',[12 10], ...
        'Position',[(networkLeft+networkWidth+legendGap)/width ...
        (height-405)/height legendWidth/width 220/height]);
    if snapshot.step > 0
        title(networkLegend,sprintf('Move сохранённого\nсостояния'),'FontSize',7);
    end
    set(ax,'Position',[networkLeft/width (height-430)/height networkWidth/width 270/height], ...
        'XLim',[-0.3 Net.H.Nx+0.3],'YLim',[-1.3 Net.H.Ny+0.3]);
    drawTable(canvas,Net.P,'Net.P - давление в узлах, Па', ...
        40,180,width/2-60,'%.6g');
    fields = {'Q','Dir','Sat','State','Regime'};
    captions = {'расход, м³/с','направление','доля второй фазы, безразм.', ...
        'состояние','режим'};
    fieldsY = 470;
    for j=1:numel(fields)
        y = fieldsY+(j-1)*tableHeight;
        for side=1:2
            orientation = 'HV'; key = orientation(side);
            titleText = sprintf('Net.%s.%s - %s',key,fields{j},captions{j});
            if ismember(fields{j},{'Q','Sat'}), format = '%.6g'; else, format = '%d'; end
            drawTable(canvas,Net.(key).(fields{j}),titleText, ...
                40+(side-1)*width/2,y,width/2-60,format);
        end
    end
    moveY = fieldsY + 5*tableHeight + 5;
    line(canvas,[40 width-40],[moveY moveY],'Color',[.35 .4 .45],'LineWidth',0.8);
    label(canvas,40,moveY+22,'Move сохранённого состояния (как на рисунке)',10,true);
    drawTable(canvas,Net.H.Move,'Net.H.Move', ...
        40,moveY+38,width/2-60,'%d');
    drawTable(canvas,Net.V.Move,'Net.V.Move', ...
        40+width/2,moveY+38,width/2-60,'%d');
    [marginH,marginV] = movePressureMargin(Net);
    marginY = moveY + tableHeight + 38;
    label(canvas,40,marginY+22, ...
        ['Ориентированный перепад минус ' pressureName ' (положение относительно границы режимов), Па'], ...
        10,true);
    drawTable(canvas,marginH,['Net.H: Δp − ' pressureName ', Па'], ...
        40,marginY+38,width/2-60,'%.6g');
    drawTable(canvas,marginV,['Net.V: Δp − ' pressureName ', Па'], ...
        40+width/2,marginY+38,width/2-60,'%.6g');
    label(canvas,40,height-20,sprintf('Страница %d | Индексы строк и столбцов соответствуют MATLAB.', ...
        snapshot.step+2),9,false);
    exportPage(fig,temporaryPdf,width,height,true);
end
movefile(temporaryPdf,pdfPath,'f');
end

function exportPage(fig,pdfPath,width,height,append)
% R2023a: a fixed-size panel avoids screen limits on the figure's height.
% exportgraphics adds its own thin margin; no R2025a size options are used.
drawnow;
canvasPanel = findobj(fig,'Type','uipanel');
set(canvasPanel,'Units','points','Position',[0 0 0.75*width 0.75*height]);
exportgraphics(canvasPanel,pdfPath,'ContentType','vector','Append',append, ...
    'BackgroundColor','white');
end

function ax = page(fig,width,height)
clf(fig);
canvasPanel = uipanel(fig,'Units','points', ...
    'Position',[0 0 0.75*width 0.75*height],'BorderType','none', ...
    'BackgroundColor','w');
% This property exists on figure-based panels only from R2025a.
if isprop(canvasPanel,'AutoResizeChildren')
    canvasPanel.AutoResizeChildren = 'off';
end
ax = axes(canvasPanel,'Units','normalized','Position',[0 0 1 1], ...
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
        elseif isnan(A(r,c)), value='—';
        else, value=sprintf(format,A(r,c)); end
        text(ax,x+(c+.5)*cellWidth,top+(r+.5)*rowHeight,value, ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName','Arial','FontSize',9,'Interpreter','none');
    end
end
end

function [PcH,PcV] = capillaryPressures(Net)
if isfield(Net,'k')
    PcH = Net.coef*sqrt(Net.H.A/pi).^(-5/4);
    PcV = Net.coef*sqrt(Net.V.A/pi).^(-5/4);
else
    % Чтение исторических отчётов без переинтерпретации параметров.
    PcH = 2*Net.sigma*cos(Net.theta)./sqrt(Net.H.A/pi);
    PcV = 2*Net.sigma*cos(Net.theta)./sqrt(Net.V.A/pi);
end
end

function lines = modelParameterLines(Net)
if isfield(Net,'k')
    lines = {
        sprintf('Коэффициент плато k: %.12g; xi: %.12g',Net.k,Net.xi)
        sprintf('P_crit: coef=%.12g Па·м^(5/4); ширина=%.12g Па',Net.coef,Net.P_crit_width)};
else
    lines = {
        sprintf('Исторический коэффициент kdyn: %.12g',Net.kdyn)
        sprintf('Исторический множитель bound: %.12g',Net.bound)};
end
end

function [marginH,marginV] = movePressureMargin(Net)
marginH = nan(size(Net.H.A));
marginV = nan(size(Net.V.A));
[PcH,PcV] = capillaryPressures(Net);
for i=1:Net.H.Ny
    for j=1:Net.H.Nx
        if Net.H.State(i,j) ~= 1
            continue
        end
        if j == 1
            dp = Net.H.P0 - Net.P(i,1);
        elseif j == Net.H.Nx
            dp = Net.P(i,j-1);
        else
            dp = Net.P(i,j-1) - Net.P(i,j);
        end
        marginH(i,j) = Net.H.Dir(i,j)*dp - PcH(i,j);
    end
end
for i=1:Net.V.Ny
    for j=1:Net.V.Nx
        if Net.V.State(i,j) ~= 1
            continue
        end
        if i == 1
            dp = Net.V.P0 - Net.P(1,j);
        elseif i == Net.V.Ny
            dp = Net.P(i-1,j);
        else
            dp = Net.P(i-1,j) - Net.P(i,j);
        end
        marginV(i,j) = Net.V.Dir(i,j)*dp - PcV(i,j);
    end
end
end
