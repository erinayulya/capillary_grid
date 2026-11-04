function residualAnalysis = analyzeResidualSaturation(sourceDirectory,outputDirectory,saveResults)
%ANALYZERESIDUALSATURATION Analyze the highest numbered saved step, read-only.
% Prefer solvedNet; legacy snapshots may contain Net only. Never silently
% fall back to an earlier state when the latest snapshot is invalid.
% Default output: sourceDirectory/analysis.
% Saves cluster_sizes.csv, clusters.csv, cluster_composition.csv,
% cluster_channels.csv and residual_saturation.mat; no PDF is created here.
% saveResults=false returns data without writing outputs (common report staging).
if nargin<3, saveResults=true; end
validateattributes(saveResults,{'logical','numeric'},{'scalar','binary'});
if nargin<1 || isempty(sourceDirectory)
    error('analyzeResidualSaturation:Directory','Укажите папку расчёта.');
end
sourceDirectory=char(sourceDirectory);
if ~isfolder(sourceDirectory)
    error('analyzeResidualSaturation:Directory','Папка расчёта не существует.');
end
files=dir(fullfile(sourceDirectory,'step_*.mat'));
files=files(~[files.isdir]);
tokens=regexp({files.name},'^step_(\d+)\.mat$','tokens','once');
valid=~cellfun('isempty',tokens); files=files(valid); tokens=tokens(valid);
numbers=cellfun(@(token) str2double(token{1}),tokens);
if isempty(numbers)
    error('analyzeResidualSaturation:NoSteps','Нет сохранённых step_*.mat.');
end
if numel(unique(numbers))~=numel(numbers)
    error('analyzeResidualSaturation:DuplicateStep','Несколько файлов одного шага.');
end
[lastStep,index]=max(numbers);
snapshotPath=fullfile(sourceDirectory,files(index).name);
variables=whos('-file',snapshotPath);
selected=intersect({'solvedNet','Net','step','elapsedTime'},{variables.name});
snapshot=load(snapshotPath,selected{:});
if isfield(snapshot,'solvedNet'), savedNet=snapshot.solvedNet;
elseif isfield(snapshot,'Net'), savedNet=snapshot.Net;
else, error('analyzeResidualSaturation:Snapshot','В снимке нет solvedNet или Net.');
end
if ~all(isfield(snapshot,{'step','elapsedTime'})) || ~isequal(snapshot.step,lastStep)
    error('analyzeResidualSaturation:Snapshot','Номер шага или метаданные снимка некорректны.');
end
validateattributes(snapshot.elapsedTime,{'numeric'},{'scalar','real','finite','nonnegative'});
residualAnalysis=displacedPhaseClusters(savedNet);
if nargin<2 || isempty(outputDirectory)
    outputDirectory=fullfile(sourceDirectory,'analysis');
elseif ~isfolder(outputDirectory)
    error('analyzeResidualSaturation:Directory','Явно заданная выходная папка должна существовать.');
end
outputDirectory=char(outputDirectory);
if ~isfolder(outputDirectory)
    [ok,message]=mkdir(outputDirectory);
    if ~ok, error('analyzeResidualSaturation:Directory','%s',message); end
end
residualAnalysis.sourceDirectory=sourceDirectory;
residualAnalysis.snapshotPath=snapshotPath;
residualAnalysis.outputDirectory=outputDirectory;
residualAnalysis.step=lastStep;
residualAnalysis.elapsedTime=snapshot.elapsedTime;
if ~saveResults, return; end
base=tempname(outputDirectory);
suffixes={'.sizes.csv','.clusters.csv','.composition.csv','.channels.csv','.mat'};
temporary=strcat(base,suffixes);
cleanup=onCleanup(@() removeTemporary(temporary));
writeResidualSaturationTables(residualAnalysis,temporary);
targets={'cluster_sizes.csv','clusters.csv','cluster_composition.csv', ...
    'cluster_channels.csv','residual_saturation.mat'};
for k=1:numel(targets)
    [ok,message]=movefile(temporary{k},fullfile(outputDirectory,targets{k}),'f');
    if ~ok, error('analyzeResidualSaturation:WriteFailed','%s',message); end
end
end

function removeTemporary(files)
for k=1:numel(files)
    if isfile(files{k}), delete(files{k}); end
end
end
