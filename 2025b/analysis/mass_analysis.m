function batchSummary = mass_analysis(parentDirectory,overwrite)
%MASS_ANALYSIS Create brief HTML reports for all runs below a chosen folder.
%   MASS_ANALYSIS opens a folder picker. Select e.g. the calculation's 10_10
%   folder, not the generator's Excel folder. Every nested summary.mat is
%   treated as a run. Output is each run's analysis/brief_report.html.
%
%   SUMMARY = MASS_ANALYSIS(FOLDER) regenerates all reports without per-run
%   dialogs. Mu and sigma must occur in a sigma_*_mu_* path component.
%   MASS_ANALYSIS(FOLDER,FALSE) skips reports that already exist, allowing
%   an interrupted batch to continue. The default OVERWRITE is TRUE.
%   A failed report is logged; the remaining runs continue. The existing
%   writer preserves the previous brief report if regeneration fails.
%
%   SUMMARY and FOLDER/mass_analysis_summary.csv contain RunDirectory,
%   ReportPath, Status (pending/done/skipped/error), Message, ElapsedSeconds.
%   This function does not run a simulation or modify input MAT/old PDFs.

narginchk(0,2);
batchSummary = emptySummary();
if nargin<2, overwrite=true; end
validateattributes(overwrite,{'logical','numeric'}, ...
    {'scalar','real','finite','binary'},mfilename,'overwrite');
analysisDirectory=fileparts(mfilename('fullpath'));
releaseRoot=fileparts(analysisDirectory);
previousPath=path;
pathCleanup=onCleanup(@() path(previousPath));
addpath(fullfile(analysisDirectory,'front_analysis'),'-begin');
if nargin<1 || isempty(parentDirectory)
    parentDirectory=uigetdir(fullfile(releaseRoot,'results'), ...
        'Выберите папку результатов, например 10_10');
    if isequal(parentDirectory,0), return; end
end
if ~((ischar(parentDirectory) && isrow(parentDirectory)) || ...
        (isstring(parentDirectory) && isscalar(parentDirectory)))
    error('mass_analysis:Directory','Путь должен быть строкой или вектором символов.');
end
parentDirectory=char(parentDirectory);
if ~isfolder(parentDirectory)
    error('mass_analysis:Directory','Папка не найдена: %s',parentDirectory);
end
[~,attributes]=fileattrib(parentDirectory);
parentDirectory=attributes.Name;
% Include a selected run itself as well as arbitrarily nested run folders.
files=[dir(fullfile(parentDirectory,'summary.mat')); ...
    dir(fullfile(parentDirectory,'**','summary.mat'))];
files=files(~[files.isdir]);
if isempty(files)
    error('mass_analysis:NoResults', ...
        'В %s нет summary.mat. Выберите папку результатов расчёта, а не таблиц сетки.', ...
        parentDirectory);
end
sources=unique(string({files.folder}).');
count=numel(sources);
batchSummary=table(sources,fullfile(sources,'analysis','brief_report.html'), ...
    repmat("pending",count,1),strings(count,1),zeros(count,1), ...
    'VariableNames',{'RunDirectory','ReportPath','Status','Message','ElapsedSeconds'});
journal=fullfile(parentDirectory,'mass_analysis_summary.csv');
writeJournal(batchSummary,journal);
fprintf('Найдено расчётов: %d. Журнал: %s\n',count,journal);
for index=1:count
    source=char(sources(index));
    fprintf('\n[%d/%d] %s\n',index,count,source);
    timer=tic;
    try
        if ~overwrite && isfile(batchSummary.ReportPath(index))
            batchSummary.Status(index)="skipped";
            batchSummary.Message(index)="Краткий отчёт уже существует.";
            fprintf('Пропуск: отчёт уже существует.\n');
        else
            steps=dir(fullfile(source,'step_*.mat'));
            if ~any(~[steps.isdir] & ...
                    ~cellfun('isempty',regexp({steps.name},'^step_\d+\.mat$','once')))
                error('mass_analysis:NoSteps','Нет сохранённых step_*.mat.');
            end
            distribution=readDistribution(source);
            report=writeBriefAnalysisReport(source,distribution);
            batchSummary.ReportPath(index)=string(report.briefReportPath);
            clear report
            batchSummary.Status(index)="done";
            batchSummary.Message(index)="Краткий отчёт сформирован.";
        end
    catch exception
        batchSummary.Status(index)="error";
        batchSummary.Message(index)=string(exception.identifier)+": "+exception.message;
        warning('mass_analysis:ReportFailed','%s: %s',source,exception.message);
    end
    batchSummary.ElapsedSeconds(index)=toc(timer);
    writeJournal(batchSummary,journal);
end
fprintf('\nГотово: %d; пропущено: %d; ошибок: %d.\nЖурнал: %s\n', ...
    nnz(batchSummary.Status=="done"),nnz(batchSummary.Status=="skipped"), ...
    nnz(batchSummary.Status=="error"),journal);
end

function distribution=readDistribution(source)
% Resolve explicitly, so the individual report can never open inputdlg.
number='([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)';
token=regexp(source,['(?:^|[\\/])sigma_' number '_mu_' number '(?:[\\/]|$)'], ...
    'tokens','once');
if isempty(token)
    error('mass_analysis:MissingDistribution', ...
        ['В пути нет sigma_<sigma>_mu_<mu>. Заданные параметры неизвестны; ' ...
         'для этого расчёта сформируйте отчёт отдельно через run_analysis.']);
end
distribution=struct('mu',str2double(token{2}),'sigma',str2double(token{1}));
end

function writeJournal(summary,file)
temporary=[tempname(fileparts(file)) '.tmp.csv'];
cleanup=onCleanup(@() deleteTemporary(temporary));
writetable(summary,temporary,'Encoding','UTF-8');
[ok,message]=movefile(temporary,file,'f');
if ~ok, error('mass_analysis:JournalWrite','%s',message); end
end

function deleteTemporary(file)
if isfile(file), delete(file); end
end

function summary=emptySummary()
summary=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),zeros(0,1), ...
    'VariableNames',{'RunDirectory','ReportPath','Status','Message','ElapsedSeconds'});
end
