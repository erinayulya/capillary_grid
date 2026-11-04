function folder = latestFrontAnalysisRun(resultsDirectory)
%LATESTFRONTANALYSISRUN Newest named run with saved steps, without writes.
% Used only as the default; the dialog can select another results folder.
folders = dir(fullfile(resultsDirectory,'run_*'));
folders = folders([folders.isdir]);
keys = NaN(numel(folders),2);
for k = 1:numel(folders)
    token = regexp(folders(k).name,'^run_(\d{8})_(\d{6})(?:_(\d+))?$','tokens','once');
    if isempty(token), continue; end
    keys(k,1) = str2double([token{1} token{2}]);
    keys(k,2) = 0;
    if numel(token)>2, keys(k,2) = str2double(token{3}); end
end
valid = isfinite(keys(:,1));
folders = folders(valid); keys = keys(valid,:);
[~,order] = sortrows(keys,[-1 -2]);
for index = order'
    candidate = fullfile(resultsDirectory,folders(index).name);
    files = dir(fullfile(candidate,'step_*.mat'));
    validNames = ~cellfun('isempty',regexp({files.name},'^step_\d+\.mat$','once'));
    if any(validNames & ~[files.isdir]), folder = candidate; return; end
end
error('analyzeMeniscusFront:NoRun','В results нет расчётов с сохранёнными шагами.');
end
