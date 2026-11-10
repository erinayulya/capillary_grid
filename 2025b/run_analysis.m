% Анализ выбранного расчёта активной версии. Запускать кнопкой Run.
% Все координаты безразмерны: ширина и высота сети равны 1.
% Параметры фронта и кластеров задаются в диалоге; результаты — в analysis расчёта.
% «Сформировать краткий отчет» создаёт отдельный HTML с активными GIF.
frontAnalysis = runFrontAnalysis(fullfile(fileparts(mfilename('fullpath')), ...
    'analysis','front_analysis'));
if ~isempty(frontAnalysis)
    allMenisci = frontAnalysis.allMenisci;
    mobileMenisci = frontAnalysis.mobileMenisci;
    frontFits = frontAnalysis.frontFits;
    fourierFits = frontAnalysis.fourierFits;
    continuousSpectrum = frontAnalysis.continuousSpectrum;
    harmonicTable = frontAnalysis.harmonicTable;
    harmonicCosTable = frontAnalysis.harmonicCosTable;
    harmonicSinTable = frontAnalysis.harmonicSinTable;
    residualAnalysis = frontAnalysis.residualAnalysis;
end

function result = runFrontAnalysis(analysisDirectory)
previousPath = path;
pathCleanup = onCleanup(@() path(previousPath));
addpath(analysisDirectory,'-begin');
dialog = showFrontAnalysisDialog();
dialogCleanup = onCleanup(@() closeDialog(dialog));
uiwait(dialog);
result = [];
if ~isgraphics(dialog) || isempty(dialog.UserData), return; end
options = dialog.UserData;
delete(dialog);
if isfield(options,'createBriefReport') && options.createBriefReport
    result = writeBriefAnalysisReport(options.sourceDirectory);
else
    result = analyzeMeniscusFront(options.sourceDirectory,[],options.frameDelay,options);
end
end

function closeDialog(dialog)
if isgraphics(dialog), delete(dialog); end
end
