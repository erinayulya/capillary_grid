function frontAnalysis = analyzeMeniscusFront(sourceDirectory,outputDirectory,frameDelay,options)
%ANALYZEMENISCUSFRONT Tables, linear/Fourier fronts and optional GIF/PDF.
% With no arguments, selects the newest run_TIMESTAMP[_N] containing steps
% in this release's results/. A stopped run is also a performed calculation.
% Writes all_menisci.csv, mobile_menisci.csv, front_analysis.mat and
% mobile_front.gif/mobile_front.pdf into sourceDirectory/analysis by default.
% Each saved step contributes a frame; missing/unsaved steps are not invented.
% sourceDirectory optionally selects a different run. frameDelay is constant
% seconds/frame (default 0.1); actual model time is displayed in every frame.
% options.createGif/createPdf independently select outputs (both true).
% options.analyzeClusters (false): analyze the final snapshot, save tables
% beside front outputs, and append clusters to the common mobile_front.pdf.
% Tables, interpolants and ten Fourier harmonics per frame are always saved.
% PDF: nonempty states with t~=0, followed by copyable coefficient tables.
% Cosine/sine coefficient timetables and numeric CSV/TSV are always saved.
% Does not call setupProject, a solver, or alter Net/source snapshots/MAT path.
analysisDirectory = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(sourceDirectory)
    sourceDirectory = latestFrontAnalysisRun(fullfile(fileparts(fileparts(analysisDirectory)),'results'));
end
defaultOutput = nargin < 2 || isempty(outputDirectory);
if defaultOutput, outputDirectory = fullfile(sourceDirectory,'analysis'); end
if nargin < 3 || isempty(frameDelay), frameDelay = 0.1; end
if nargin < 4 || isempty(options), options = struct; end
if ~isstruct(options) || ~isscalar(options)
    error('analyzeMeniscusFront:Options','options должен быть скалярной структурой.');
end
if ~isfield(options,'createGif'), options.createGif = true; end
if ~isfield(options,'createPdf'), options.createPdf = true; end
if ~isfield(options,'analyzeClusters'), options.analyzeClusters = false; end
validateattributes(options.createGif,{'logical','numeric'},{'scalar','binary'});
validateattributes(options.createPdf,{'logical','numeric'},{'scalar','binary'});
validateattributes(options.analyzeClusters,{'logical','numeric'},{'scalar','binary'});
sourceDirectory = char(sourceDirectory);
outputDirectory = char(outputDirectory);
if ~isfolder(sourceDirectory) || (~defaultOutput && ~isfolder(outputDirectory))
    error('analyzeMeniscusFront:Directory','Исходная и явно заданная выходная папки должны существовать.');
end
[~,sourceAttributes] = fileattrib(sourceDirectory);
sourceDirectory = sourceAttributes.Name;
validateattributes(frameDelay,{'numeric'},{'scalar','real','finite','>=',0.01,'<=',655});
files = stepFiles(sourceDirectory);
if isempty(files), error('analyzeMeniscusFront:NoSteps','Нет сохранённых step_*.mat.'); end
nFrames = numel(files);
allParts = cell(nFrames,1);
mobileParts = cell(nFrames,1);
frontFits = cell(nFrames,1);
fourierFits = cell(nFrames,1);
steps = zeros(nFrames,1);
times = zeros(nFrames,1);
allCounts = zeros(nFrames,1);
mobileCounts = zeros(nFrames,1);
for k = 1:nFrames
    filename = fullfile(sourceDirectory,files(k).name);
    snapshot = load(filename,'solvedNet','Net','step','elapsedTime');
    if isfield(snapshot,'solvedNet')
        savedNet = snapshot.solvedNet;
    elseif isfield(snapshot,'Net')
        savedNet = snapshot.Net;
    else
        error('analyzeMeniscusFront:Snapshot','Нет Net/solvedNet: %s',filename);
    end
    if ~all(isfield(snapshot,{'step','elapsedTime'}))
        error('analyzeMeniscusFront:Snapshot','Нет step/elapsedTime: %s',filename);
    end
    expectedStep = sscanf(files(k).name,'step_%d.mat');
    if ~isequal(snapshot.step,expectedStep)
        error('analyzeMeniscusFront:Step','Номер шага не совпадает с именем: %s',filename);
    end
    [allParts{k},mobileParts{k},currentGeometry] = ...
        meniscusCoordinates(savedNet,snapshot.step,snapshot.elapsedTime);
    if k == 1
        geometry = currentGeometry;
    elseif ~isequal(geometry,currentGeometry)
        error('analyzeMeniscusFront:GeometryChanged','Геометрия изменяется между снимками.');
    end
    steps(k) = snapshot.step;
    times(k) = snapshot.elapsedTime;
    allCounts(k) = height(allParts{k});
    mobileCounts(k) = height(mobileParts{k});
    frontFits{k} = interpolateMeniscusFront(mobileParts{k});
    fourierFits{k} = fourierMeniscusFront(frontFits{k});
end
if any(diff(times)<0)
    error('analyzeMeniscusFront:Time','Время сохранённых шагов убывает.');
end
if defaultOutput
    outputDirectory = fullfile(sourceDirectory,'analysis');
    if ~isfolder(outputDirectory)
        [ok,message] = mkdir(outputDirectory);
        if ~ok, error('analyzeMeniscusFront:Directory','%s',message); end
    end
end
[~,outputAttributes] = fileattrib(outputDirectory);
outputDirectory = outputAttributes.Name;
frontAnalysis = struct('sourceDirectory',sourceDirectory, ...
    'outputDirectory',outputDirectory,'geometry',geometry, ...
    'selection','State == 1 & Move ~= 2', ...
    'interpolation','x=f(y): linear interpolation of mean X at equal Y; no extrapolation', ...
    'frameDelay',frameDelay,'createGif',logical(options.createGif), ...
    'createPdf',logical(options.createPdf),'savedFiles',{ {files.name}' }, ...
    'allMenisci',vertcat(allParts{:}),'mobileMenisci',vertcat(mobileParts{:}), ...
    'frames',table(steps,times,allCounts,mobileCounts, ...
        'VariableNames',{'Step','Time','AllCount','MobileCount'}), ...
    'frontFits',{frontFits},'fourierFits',{fourierFits});
frontAnalysis.gifPath = '';
frontAnalysis.pdfPath = '';
frontAnalysis.pdfPageCount = 0;
frontAnalysis.analyzeClusters = logical(options.analyzeClusters);
frontAnalysis.residualAnalysis = [];
if options.analyzeClusters
    previousPath = path;
    clusterPathCleanup = onCleanup(@() path(previousPath));
    addpath(fullfile(fileparts(analysisDirectory),'residual_saturation_analysis'),'-begin');
    frontAnalysis.residualAnalysis = analyzeResidualSaturation(sourceDirectory,outputDirectory,false);
end
[frontAnalysis.harmonicTable,frontAnalysis.harmonicCosTable, ...
    frontAnalysis.harmonicSinTable] = coefficientTables(times,fourierFits);
if options.createGif, frontAnalysis.gifPath = fullfile(outputDirectory,'mobile_front.gif'); end
if options.createPdf, frontAnalysis.pdfPath = fullfile(outputDirectory,'mobile_front.pdf'); end
% Prepare all files before replacing previous analysis outputs.
temporaryBase = tempname(outputDirectory);
temporaryFiles = strcat(temporaryBase, ...
    {'.all.csv','.mobile.csv','.mat','.gif','.pdf','.harmonics.csv','.harmonics.tsv', ...
    '.sizes.csv','.clusters.csv','.composition.csv','.channels.csv','.residual.mat'});
temporaryCleanup = onCleanup(@() removeTemporary(temporaryFiles));
writetable(frontAnalysis.allMenisci,temporaryFiles{1});
writetable(frontAnalysis.mobileMenisci,temporaryFiles{2});
exportTable = array2table([seconds(frontAnalysis.harmonicTable.Time) frontAnalysis.harmonicTable{:,:}], ...
    'VariableNames',[{'Time_s'} frontAnalysis.harmonicTable.Properties.VariableNames]);
writetable(exportTable,temporaryFiles{6});
writetable(exportTable,temporaryFiles{7},'FileType','text','Delimiter','\t');
targets = {'all_menisci.csv','mobile_menisci.csv','front_analysis.mat', ...
    'mobile_front.gif','mobile_front.pdf','harmonic_coefficients.csv','harmonic_coefficients.tsv', ...
    'cluster_sizes.csv','clusters.csv','cluster_composition.csv','cluster_channels.csv', ...
    'residual_saturation.mat'};
enabled = [true true true logical(options.createGif) logical(options.createPdf) true true ...
    repmat(logical(options.analyzeClusters),1,5)];
if options.analyzeClusters
    writeResidualSaturationTables(frontAnalysis.residualAnalysis,temporaryFiles(8:12));
end
if enabled(4)
    writeFrontGif(frontAnalysis,mobileParts,temporaryFiles{4});
end
if enabled(5)
    frontAnalysis.pdfPageCount = writeFrontFourierPdf(frontAnalysis,mobileParts,temporaryFiles{5});
end
save(temporaryFiles{3},'frontAnalysis','-v7.3');
for k = find(enabled)
    [ok,message] = movefile(temporaryFiles{k},fullfile(outputDirectory,targets{k}),'f');
    if ~ok, error('analyzeMeniscusFront:WriteFailed','%s',message); end
end
fprintf('Источник: %s\nСохранённых состояний: %d\n',sourceDirectory,nFrames);
fprintf('Строк в таблицах: все %d; Move~=2 %d\n', ...
    height(frontAnalysis.allMenisci),height(frontAnalysis.mobileMenisci));
fprintf('Результаты: %s\n',outputDirectory);
end

function [combined,cosine,sine] = coefficientTables(times,fits)
% Duration row times also preserve snapshots with equal elapsedTime (R2023a).
count = 10;
a = NaN(numel(times),count); b = a;
for k = 1:numel(times)
    a(k,:) = fits{k}.a';
    b(k,:) = fits{k}.b';
end
% Summary tables exclude the initial state and any unavailable coefficients.
keep = times~=0 & isfinite(times) & all(isfinite([a b]),2);
times = times(keep); a = a(keep,:); b = b(keep,:);
namesA = arrayfun(@(n) sprintf('a%d',n),1:count,'UniformOutput',false);
namesB = arrayfun(@(n) sprintf('b%d',n),1:count,'UniformOutput',false);
rowTimes = seconds(times);
cosine = array2timetable(a,'RowTimes',rowTimes,'VariableNames',namesA);
sine = array2timetable(b,'RowTimes',rowTimes,'VariableNames',namesB);
values = zeros(numel(times),2*count);
values(:,1:2:end) = a; values(:,2:2:end) = b;
names = reshape([namesA;namesB],1,[]);
combined = array2timetable(values,'RowTimes',rowTimes,'VariableNames',names);
end

function files = stepFiles(folder)
files = dir(fullfile(folder,'step_*.mat'));
files = files(~[files.isdir]);
tokens = regexp({files.name},'^step_(\d+)\.mat$','tokens','once');
valid = ~cellfun('isempty',tokens);
files = files(valid); tokens = tokens(valid);
numbers = cellfun(@(token) str2double(token{1}),tokens);
[~,order] = sort(numbers);
files = files(order);
if numel(unique(numbers)) ~= numel(numbers)
    error('analyzeMeniscusFront:DuplicateStep','Несколько файлов одного шага.');
end
end

function writeFrontGif(result,mobileParts,gifPath)
fig = figure('Visible','off','Color','w','IntegerHandle','off', ...
    'MenuBar','none','ToolBar','none','Units','centimeters', ...
    'Position',[1 1 19 19],'PaperUnits','centimeters','PaperSize',[19 19], ...
    'PaperPosition',[0 0 19 19],'PaperPositionMode','manual','InvertHardcopy','off');
figureCleanup = onCleanup(@() close(fig));
temporaryPng = [tempname(fileparts(gifPath)) '.png'];
pngCleanup = onCleanup(@() removeTemporary({temporaryPng}));
canvas = uipanel(fig,'Units','points','Position',[0 0 19/2.54*72 19/2.54*72], ...
    'BorderType','none','BackgroundColor','white');
if isprop(canvas,'AutoResizeChildren'), canvas.AutoResizeChildren = 'off'; end
ax = axes('Parent',canvas,'Position',[.13 .18 .79 .68]);
hold(ax,'on');
curve = plot(ax,NaN,NaN,'--','Color',[0 .35 .75],'LineWidth',1.7);
points = plot(ax,NaN,NaN,'o','LineStyle','none','Color',[.8 .1 .05], ...
    'MarkerFaceColor',[1 .3 .15],'MarkerEdgeColor','w','MarkerSize',4.5);
axis(ax,'equal');
xlim(ax,[0 1]); ylim(ax,[0 1]);
grid(ax,'on'); box(ax,'on');
set(ax,'FontName','Arial','FontSize',11,'XTick',0:.2:1,'YTick',0:.2:1);
xlabel(ax,'x / ширина сети'); ylabel(ax,'y / высота сети');
legend(ax,[points curve],{'Мениски: State=1, Move~=2', ...
    'Линейная: среднее x при одинаковом y'},'Location','southoutside', ...
    'Interpreter','none','FontSize',9,'AutoUpdate','off');
heading = title(ax,'','Interpreter','none','FontSize',12);
emptyLabel = text(ax,.5,.5,'Нет менисков с Move~=2', ...
    'HorizontalAlignment','center','Visible','off','Color',[.4 .4 .4]);
for k = 1:height(result.frames)
    menisci = mobileParts{k};
    fit = result.frontFits{k};
    set(points,'XData',menisci.X,'YData',menisci.Y);
    if strcmp(fit.method,'linear')
        set(curve,'XData',fit.sampleX,'YData',fit.sampleY);
    else
        set(curve,'XData',NaN,'YData',NaN);
    end
    emptyLabel.Visible = 'off';
    if isempty(menisci), emptyLabel.Visible = 'on'; end
    heading.String = {sprintf('Шаг %d | t = %.6g с | Кадр %d / %d', ...
        result.frames.Step(k),result.frames.Time(k),k,height(result.frames)), ...
        sprintf('Менисков: %d | Интерполяция: %s',height(menisci),fit.method)};
    drawnow limitrate;
    if result.createGif
        exportgraphics(canvas,temporaryPng,'Resolution',100,'BackgroundColor','white');
        rgb = imread(temporaryPng);
        [indexed,palette] = rgb2ind(rgb,256,'nodither');
        if k == 1
            imwrite(indexed,palette,gifPath,'gif','LoopCount',Inf,'DelayTime',result.frameDelay);
        else
            imwrite(indexed,palette,gifPath,'gif','WriteMode','append','DelayTime',result.frameDelay);
        end
    end
    if k == 1 || k == height(result.frames) || mod(k,50)==0
        fprintf('Фронт: %d / %d кадров\n',k,height(result.frames));
    end
end
end

function removeTemporary(files)
for k = 1:numel(files)
    if isfile(files{k}), delete(files{k}); end
end
end
