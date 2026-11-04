function result = runResidualAnalysisDialog()
%RUNRESIDUALANALYSISDIALOG Select a saved run; optionally rebuild common PDF.
% All processing starts after closing the dialog; Cancel does not write.
analysisDirectory=fileparts(mfilename('fullpath'));
releaseRoot=fileparts(fileparts(analysisDirectory));
previousPath=path;
pathCleanup=onCleanup(@() path(previousPath));
addpath(analysisDirectory,fullfile(releaseRoot,'analysis','front_analysis'),'-begin');
fig=showResidualAnalysisDialog(fullfile(releaseRoot,'results'));
dialogCleanup=onCleanup(@() closeDialog(fig));
uiwait(fig);
result=[];
if ~isgraphics(fig) || isempty(fig.UserData), return; end
options=fig.UserData;
delete(fig);
if options.analyzeClusters
    reportOptions=struct('createGif',false,'createPdf',true,'analyzeClusters',true);
    front=analyzeMeniscusFront(options.sourceDirectory,[],.1,reportOptions);
    result=front.residualAnalysis;
    fprintf('Общий отчёт анализа: %s\n',front.pdfPath);
else
    result=analyzeResidualSaturation(options.sourceDirectory);
end
fprintf('Шаг %d: %d кластеров. Таблицы: %s\n', ...
    result.step,height(result.clusters),result.outputDirectory);
end

function closeDialog(fig)
if isgraphics(fig), delete(fig); end
end
