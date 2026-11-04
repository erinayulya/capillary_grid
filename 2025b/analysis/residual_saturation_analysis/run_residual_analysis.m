% Выберите папку расчёта. Анализ последнего снимка, таблицы и общий PDF.
residualAnalysis = launchResidualAnalysis(fileparts(mfilename('fullpath')));

function result = launchResidualAnalysis(folder)
previousPath=path;
cleanup=onCleanup(@() path(previousPath));
addpath(folder,'-begin');
result=runResidualAnalysisDialog();
end
