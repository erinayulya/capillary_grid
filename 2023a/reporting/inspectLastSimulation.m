function info = inspectLastSimulation(resultsFolder)
%INSPECTLASTSIMULATION Inspect only the latest named run, without writes.
% A completed calculation is one that reached stationarity (or the legacy
% breakthrough criterion). A limit, manual stop, crash or error is resumable
% only when a valid solved snapshot exists. Does not execute calculations.
info = struct('found',false,'completed',false,'canResume',false, ...
    'directory','','status','','step',[],'elapsedTime',[],'resume',[], ...
    'gifPath','','pdfPath','','hasGif',false,'hasPdf',false, ...
    'needGif',false,'needPdf',false, ...
    'message','Сохранённых расчётов пока нет.');
folders = dir(fullfile(resultsFolder,'run_*'));
folders = folders([folders.isdir]);
tokens = regexp({folders.name},'^run_(\d{8})_(\d{6})(?:_(\d+))?$','tokens','once');
valid = ~cellfun('isempty',tokens);
folders = folders(valid); tokens = tokens(valid);
if isempty(folders), return; end
keys = zeros(numel(folders),2);
for index = 1:numel(folders)
    name = folders(index).name;
    keys(index,1) = str2double([name(5:12) name(14:19)]);
    keys(index,2) = 1;
    if numel(name) > 19
        keys(index,2) = str2double(name(21:end));
    end
end
[~,order] = sortrows(keys,[1 2]);
info.found = true;
info.directory = fullfile(resultsFolder,folders(order(end)).name);
info.gifPath = fullfile(info.directory,'saturation_pressure.gif');
info.pdfPath = fullfile(info.directory,'report.pdf');
info.hasGif = isfile(info.gifPath);
info.hasPdf = isfile(info.pdfPath);
try
    data = load(fullfile(info.directory,'summary.mat'),'result');
    if isstruct(data.result) && isscalar(data.result) && isfield(data.result,'status')
        status = data.result.status;
        if ischar(status) || (isstring(status) && isscalar(status))
            info.status = char(status);
        end
    end
catch
    info.status = 'Итоговый файл отсутствует или повреждён.';
end
info.completed = any(strcmp(info.status, ...
    {'Установилось стационарное течение.','Вторая фаза достигла правой границы.'}));
if info.completed
    info.needGif = ~info.hasGif;
    info.needPdf = ~info.hasPdf;
    info.message = 'Последний расчёт завершён до конца. Продолжение не требуется.';
    return;
end
try
    info.resume = prepareSimulationResume(info.directory);
    info.step = info.resume.snapshot.step;
    info.elapsedTime = info.resume.snapshot.elapsedTime;
    info.canResume = true;
    info.message = sprintf('Последний расчёт прерван. Сохранён шаг %d, t = %.6g с.', ...
        info.step,info.elapsedTime);
    if ~isempty(info.resume.skippedSnapshots)
        info.message = [info.message ' Более поздние повреждённые снимки пропущены.'];
    end
catch exception
    info.message = ['Последний расчёт не завершён. ' exception.message];
end
end
