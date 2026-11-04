function result = writeBriefAnalysisReport(sourceDirectory,distribution)
%WRITEBRIEFANALYSISREPORT Self-contained HTML with animated GIFs and tables.
%   RESULT = WRITEBRIEFANALYSISREPORT(SOURCE) creates analysis/brief_report.html.
%   Mu/sigma describe ln(area in m^2), taken from sigma_*_mu_* in the path.
%   For another folder, a dialog asks for the known distribution parameters.
%   RESULT = WRITEBRIEFANALYSISREPORT(SOURCE,DISTRIBUTION) accepts a scalar
%   struct with mu and sigma to avoid the dialog. No parameters are estimated.
%   Both GIFs use all saved states at 0.5 s/frame. A4 sheets use 12 pt text,
%   10 pt table numbers, 20 mm margins and numbered captions. Old reports are read
%   only; intermediate front/cluster outputs are removed after embedding.

if nargin<2, distribution=struct(); end
analysisRoot=fileparts(mfilename('fullpath'));
releaseRoot=fileparts(fileparts(analysisRoot));
previousPath=path;
pathCleanup=onCleanup(@() path(previousPath));
addpath(analysisRoot,fullfile(releaseRoot,'reporting'), ...
    fullfile(releaseRoot,'visualization'), ...
    fullfile(releaseRoot,'analysis','residual_saturation_analysis'),'-begin');
data=load(fullfile(sourceDirectory,'summary.mat'),'result','parameters');
Net=data.parameters; runResult=data.result;
distribution=distributionParameters(sourceDirectory,distribution);
result=[];
if isempty(distribution), return; end
outputDirectory=fullfile(sourceDirectory,'analysis');
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
[~,attributes]=fileattrib(outputDirectory);
outputDirectory=attributes.Name;
temporaryDirectory=[tempname(outputDirectory) '_brief'];
mkdir(temporaryDirectory);
fileCleanup=onCleanup(@() removeStaging(temporaryDirectory,outputDirectory));

options=struct('createGif',false,'createPdf',false,'analyzeClusters',true);
result=analyzeMeniscusFront(sourceDirectory,temporaryDirectory,0.5,options);
result.gifPath=fullfile(temporaryDirectory,'brief_front.gif');
writeFrontAnimation(result,result.gifPath);
fprintf('Краткий отчёт: анимация сатурации и давления...\n');
satGif=fullfile(temporaryDirectory,'brief_saturation.gif');
writeSaturationGif(sourceDirectory,result.savedFiles,satGif);
networkPng=fullfile(temporaryDirectory,'network.png');
distributionPng=fullfile(temporaryDirectory,'distribution.png');
lastSaturationPng=fullfile(temporaryDirectory,'last_saturation.png');
writeNetworkPicture(Net,networkPng);
writeDistributionPicture(distribution,distributionPng);
writeLastSaturation(result.residualAnalysis,lastSaturationPng);

pages=struct('heading',{},'orientation',{},'content',{});
presentation=simulationReportPresentation(Net,runResult);
pages(end+1)=sheet('Результаты моделирования','portrait', ...
    titleContent(Net,runResult,presentation,distribution,networkPng,distributionPng));
pages(end+1)=sheet('Сатурация и давление','portrait saturation-page', ...
    picture(satGif,'gif','Сатурация и давление','animation')+ ...
    '<p class="caption">Рисунок 2. Сатурация и давление. Время кадра: 0,5 с.</p>');
pages(end+1)=sheet('Движение фронта вытеснения','portrait', ...
    '<p>Мениски State=1, Move≠2 и линейная интерполяция фронта. Время кадра: 0,5 с.</p>'+ ...
    picture(result.gifPath,'gif','Движение фронта','front-animation')+ ...
    '<p class="caption">Рисунок 3. Движение фронта в сохранённых состояниях.</p>');
pages=appendHarmonics(pages,result);
pages=appendResidual(pages,result.residualAnalysis,lastSaturationPng);
html=htmlDocument(pages,runResult);
temporaryHtml=fullfile(temporaryDirectory,'brief_report.html');
writelines(html,temporaryHtml,'Encoding','UTF-8');
htmlPath=fullfile(outputDirectory,'brief_report.html');
[ok,message]=movefile(temporaryHtml,htmlPath,'f');
if ~ok, error('writeBriefAnalysisReport:WriteFailed','%s',message); end
result.outputDirectory=outputDirectory;
result.gifPath=''; result.pdfPath='';
result.briefReportPath=htmlPath;
result.briefReportPageCount=numel(pages);
result.briefReportPageCountIsMinimum=true;
result.distribution=distribution;
result.residualAnalysis.outputDirectory=outputDirectory;
fprintf('Краткий HTML-отчёт: %s\n',htmlPath);
end

function value=distributionParameters(source,value)
if ~all(isfield(value,{'mu','sigma'}))
    number='([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)';
    token=regexp(char(source),['(?:^|[\\/])sigma_' number '_mu_' number '(?:[\\/]|$)'], ...
        'tokens','once');
    if ~isempty(token)
        value=struct('mu',str2double(token{2}),'sigma',str2double(token{1}));
    else
        answer=inputdlg({'Заданное μ для ln(площади в м²):', ...
            'Заданное σ для ln(площади в м²):'}, ...
            'Параметры логнормальной сети',[1 55],{'',''});
        if isempty(answer), value=[]; return; end
        value=struct('mu',str2double(answer{1}),'sigma',str2double(answer{2}));
    end
end
validateattributes(value.mu,{'numeric'},{'scalar','real','finite'});
validateattributes(value.sigma,{'numeric'},{'scalar','real','finite','positive'});
end

function writeSaturationGif(source,files,target)
limits=[Inf -Inf];
for k=1:numel(files)
    state=loadSimulationStep(fullfile(source,files{k}));
    limits=[min(limits(1),min(state.solvedNet.P(:))), ...
        max(limits(2),max(state.solvedNet.P(:)))];
end
if limits(1)==limits(2), limits=limits+[-1 1]; end
pageSizeCm=[17 23.2];
fig=paperFigure(pageSizeCm);
cleanup=onCleanup(@() close(fig));
canvas=fig;
headingAxes=axes(canvas,'Position',[0 0 1 1],'Visible','off','XLim',[0 1],'YLim',[0 1]);
text(headingAxes,.5,.99,'Сатурация и давление','HorizontalAlignment','center', ...
    'VerticalAlignment','top','FontName','Arial','FontSize',16,'FontWeight','bold');
heading=text(headingAxes,.5,.955,'','HorizontalAlignment','center', ...
    'VerticalAlignment','top','FontName','Arial','FontSize',12,'Interpreter','none');
frame=[];
for k=1:numel(files)
    state=loadSimulationStep(fullfile(source,files{k}));
    regions=[0 .46 1 .46;0 0 1 .46];
    frame=drawSaturationPressureFrame(canvas,state.solvedNet,state,k,numel(files), ...
        limits,true,frame,regions,pageSizeCm/2.54*72);
    if k==1, enlargeFrameArtwork(frame,state.solvedNet,regions,pageSizeCm); end
    heading.String=frame.heading.String;
    set(findall(canvas,'Type','axes'),'FontSize',12);
    set(findall(canvas,'Type','legend'),'FontSize',12);
    set(findall(canvas,'Type','colorbar'),'FontSize',12);
    drawnow limitrate;
    rgb=print(fig,'-RGBImage','-r120');
    [indexed,palette]=rgb2ind(rgb,256,'nodither');
    if k==1
        imwrite(indexed,palette,target,'gif','LoopCount',Inf,'DelayTime',.5);
    else
        imwrite(indexed,palette,target,'gif','WriteMode','append','DelayTime',.5);
    end
    if k==1 || k==numel(files) || mod(k,50)==0
        fprintf('Краткий отчёт, сатурация: %d / %d кадров\n',k,numel(files));
    end
end
end

function enlargeFrameArtwork(frame,Net,regions,pageSizeCm)
% Use the main report's physical fit; let small meshes also fill their slot.
points=pageSizeCm/2.54*72;
layout=reportNetworkLayout(Net.H.Nx,Net.H.Ny,regions,points);
boxes=regions.*points([1 2 1 2]);
span=[Net.H.Nx+.6 Net.H.Ny+1.6];
pitch=min([min(boxes(:,3))-104 min(boxes(:,4))-62]./span);
factor=pitch/layout.cellPitchPoints;
positions=layout.axesPositions.*points([1 2 1 2]);
for k=1:2
    center=positions(k,1:2)+positions(k,3:4)/2;
    positions(k,3:4)=positions(k,3:4)*factor;
    positions(k,1:2)=center-positions(k,3:4)/2;
end
sat=ancestor(frame.water,'axes'); pressure=ancestor(frame.pressure,'axes');
set(sat,'Position',positions(1,:)./points([1 2 1 2]));
set(pressure,'Position',positions(2,:)./points([1 2 1 2]));
bar=findall(pressure.Parent,'Type','colorbar');
barPosition=[positions(2,1)+positions(2,3)+12 positions(2,2) 10 positions(2,4)];
set(bar,'Position',barPosition./points([1 2 1 2]));
set([frame.water frame.oil frame.closed],'LineWidth',min(3,.10*pitch));
frame.pressure.SizeData=min(14,.60*pitch)^2;
frame.menisci.MarkerSize=min(6,.22*pitch);
end

function writeFrontAnimation(result,target)
fig=paperFigure([17 19]);
cleanup=onCleanup(@() close(fig));
plotPosition=[.10 .13 .88 .79];
ax=axes(fig,'Position',plotPosition,'Color','white', ...
    'FontName','Arial','FontSize',12,'XColor','black','YColor','black');
hold(ax,'on');
curve=plot(ax,NaN,NaN,'--','Color',[0 .35 .75],'LineWidth',1.7);
points=plot(ax,NaN,NaN,'o','LineStyle','none','Color',[.8 .1 .05], ...
    'MarkerFaceColor',[1 .3 .15],'MarkerEdgeColor','white','MarkerSize',4.5);
axis(ax,'equal'); xlim(ax,[0 1]); ylim(ax,[0 1]); grid(ax,'on'); box(ax,'on');
xlabel(ax,'x / ширина сети','FontSize',12); ylabel(ax,'y / высота сети','FontSize',12);
legend(ax,[points curve],{'Мениски: State=1, Move≠2','Линейный фронт'}, ...
    'Location','southoutside','FontSize',12,'AutoUpdate','off');
set(ax,'PositionConstraint','innerposition','Position',plotPosition);
heading=title(ax,'','FontSize',12,'Interpreter','none');
emptyLabel=text(ax,.5,.5,'Нет выбранных менисков','HorizontalAlignment','center', ...
    'FontSize',12,'Visible','off');
for k=1:height(result.frames)
    menisci=result.mobileMenisci(result.mobileMenisci.Step==result.frames.Step(k),:);
    fit=result.frontFits{k};
    set(points,'XData',menisci.X,'YData',menisci.Y);
    if strcmp(fit.method,'linear')
        set(curve,'XData',fit.sampleX,'YData',fit.sampleY);
    else
        set(curve,'XData',NaN,'YData',NaN);
    end
    emptyLabel.Visible='off';
    if isempty(menisci), emptyLabel.Visible='on'; end
    heading.String={sprintf('Шаг %d | t = %.6g с | Кадр %d / %d', ...
        result.frames.Step(k),result.frames.Time(k),k,height(result.frames)), ...
        sprintf('Менисков: %d | %s',height(menisci),fit.method)};
    drawnow limitrate;
    rgb=print(fig,'-RGBImage','-r120');
    [indexed,palette]=rgb2ind(rgb,256,'nodither');
    if k==1
        imwrite(indexed,palette,target,'gif','LoopCount',Inf,'DelayTime',.5);
    else
        imwrite(indexed,palette,target,'gif','WriteMode','append','DelayTime',.5);
    end
end
end

function writeNetworkPicture(Net,target)
% Same lattice as run/plotNetwork; physical stroke/node sizes prevent merging.
nRows=size(Net.H.A,1); nCols=size(Net.V.A,2);
sizeCm=[9.1 7.3];
fig=paperFigure(sizeCm);
cleanup=onCleanup(@() close(fig));
position=[.16 .20 .81 .73];
ax=axes(fig,'Position',position,'FontSize',12,'Color','white', ...
    'XColor','black','YColor','black');
pitch=min((sizeCm/2.54*72).*position(3:4)./[nCols+2.4 nRows+2.4]);
stroke=max(.12,min(.8,.12*pitch));
nodeSize=max(.2,min(2.4,.35*pitch));
hold(ax,'on');
plot(ax,[zeros(1,nRows);(nCols+1)*ones(1,nRows)], ...
    repmat(0:nRows-1,2,1),'Color','black','LineWidth',stroke);
plot(ax,repmat(1:nCols,2,1),[-ones(1,nCols);nRows*ones(1,nCols)], ...
    'Color','black','LineWidth',stroke);
[x,y]=meshgrid(0:nCols,0:nRows-1);
plot(ax,x(:),y(:),'o','LineStyle','none','MarkerSize',nodeSize, ...
    'MarkerFaceColor','black','MarkerEdgeColor','none');
plot(ax,zeros(1,nRows),0:nRows-1,'o','LineStyle','none', ...
    'MarkerSize',max(.5,min(5,.8*pitch)), ...
    'MarkerFaceColor','red','MarkerEdgeColor','none');
axis(ax,'equal'); box(ax,'on');
xlim(ax,[-.7 nCols+1.7]); ylim(ax,[-1.7 nRows+.7]);
title(ax,sprintf('Сеть %d × %d',nRows,nCols), ...
    'FontSize',12,'Color','black');
xlabel(ax,'Столбцы','FontSize',12,'Color','black');
ylabel(ax,'Строки','FontSize',12,'Color','black');
print(fig,target,'-dpng','-r240');
end

function writeDistributionPicture(parameters,target)
bounds=pi*([.1e-3 1e-3]/2).^2;
A=logspace(log10(bounds(1)),log10(bounds(2)),4001);
z=(log(bounds)-parameters.mu)/parameters.sigma;
mass=.5*diff(erf(z/sqrt(2)));
if ~isfinite(mass) || mass<=0
    error('writeBriefAnalysisReport:DistributionRange', ...
        'Указанные μ и σ не дают численно разрешимой вероятности в диапазоне площадей.');
end
density=exp(-.5*((log(A)-parameters.mu)/parameters.sigma).^2) ./ ...
    (A*parameters.sigma*sqrt(2*pi)*mass);
fig=paperFigure([8.2 7.3]);
cleanup=onCleanup(@() close(fig));
ax=axes(fig,'FontSize',12,'Color','white','XColor','black','YColor','black', ...
    'Position',[.24 .23 .70 .63]);
plot(ax,[0 bounds(1) A bounds(2) bounds(2)*1.025]/1e-7, ...
    [0 0 density 0 0]*1e-7,'LineWidth',1.6);
ax.FontSize=12;
title(ax,'Распределение площадей','FontSize',12,'Color','black');
xlabel(ax,'A, ×10^{-7} м²','FontSize',12,'Color','black');
ylabel(ax,'Плотность','FontSize',12,'Color','black');
xlim(ax,[0 bounds(2)*1.025/1e-7]); ylim(ax,[0 max(density)*1.08e-7]);
grid(ax,'on');
print(fig,target,'-dpng','-r180');
end

function writeLastSaturation(residual,target)
state=loadSimulationStep(residual.snapshotPath);
Net=state.solvedNet;
sizeCm=[17 16.5];
fig=paperFigure(sizeCm);
cleanup=onCleanup(@() close(fig));
limits=[min(Net.P(:)) max(Net.P(:))];
if limits(1)==limits(2), limits=limits+[-1 1]; end
frame=drawSaturationPressureFrame(fig,Net,state,1,1,limits,false,[],[0 0 1 1]);
sat=ancestor(frame.water,'axes');
delete(findall(fig,'Type','colorbar'));
delete(ancestor(frame.pressure,'axes'));
frame.menisci.Visible='off';
position=[.08 .10 .90 .86];
set(sat,'Units','normalized','Position',position,'FontSize',12);
pitch=min((sizeCm/2.54*72).*position(3:4)./[Net.H.Nx+.6 Net.H.Ny+1.6]);
set([frame.water frame.oil frame.closed],'LineWidth',min(2.5,.12*pitch));
title(sat,sprintf('Сатурация: шаг %d, t = %.6g с',residual.step,residual.elapsedTime), ...
    'FontSize',12,'Color','black');
legendHandle=legend(sat); legendHandle.FontSize=12;
print(fig,target,'-dpng','-r180');
end

function fig=paperFigure(sizeCm)
fig=figure('Visible','off','Color','white','Units','centimeters', ...
    'Position',[1 1 sizeCm],'PaperUnits','centimeters','PaperSize',sizeCm, ...
    'PaperPosition',[0 0 sizeCm],'PaperPositionMode','manual','InvertHardcopy','off');
end

function content=titleContent(Net,run,presentation,distribution,network,curve)
lines={['Дата начала: ' run.startedAt]; ...
    sprintf('Общее модельное время (сумма dt): %.12g с',run.totalTime); ...
    sprintf('Выполнено шагов: %d',run.steps);run.status};
if isfield(run,'totalComputeTime')
    compute=sprintf('Общее время вычислений: %.6g с',run.totalComputeTime);
    if isfield(run,'failedComputeTime') && run.failedComputeTime>0
        compute=sprintf('%s; незавершённый расчёт: %.6g с',compute,run.failedComputeTime);
    end
    lines{end+1,1}=compute;
end
lines=[lines;presentation.boundaryLines;{ ...
    sprintf('Вязкость вытесняемой фазы (%s), Net.mu1: %.12g Па·с', ...
        presentation.phases.displacedName,Net.mu1); ...
    sprintf('Вязкость вытесняющей фазы (%s), Net.mu2: %.12g Па·с', ...
        presentation.phases.displacingName,Net.mu2); ...
    sprintf('Длина капилляра, Net.L: %.12g м',Net.L); ...
    sprintf('Поверхностное натяжение, Net.sigma: %.12g Н/м',Net.sigma); ...
    sprintf('Угол смачивания, Net.theta: %.12g рад',Net.theta)}; ...
    presentation.modelLines];
content="<div class=""parameters"">";
for k=1:numel(lines), content=content+"<p>"+escape(lines{k})+"</p>"; end
content=content+"</div><p class=""distribution-meta""><b>"+ ...
    escape(sprintf('Размер сети: %d × %d. μ = %.9g; σ = %.9g.', ...
    size(Net.H.A,1),size(Net.V.A,2),distribution.mu,distribution.sigma))+ ...
    '</b></p><p>Площади взяты из логнормального распределения; μ и σ относятся к ln(A в м²). Диаметры ограничены 0,1–1 мм.</p>'+ ...
    '<div class="formula" role="math" aria-label="Плотность логнормального распределения">'+ ...
    '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block"><mrow>'+ ...
    '<mi>f</mi><mo stretchy="false">(</mo><mi>A</mi><mo stretchy="false">)</mo><mo>=</mo>'+ ...
    '<mfrac><mn>1</mn><mrow><mi>A</mi><mi>σ</mi><msqrt><mrow><mn>2</mn><mi>π</mi></mrow></msqrt></mrow></mfrac>'+ ...
    '<mi>exp</mi><mo>(</mo><mo>−</mo><mfrac><msup><mrow><mo>(</mo><mi>ln</mi><mi>A</mi><mo>−</mo><mi>μ</mi><mo>)</mo></mrow><mn>2</mn></msup>'+ ...
    '<mrow><mn>2</mn><msup><mi>σ</mi><mn>2</mn></msup></mrow></mfrac><mo>)</mo></mrow></math></div>'+ ...
    '<p>В допустимом диапазоне плотность нормирована: f<sub>усеч.</sub>(A) = f(A) / [F(A<sub>max</sub>) − F(A<sub>min</sub>)].</p>'+ ...
    '<div class="title-pictures"><figure>'+picture(network,'png','Схема сети','')+ ...
    '<figcaption>Рисунок 1а. Схема сети.</figcaption></figure><figure>'+ ...
    picture(curve,'png','Логнормальное распределение площадей','')+ ...
    '<figcaption>Рисунок 1б. Плотность площадей.</figcaption></figure></div>';
end

function pages=appendHarmonics(pages,result)
tables={result.harmonicCosTable,result.harmonicSinTable};
labels={'Косинусные коэффициенты a₁–a₁₀','Синусные коэффициенты b₁–b₁₀'};
count=height(tables{1});
chunks=max(1,ceil(2*count/12));
for chunk=1:chunks
    virtualRows=(chunk-1)*12+1:min(chunk*12,2*count);
    content="<p>x(y) = a₀ + Σ[aₙ cos(2πnu) + bₙ sin(2πnu)]. Время — с; коэффициенты — доли ширины сети. Исключены t=0 и неопределённые значения.</p>";
    for kind=1:2
        T=tables{kind};
        indices=virtualRows-(kind-1)*count;
        indices=indices(indices>=1 & indices<=count);
        if isempty(indices) && count>0, continue; end
        times=seconds(T.Time);
        headers=[{'Время, с'} T.Properties.VariableNames];
        values=[times(indices) T{indices,:}];
        content=content+numericTable(headers,values,'%.7g','harmonics',labels{kind});
    end
    pages(end+1)=sheet(sprintf('Коэффициенты 10 гармоник — лист %d из %d',chunk,chunks), ...
        'landscape',content); %#ok<AGROW>
end
end

function pages=appendResidual(pages,residual,lastPicture)
T=residual.distribution;
T=T(T.ClusterCount>0,:);
headers={'Каналов','Кластеров','H','V','Изол.'};
intro=escape(sprintf('Последний снимок: шаг %d; t = %.9g с. Остаточная насыщенность: %.6g %%.', ...
    residual.step,residual.elapsedTime,100*residual.displacedSaturation));
summary="<p>"+intro+"</p><p>"+escape(sprintf( ...
    'Кластеров: %d; каналов: %d; объём остатков: %.9g м³.', ...
    height(residual.clusters),height(residual.channels),residual.displacedVolume))+ ...
    "</p><p>"+escape(sprintf('Исключено по правой границе: %d кластеров, %d каналов.', ...
    residual.excludedRightConnectedClusterCount,residual.excludedRightConnectedChannelCount))+"</p>";
content='<div class="residual-summary">'+summary+ ...
    numericTable(headers,T{:,:},'%d','residual')+ ...
    '<p>H/V — суммы каналов. Изол. — кластеры без пути к выходу.</p></div>'+ ...
    '<figure class="residual-picture">'+ ...
    picture(lastPicture,'png','Сатурация последнего снимка без менисков','last-saturation')+ ...
    '<figcaption class="caption">Рисунок 4. Сатурация последнего сохранённого состояния. Мениски не отображаются.</figcaption></figure>';
pages(end+1)=sheet('Остаточная насыщенность — итог','portrait residual-final',content);
end

function html=numericTable(headers,values,format,style,caption)
if nargin<5, caption=''; end
html="<table class="""+style+""">";
if ~isempty(caption), html=html+"<caption>"+escape(caption)+"</caption>"; end
html=html+"<thead><tr>";
for k=1:numel(headers), html=html+"<th scope=""col"">"+escape(headers{k})+"</th>"; end
html=html+"</tr></thead><tbody>";
if isempty(values)
    html=html+"<tr><td colspan="""+numel(headers)+""">Нет подходящих строк.</td></tr>";
else
    for row=1:size(values,1)
        html=html+"<tr>";
        for column=1:size(values,2)
            if strcmp(style,'harmonics') && column>1 && isfinite(values(row,column))
                % Seven significant digits, with a compact exponent. This
                % avoids long leading-zero decimals and split final digits.
                textValue=sprintf('%.6e',values(row,column));
                textValue=strrep(textValue,'e+','e');
                textValue=regexprep(textValue,'e(-?)0*(\d+)$','e$1$2');
                if values(row,column)==0, textValue='0'; end
            else
                textValue=sprintf(format,values(row,column));
            end
            html=html+"<td>"+escape(textValue)+"</td>";
        end
        html=html+"</tr>";
    end
end
html=html+"</tbody></table>";
end

function value=picture(file,type,alternative,style)
fid=fopen(file,'rb');
if fid<0, error('writeBriefAnalysisReport:Image','Не удалось открыть %s.',file); end
cleanup=onCleanup(@() fclose(fid));
bytes=fread(fid,Inf,'*uint8');
encoded=matlab.net.base64encode(bytes);
value="<img class="""+style+""" alt="""+escape(alternative)+ ...
    """ src=""data:image/"+type+";base64,"+string(encoded)+""">";
end

function value=sheet(heading,orientation,content)
value=struct('heading',heading,'orientation',orientation,'content',content);
end

function html=htmlDocument(pages,run)
css="html{font-size:12pt}*{box-sizing:border-box}body{margin:0;background:#e8e8e8;color:#111;font-family:Arial,sans-serif;font-size:12pt;line-height:1.28}"+ ...
    ".sheet{width:210mm;min-height:297mm;margin:8mm auto;padding:20mm;background:white;display:flex;flex-direction:column;break-after:page}"+ ...
    ".sheet.landscape{width:297mm;min-height:210mm}.page-body{flex:1}h1{font-size:20pt;margin:0 0 4mm}h2{font-size:13pt;margin:4mm 0 2mm}.saturation-page h1{display:none}"+ ...
    "p{margin:0 0 2mm}.residual-summary>p{margin-bottom:1mm}.residual-summary table,.residual-picture{break-inside:avoid}.parameters{line-height:1.16}.parameters p{margin:0 0 .3mm}.distribution-meta{margin-top:3mm}.formula{margin:3mm 0;font-size:14pt}"+ ...
    ".title-pictures{display:grid;grid-template-columns:1.1fr .9fr;gap:5mm;margin-top:3mm}figure{margin:0;min-width:0}img{display:block;max-width:100%;height:auto;margin:auto}"+ ...
    "figcaption,.caption{font-size:12pt;margin-top:2mm}.animation,.front-animation,.last-saturation{width:100%}.last-saturation{margin-top:2mm}"+ ...
    "table{width:100%;border-collapse:collapse;font-size:12pt;margin:2mm 0 4mm;font-variant-numeric:tabular-nums}td{font-size:10pt}th,td{border:0.2mm solid #aaa;padding:.8mm 1.4mm;text-align:right;white-space:nowrap}"+ ...
    "th{background:#f1f1f1;font-weight:bold}thead{display:table-header-group}tr{break-inside:avoid}.harmonics{table-layout:fixed;margin:1mm 0 2mm}.harmonics th:first-child{width:9%}"+ ...
    ".harmonics caption{text-align:left;font-size:12pt;font-weight:bold;padding-bottom:1mm}.harmonics th{padding:.8mm .1mm}.harmonics td{padding:.55mm 0;line-height:1.1;white-space:nowrap}"+ ...
    ".page-footer{border-top:.2mm solid #bbb;margin-top:5mm;padding-top:2mm;font-size:12pt;display:flex;justify-content:space-between;gap:5mm}.page-footer span:last-child{white-space:nowrap}"+ ...
    "@page portrait{size:A4 portrait;margin:0}@page landscape{size:A4 landscape;margin:0}.portrait{page:portrait}.landscape{page:landscape}"+ ...
    "@media print{body{background:white}.sheet{margin:0;box-shadow:none}.sheet:last-child{break-after:auto}}";
html="<!doctype html><html lang=""ru""><head><meta charset=""UTF-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1""><title>Краткий отчёт моделирования</title><style>"+css+"</style></head><body>";
for k=1:numel(pages)
    html=html+"<section class=""sheet "+pages(k).orientation+""" data-page="""+k+""">"+ ...
        "<main class=""page-body""><h1>"+escape(pages(k).heading)+"</h1>"+pages(k).content+ ...
        "</main><footer class=""page-footer""><span>"+escape(pages(k).heading)+ ...
        "</span><span>Страница "+k+" из "+numel(pages)+"</span></footer></section>";
end
html=html+residualFitScript()+"<!-- Source run started: "+escape(run.startedAt)+" --></body></html>";
end

function script=residualFitScript()
% Browser measurement preserves 12 pt text and the whole table; only the
% picture may shrink, proportionally, to at least 80 percent of its width.
script=strjoin([ ...
    "<script>"; ...
    "(() => {"; ...
    "  function numberPages() {"; ...
    "    const pages = [...document.querySelectorAll('.sheet')];"; ...
    "    pages.forEach((page, i) => { page.dataset.page = i + 1; page.querySelector('.page-footer span:last-child').textContent = 'Страница ' + (i + 1) + ' из ' + pages.length; });"; ...
    "    document.body.dataset.pageCount = pages.length;"; ...
    "  }"; ...
    "  function fitResidual() {"; ...
    "    const page = document.querySelector('.residual-final');"; ...
    "    if (!page) return;"; ...
    "    if (document.querySelector('.residual-figure-page')) { numberPages(); return; }"; ...
    "    const figure = page.querySelector('.residual-picture');"; ...
    "    const image = figure.querySelector('img');"; ...
    "    if (!image.complete || !image.naturalHeight) return;"; ...
    "    image.style.width = '100%';"; ...
    "    const fullHeight = image.getBoundingClientRect().height;"; ...
    "    const maximum = parseFloat(getComputedStyle(page).minHeight);"; ...
    "    const extra = Math.max(0, page.getBoundingClientRect().height - maximum);"; ...
    "    const scale = Math.min(1, (fullHeight - extra - (extra > 1 ? 2 : 0)) / fullHeight);"; ...
    "    if (scale >= 0.8) {"; ...
    "      image.style.width = (scale * 100) + '%';"; ...
    "      figure.dataset.scale = scale.toFixed(6);"; ...
    "      page.dataset.residualLayout = 'combined';"; ...
    "    } else {"; ...
    "      const next = document.createElement('section');"; ...
    "      next.className = 'sheet portrait residual-figure-page';"; ...
    "      const main = document.createElement('main'); main.className = 'page-body';"; ...
    "      const heading = document.createElement('h1'); heading.textContent = 'Сатурация последнего состояния';"; ...
    "      main.append(heading, figure); next.append(main);"; ...
    "      const footer = page.querySelector('.page-footer').cloneNode(true);"; ...
    "      footer.querySelector('span').textContent = heading.textContent; next.append(footer);"; ...
    "      page.after(next); figure.dataset.scale = '1'; page.dataset.residualLayout = 'separate';"; ...
    "    }"; ...
    "    numberPages();"; ...
    "  }"; ...
    "  window.fitBriefResidualPage = fitResidual;"; ...
    "  window.addEventListener('load', fitResidual, {once: true});"; ...
    "  window.addEventListener('beforeprint', fitResidual);"; ...
    "  if (document.fonts) document.fonts.ready.then(fitResidual);"; ...
    "  if (document.readyState === 'complete') fitResidual();"; ...
    "})();"; ...
    "</script>"],newline);
end

function text=escape(value)
text=string(value);
text=replace(text,["&","<",">","""","'"], ...
    ["&amp;","&lt;","&gt;","&quot;","&#39;"]);
end

function removeStaging(folder,parent)
[actual,name]=fileparts(folder);
if strcmpi(actual,parent) && endsWith(name,'_brief') && isfolder(folder)
    [ok,message]=rmdir(folder,'s');
    if ~ok, warning('writeBriefAnalysisReport:Cleanup','%s',message); end
end
end
