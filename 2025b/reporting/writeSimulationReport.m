function [pdfPath,result] = writeSimulationReport(directory,stride,gifPath,reportOptions)
%WRITESIMULATIONREPORT Rebuild a PDF from saved parameters and step MAT files.
% Uses base MATLAB graphics; no Report Generator or external Python required.
if nargin < 2, stride = 1; end
if nargin < 3, gifPath = ''; end
if nargin < 4, reportOptions = struct(); end
% With a GIF, include every saved frame and only P/H.Q/V.Q from solvedNet.
hasGif = ~isempty(gifPath);
savedFrames = false;
if isfield(reportOptions,'savedFrames'), savedFrames = reportOptions.savedFrames; end
validateattributes(savedFrames,{'logical','numeric'},{'scalar','binary'});
frameReport = hasGif || savedFrames;
if hasGif, frameInfo = imfinfo(gifPath); end
data = load(fullfile(directory,'summary.mat'),'result','parameters');
result = data.result;
selectedSteps = selectSimulationReportSteps(result.steps,stride);
Net = data.parameters;
presentation = simulationReportPresentation(Net,result,reportOptions);
result.reportModelOptions = presentation.modelOptions;
pdfPath = fullfile(directory,'report.pdf');
% Build separately so an earlier report survives an interrupted regeneration.
temporaryPdf = [tempname(directory) '.pdf'];
fileCleanup = onCleanup(@() deleteTemporaryPdf(temporaryPdf));
maxRows = max(Net.H.Ny,Net.V.Ny);
maxCols = max(Net.H.Nx,Net.V.Nx);
margin = 20/25.4*96; % 20 mm; export scale is 0.75 points per canvas unit.
width = max(210/25.4*96, 2*margin+(maxCols+1)*80);
if ~frameReport, width = max(width,2*margin+2*(maxCols+1)*100+30); end
tableHeight = 40 + 20*(maxRows+1);
firstTableHeight = 32+20*(maxRows+1);
firstTableY = margin+186+18*(numel(presentation.boundaryLines)+ ...
    numel(presentation.modelLines)+8)+18;
height = max([297/25.4*96, firstTableY+4*firstTableHeight+margin+40, ...
    2*margin+100+(width-2*margin)*21/29.7+3*tableHeight, ceil(width*1106/806)]);
if ~frameReport
    legacyFieldsY = max(margin+446,margin+186+tableHeight);
    height = max(height,legacyFieldsY+7*tableHeight+150+margin);
end
result.reportLayout = struct('marginMm',20,'pageSizePoints',0.75*[width height], ...
    'cellSizePoints',[60 15], ...
    'frameArtwork','vector','tableOrder',{{'P','H.Q','V.Q'}});
if frameReport
    frameMetrics = frameLayout(Net,width,margin);
    result.reportLayout.framePageSizePoints = .75*[frameMetrics.pictureWidth frameMetrics.pageHeight];
    result.reportLayout.imageHeightFraction = 1/2;
    result.reportLayout.figureArrangement = 'stacked-adaptive';
    result.reportLayout.tablePageSizePoints = .75*[width frameMetrics.pageHeight];
    result.reportLayout.preferredCellPitchPoints = 32;
    result.reportLayout.textFontSizePoints = [11 12];
end
fig = figure('Visible','off','Color','w','Units','pixels', ...
    'Position',[10 10 width height],'IntegerHandle','off', ...
    'WindowStyle','normal','Resize','off');
cleanup = onCleanup(@() close(fig));
canvas = page(fig,width,height);
label(canvas,margin,margin+20,'Результаты моделирования',23,true);
label(canvas,margin,margin+50,['Дата начала: ' result.startedAt],12,false);
label(canvas,margin,margin+80,sprintf('Общее модельное время (сумма dt): %.12g с', ...
    result.totalTime),15,true);
label(canvas,margin,margin+108,sprintf('Выполнено шагов: %d',result.steps),12,false);
statusBottom = label(canvas,margin,margin+134,result.status,11,false);
if isfield(result,'totalComputeTime')
    computeText = sprintf('Общее время вычислений (включая шаг 0): %.6g с',result.totalComputeTime);
    if isfield(result,'failedComputeTime') && result.failedComputeTime > 0
        computeText = sprintf('%s; незавершённый расчёт: %.6g с',computeText,result.failedComputeTime);
    end
else
    computeText = 'Общее время вычислений: не измерялось.';
end
computeBottom = label(canvas,margin,max(margin+158,statusBottom+18),computeText,10,true);
lines = [presentation.boundaryLines; {
    sprintf('Вязкость воды, Net.mu1: %.12g Па·с',Net.mu1)
    sprintf('Вязкость нефти, Net.mu2: %.12g Па·с',Net.mu2)
    sprintf('Длина капилляра, Net.L: %.12g м',Net.L)
    sprintf('Поверхностное натяжение, Net.sigma: %.12g Н/м',Net.sigma)
    sprintf('Угол смачивания, Net.theta: %.12g рад',Net.theta)
    }; presentation.modelLines; {
    sprintf('Внутренние узлы: %d строк x %d столбцов',Net.H.Ny,Net.H.Nx-1)
    'Начальное состояние сохранено в parameters.mat; шаг 0 показан отдельно.'
    'Время вычислений не включает запись MAT, построение PDF, графики и диалоги.'}];
nextY = max(margin+186,computeBottom+22);
for k=1:numel(lines)
    bottom = label(canvas,margin,nextY,lines{k},10,false);
    nextY = max(nextY+18,bottom+8);
end
firstTableY = max(firstTableY,nextY+18);
neededHeight = firstTableY+4*firstTableHeight+margin+40;
if neededHeight > height
    height = neededHeight;
    set(fig,'Position',[10 10 width height]);
    if isa(canvas.Parent,'matlab.ui.container.Panel')
        set(canvas.Parent,'Units','points','Position',[0 0 .75*width .75*height]);
    end
    canvas.YLim = [0 height];
    background = findobj(canvas,'Type','rectangle');
    set(background,'Position',[0 0 width height]);
    result.reportLayout.pageSizePoints = .75*[width height];
end
pressureName = 'p_c';
if isfield(Net,'k'), pressureName = 'P_crit'; end
if presentation.modelOptions.meniscusModel == 1, pressureName = '0 (вязкий режим)'; end
drawTable(canvas,Net.H.A,'Net.H.A - площади горизонтальных капилляров, м²', ...
    margin,firstTableY,(size(Net.H.A,2)+1)*80,'%.6g');
drawTable(canvas,Net.V.A,'Net.V.A - площади вертикальных капилляров, м²', ...
    margin,firstTableY+firstTableHeight,(size(Net.V.A,2)+1)*80,'%.6g');
drawTable(canvas,presentation.PcapH,'P_cap горизонтальных капилляров, Па', ...
    margin,firstTableY+2*firstTableHeight,(size(Net.H.A,2)+1)*80,'%.6g');
drawTable(canvas,presentation.PcapV,'P_cap вертикальных капилляров, Па', ...
    margin,firstTableY+3*firstTableHeight,(size(Net.V.A,2)+1)*80,'%.6g');
label(canvas,margin,height-margin-12, ...
    'Таблицы: 6 значащих цифр. Полная точность сохранена в MAT-файлах.',10,false);
exportPage(fig,temporaryPdf,width,height,false);

files = dir(fullfile(directory,'step_*.mat'));
[~,order] = sort({files.name});
stepNumbers = cellfun(@(name) sscanf(name,'step_%d'),{files.name});
order = order(ismember(stepNumbers(order),selectedSteps));
if frameReport
    [~,order] = sort(stepNumbers);
    if hasGif && numel(frameInfo) ~= numel(order)
        error('writeSimulationReport:FrameCount', ...
            'Число кадров GIF (%d) не совпадает с числом сохранённых состояний (%d).', ...
            numel(frameInfo),numel(order));
    end
    pressureRange = [Inf -Inf];
    for frame = order
        state = loadSimulationStep(fullfile(directory,files(frame).name));
        pressureRange = [min(pressureRange(1),min(state.solvedNet.P(:))), ...
            max(pressureRange(2),max(state.solvedNet.P(:)))];
    end
    if pressureRange(1) == pressureRange(2)
        pad = max(1,abs(pressureRange(1))*0.01);
        pressureRange = pressureRange+[-pad pad];
    end
end
renderedSteps = zeros(1,numel(order));
stepPages = zeros(numel(order),3); % [step, first page, last page]
frameIndex = 0;
pageNumber = 1;
for k = order
    frameIndex = frameIndex+1;
    snapshot = loadSimulationStep(fullfile(directory,files(k).name));
    pageNumber = pageNumber + 1;
    firstPage = pageNumber;
    renderedSteps(frameIndex) = snapshot.step;
    Net = snapshot.Net;
    if frameReport
        Net = snapshot.solvedNet;
        frameMetrics = frameLayout(Net,width,margin);
        frameHeight = frameMetrics.pageHeight;
        pageNumber = drawGifPage(fig,Net,snapshot,frameIndex,numel(order),pressureRange, ...
            presentation.modelOptions.showMeniscus,width,frameHeight,margin,pageNumber,temporaryPdf);
        stepPages(frameIndex,:) = [snapshot.step firstPage pageNumber];
        continue;
    end
    canvas = page(fig,width,height);
    label(canvas,margin,margin+14,sprintf('Шаг %d',snapshot.step),20,true);
    label(canvas,margin,margin+48,sprintf('dt выполненного шага = %.12g с     t = %.12g с', ...
        snapshot.dtUsed,snapshot.elapsedTime),12,true);
    label(canvas,margin,margin+76,sprintf('dt после решения для следующего шага = %.12g с',snapshot.solvedNet.dt),10,false);
    if isfield(snapshot,'stepComputeTime') && isfield(snapshot,'totalComputeTime')
        computeText = sprintf('Вычисления шага: %.6g с; накопленное время вычислений: %.6g с', ...
            snapshot.stepComputeTime,snapshot.totalComputeTime);
    else
        computeText = 'Время вычислений шага и накопленное: не измерялось.';
    end
    label(canvas,margin,margin+102,computeText,10,true);
    if strcmp(snapshot.reportPhase,'beforeSolve')
        phaseText = 'Перед решением: P и Q предыдущего шага; Sat, State, Move и Regime обновлены.';
    else
        phaseText = 'После решения: P, Q, Move и Regime относятся к одному принятому состоянию.';
    end
    label(canvas,margin,margin+126,phaseText,10,false);
    columnWidth = (width-2*margin-30)/2;
    leftCenter = margin+columnWidth/2;
    rightCenter = width-margin-columnWidth/2;
    networkWidth = min(270,columnWidth-165);
    legendWidth = 145;
    legendGap = 20;
    networkLeft = rightCenter - (networkWidth+legendGap+legendWidth)/2;
    ax = axes(canvas.Parent,'Units','normalized', ...
        'Position',[networkLeft/width (height-margin-406)/height networkWidth/width 270/height]);
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
        (height-margin-381)/height legendWidth/width 220/height]);
    if snapshot.step > 0
        title(networkLegend,sprintf('Move сохранённого\nсостояния'),'FontSize',7);
    end
    set(ax,'Position',[networkLeft/width (height-margin-406)/height networkWidth/width 270/height], ...
        'XLim',[-0.3 Net.H.Nx+0.3],'YLim',[-1.3 Net.H.Ny+0.3]);
    drawTable(canvas,Net.P,'Net.P - давление в узлах, Па', ...
        margin,margin+156,columnWidth,'%.6g');
    fields = {'Q','Dir','Sat','State','Regime'};
    captions = {'расход, м³/с','направление','доля второй фазы, безразм.', ...
        'состояние','режим'};
    fieldsY = max(margin+446,margin+156+tableHeight+30);
    for j=1:numel(fields)
        y = fieldsY+(j-1)*tableHeight;
        for side=1:2
            orientation = 'HV'; key = orientation(side);
            titleText = sprintf('Net.%s.%s - %s',key,fields{j},captions{j});
            if ismember(fields{j},{'Q','Sat'}), format = '%.6g'; else, format = '%d'; end
            drawTable(canvas,Net.(key).(fields{j}),titleText, ...
                margin+(side-1)*(columnWidth+30),y,columnWidth,format);
        end
    end
    moveY = fieldsY + 5*tableHeight + 5;
    line(canvas,[margin width-margin],[moveY moveY],'Color',[.35 .4 .45],'LineWidth',0.8);
    label(canvas,margin,moveY+22,'Move сохранённого состояния (как на рисунке)',10,true);
    drawTable(canvas,Net.H.Move,'Net.H.Move', ...
        margin,moveY+38,columnWidth,'%d');
    drawTable(canvas,Net.V.Move,'Net.V.Move', ...
        margin+columnWidth+30,moveY+38,columnWidth,'%d');
    [marginH,marginV] = movePressureMargin(Net);
    marginY = moveY + tableHeight + 38;
    label(canvas,margin,marginY+22, ...
        ['Ориентированный перепад минус ' pressureName ' (положение относительно границы режимов), Па'], ...
        10,true);
    drawTable(canvas,marginH,['Net.H: Δp − ' pressureName ', Па'], ...
        margin,marginY+38,columnWidth,'%.6g');
    drawTable(canvas,marginV,['Net.V: Δp − ' pressureName ', Па'], ...
        margin+columnWidth+30,marginY+38,columnWidth,'%.6g');
    label(canvas,margin,height-margin-12,sprintf('Страница %d | Индексы строк и столбцов соответствуют MATLAB.', ...
        pageNumber),9,false);
    exportPage(fig,temporaryPdf,width,height,true);
    stepPages(frameIndex,:) = [snapshot.step firstPage pageNumber];
end
movefile(temporaryPdf,pdfPath,'f');
result.pdf = pdfPath;
result.reportStride = stride;
result.reportSteps = renderedSteps;
result.reportStepPages = stepPages;
result.reportPageCount = pageNumber;
save(fullfile(directory,'summary.mat'),'result','-append');
end

function pageNumber = drawGifPage(fig,Net,snapshot,frameIndex,frameCount,pressureRange,showMeniscus,width,height,margin,pageNumber,pdfPath)
layout = frameLayout(Net,width,margin);
currentWidth = layout.pictureWidth;
picturePage = pageNumber;
canvas = page(fig,currentWidth,height);
label(canvas,margin,margin+18,sprintf('Шаг %d | Кадр %d',snapshot.step,frameIndex),20,true);
label(canvas,margin,margin+48,sprintf('dt выполненного шага = %.12g с     t = %.12g с', ...
    snapshot.dtUsed,snapshot.elapsedTime),11,true);
label(canvas,margin,margin+74,sprintf('Нефтенасыщенность %.2f %%', ...
    100*networkOilSaturation(Net)),11,true);
cellWidth = layout.cellWidth;
% Three vertically separated tables avoid selecting a neighbouring table.
matrices = {Net.P,Net.H.Q,Net.V.Q};
titles = {'Net.P - давление в узлах, Па', ...
    'Net.H.Q - горизонтальные расходы, м³/с', ...
    'Net.V.Q - вертикальные расходы, м³/с'};
halfHeight = layout.imageHeight;
imageTop = layout.imageTop;
region = [margin/currentWidth (height-imageTop-halfHeight)/height ...
    (currentWidth-2*margin)/currentWidth halfHeight/height; ...
    margin/currentWidth (height-imageTop-2*halfHeight)/height ...
    (currentWidth-2*margin)/currentWidth halfHeight/height];
artwork = drawSaturationPressureFrame(canvas.Parent,Net,snapshot,frameIndex,frameCount, ...
    pressureRange,showMeniscus,[],region,.75*[currentWidth height]);
% Page header already supplies step/time; remove the duplicated GIF heading.
artwork.heading.String = '';
bottomLimit = height-margin-32;
continuationTop = margin+70;
tableY = continuationTop;
% The first sheet of every step contains artwork only.
canvas = nextTablePage();
for index = 1:3
    A = matrices{index};
    firstRow = 1;
    % Move a whole table when it fits on an empty continuation page.
    fullHeight = 17+(size(A,1)+1)*20;
    if tableY+fullHeight > bottomLimit && continuationTop+fullHeight <= bottomLimit
        canvas = nextTablePage();
    end
    while firstRow <= size(A,1)
        capacity = floor((bottomLimit-tableY-17)/20)-1;
        if capacity < 1
            canvas = nextTablePage();
            capacity = floor((bottomLimit-tableY-17)/20)-1;
        end
        lastRow = min(size(A,1),firstRow+capacity-1);
        caption = titles{index};
        if firstRow > 1 || lastRow < size(A,1)
            caption = sprintf('%s | строки %d-%d',caption,firstRow,lastRow);
        end
        drawTable(canvas,A(firstRow:lastRow,:),caption,margin,tableY, ...
            (size(A,2)+1)*cellWidth,'%.6g',firstRow-1);
        tableY = tableY+17+(lastRow-firstRow+2)*20+20;
        firstRow = lastRow+1;
    end
end
finishPage();

    function nextCanvas = nextTablePage()
        finishPage();
        pageNumber = pageNumber+1;
        currentWidth = width;
        nextCanvas = page(fig,width,height);
        if pageNumber == picturePage+1, heading = 'Таблицы';
        else, heading = 'Продолжение таблиц'; end
        label(nextCanvas,margin,margin+18,sprintf('Шаг %d | %s',snapshot.step,heading),12,true);
        label(nextCanvas,margin,margin+46,sprintf('t = %.12g с',snapshot.elapsedTime),11,false);
        tableY = continuationTop;
    end

    function finishPage()
        label(canvas,margin,height-margin-12,sprintf('Страница %d | Шаг %d | Индексы MATLAB.', ...
            pageNumber,snapshot.step),11,false);
        exportPage(fig,pdfPath,currentWidth,height,true);
    end
end

function layout = frameLayout(Net,width,margin)
% Fixed sheet height; oversized tables continue on a new sheet of this step.
pageHeight = 297/25.4*96;
pictureWidth = 210/25.4*96;
tableBlocks = 17+([Net.H.Ny Net.H.Ny Net.V.Ny]+1)*20+20;
imageTop = margin+84;
imageHeight = (pageHeight-imageTop-margin-32)/2;
layout = struct('cellWidth',80,'pictureWidth',pictureWidth,'imageHeight',imageHeight, ...
    'imageTop',imageTop,'tableBlocks',tableBlocks,'pageHeight',pageHeight);
end

function deleteTemporaryPdf(file)
if isfile(file), delete(file); end
end

function exportPage(fig,pdfPath,width,height,append)
% Explicit physical dimensions preserve the configured 20 mm margins.
% Reapply layout size after graphics callbacks and ignore screen/DPI defaults.
drawnow;
set(fig,'Units','pixels','Position',[10 10 width height]);
exportgraphics(fig,pdfPath,'ContentType','vector','Append',append, ...
    'Units','points','Width',0.75*width,'Height',0.75*height, ...
    'Padding',0,'PreserveAspectRatio','off');
end

function ax = page(fig,width,height)
clf(fig);
set(fig,'Units','pixels','Position',[10 10 width height]);
ax = axes(fig,'Units','normalized','Position',[0 0 1 1], ...
    'XLim',[0 width],'YLim',[0 height],'YDir','reverse','Visible','off');
hold(ax,'on');
ax.Toolbar.Visible = 'off';
rectangle(ax,'Position',[0 0 width height],'FaceColor','w','EdgeColor','none');
end

function bottom = label(ax,x,y,value,fontSize,bold)
fontSize = min(12,max(11,fontSize));
weight = 'normal';
if bold, weight = 'bold'; end
h = text(ax,x,y,value,'FontName','Arial','FontSize',fontSize, ...
    'FontWeight',weight,'Interpreter','none','VerticalAlignment','middle');
% Wrap captions at a readable font size instead of shrinking them.
available = diff(ax.XLim)-20/25.4*96-x;
if h.Extent(3) > available
    % Long error messages also stay inside the printable area.
    words = regexp(char(value),'\s+','split');
    wrapped = {}; current = '';
    for index = 1:numel(words)
        candidate = strtrim([current ' ' words{index}]);
        h.String = candidate;
        if h.Extent(3) > available && ~isempty(current)
            wrapped{end+1} = current; %#ok<AGROW>
            current = words{index};
        else
            current = candidate;
        end
        h.String = current;
        while h.Extent(3) > available
            count = max(1,floor(numel(current)*available/h.Extent(3))-1);
            wrapped{end+1} = current(1:count); %#ok<AGROW>
            current = current(count+1:end);
            h.String = current;
        end
    end
    wrapped{end+1} = current;
    h.String = wrapped;
    h.VerticalAlignment = 'top';
end
extent = h.Extent;
bottom = extent(2)+extent(4);
end

function drawTable(ax,A,titleText,x,y,width,format,rowOffset)
if nargin < 8, rowOffset = 0; end
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
        elseif c==0, value=sprintf('%d',r+rowOffset);
        elseif isnan(A(r,c)), value='—';
        else, value=sprintf(format,A(r,c)); end
        text(ax,x+(c+.5)*cellWidth,top+(r+.5)*rowHeight,value, ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName','Arial','FontSize',10,'Interpreter','none','Tag','reportTableCell');
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
