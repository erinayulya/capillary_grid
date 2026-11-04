function outputFolder = run(nRows, nCols)
%RUN Generate 25 lognormal area meshes and a five-page distribution PDF.
%   RUN(NROWS,NCOLS) uses the five sigma values and five mu values per
%   sigma listed below. Mu and sigma describe ln(A), with A in m^2.
%   Diameters are restricted to 0.1-1 mm by resampling rejected areas.
%   NROWS and NCOLS are positive integers, as in the calculation UI.
%
%   FOLDER = RUN(...) returns the absolute results/NROWS_NCOLS folder.
%   Each sigma_<value>_mu_<value> subfolder contains horizontal_areas.xlsx
%   (NROWS-by-(NCOLS+1)) and vertical_areas.xlsx ((NROWS+1)-by-NCOLS).
%   The first sheet contains only numeric areas in m^2, ready for import.
%   A manifest MAT and distribution_visualization.pdf accompany the meshes.
%   An existing output folder is never replaced. Use RNG before RUN for
%   reproducible draws; RUN does not reset the random number generator.
%
%   Call from this folder to distinguish this RUN from the calculation UI.
%   Example: rng(42); folder = run(50,50);
%
%   See also RNG, RANDN, WRITEMATRIX, EXPORTGRAPHICS

narginchk(2,2);
validateattributes(nRows,{'numeric'}, ...
    {'real','finite','scalar','integer','positive','<=',1048575}, ...
    mfilename,'nRows',1);
validateattributes(nCols,{'numeric'}, ...
    {'real','finite','scalar','integer','positive','<=',16383}, ...
    mfilename,'nCols',2);
nRows = double(nRows);
nCols = double(nCols);

% One row of mu values for each sigma; these are parameters of log AREA.
sigmaValues = [0.1 0.2 0.3 0.4 0.5];
muValues = [ ...
    -18.36 -17.36 -16.36 -15.36 -14.36; ...
    -18.06 -17.21 -16.36 -15.51 -14.66; ...
    -17.76 -17.06 -16.36 -15.66 -14.96; ...
    -17.46 -16.91 -16.36 -15.81 -15.26; ...
    -17.16 -16.76 -16.36 -15.96 -15.56];
diameterBoundsM = [0.1e-3 1e-3];
areaBoundsM2 = pi*(diameterBoundsM/2).^2;
validateParameters(sigmaValues,muValues,areaBoundsM2);

generatorFolder = fileparts(mfilename('fullpath'));
resultsFolder = fullfile(generatorFolder,'results');
outputFolder = fullfile(resultsFolder,sprintf('%d_%d',nRows,nCols));
requireNewOutput(outputFolder);
ensureFolder(resultsFolder);

% Publish the complete set only after all Excel files and PDF pages exist.
stagingFolder = [tempname(resultsFolder) '_lognorm'];
ensureFolder(stagingFolder);
cleanup = onCleanup(@() removeStaging(stagingFolder,resultsFolder));
generation = struct('formatVersion',1,'nRows',nRows,'nCols',nCols, ...
    'sigmaValues',sigmaValues,'muValues',muValues,'areaUnit','m^2', ...
    'diameterBoundsM',diameterBoundsM,'areaBoundsM2',areaBoundsM2, ...
    'distribution','truncated lognormal area', ...
    'rngBeforeGeneration',rng, ...
    'createdAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
summary = repmat(struct('sigma',0,'mu',0,'folderName','', ...
    'minimumDiameterM',0,'maximumDiameterM',0,'areaFractionSum',0),25,1);
pairIndex = 0;
for sigmaIndex = 1:numel(sigmaValues)
    sigma = sigmaValues(sigmaIndex);
    for muIndex = 1:size(muValues,2)
        mu = muValues(sigmaIndex,muIndex);
        pairIndex = pairIndex+1;
        folderName = sprintf('sigma_%.1f_mu_%.2f',sigma,mu);
        pairFolder = fullfile(stagingFolder,folderName);
        ensureFolder(pairFolder);
        Ah = sampleAreas(nRows,nCols+1,mu,sigma,areaBoundsM2);
        Av = sampleAreas(nRows+1,nCols,mu,sigma,areaBoundsM2);
        writematrix(Ah,fullfile(pairFolder,'horizontal_areas.xlsx'), ...
            'Sheet',1,'UseExcel',false);
        writematrix(Av,fullfile(pairFolder,'vertical_areas.xlsx'), ...
            'Sheet',1,'UseExcel',false);
        totalArea = sum(Ah(:))+sum(Av(:));
        summary(pairIndex) = struct('sigma',sigma,'mu',mu, ...
            'folderName',folderName, ...
            'minimumDiameterM',2*sqrt(min(min(Ah(:)),min(Av(:)))/pi), ...
            'maximumDiameterM',2*sqrt(max(max(Ah(:)),max(Av(:)))/pi), ...
            'areaFractionSum',sum(Ah(:)/totalArea)+sum(Av(:)/totalArea));
        fprintf('[%2d/25] %s\n',pairIndex,folderName);
    end
end
generation.meshes = summary;
save(fullfile(stagingFolder,'manifest.mat'),'generation');
writeDistributionPdf(fullfile(stagingFolder, ...
    'distribution_visualization.pdf'),sigmaValues,muValues,areaBoundsM2);
requireNewOutput(outputFolder);
[success,message] = movefile(stagingFolder,outputFolder);
if ~success
    error('generate_lognorm_mesh:PublishFailed','%s',message);
end
clear cleanup
fprintf('Готово: 25 сеток, 50 Excel-файлов и PDF из 5 страниц.\n%s\n', ...
    outputFolder);
end

function validateParameters(sigmaValues,muValues,areaBounds)
if ~isequal(size(muValues),[numel(sigmaValues) 5]) || ...
        numel(sigmaValues) ~= 5 || any(~isfinite(muValues(:))) || ...
        any(~isfinite(sigmaValues(:)) | sigmaValues(:) <= 0)
    error('generate_lognorm_mesh:Parameters', ...
        'Нужны 5 положительных sigma и таблица 5 на 5 конечных mu.');
end
lower = log(areaBounds(1));
upper = log(areaBounds(2));
if any(any(muValues-3*sigmaValues(:) < lower)) || ...
        any(any(muValues+3*sigmaValues(:) > upper))
    error('generate_lognorm_mesh:ThreeSigmaRange', ...
        'Каждая пара mu/sigma должна помещать mu +/- 3*sigma в ln(Amin)..ln(Amax).');
end
names = cell(numel(muValues),1);
for row = 1:5
    for column = 1:5
        names{(row-1)*5+column} = sprintf('sigma_%.1f_mu_%.2f', ...
            sigmaValues(row),muValues(row,column));
    end
end
if numel(unique(names)) ~= 25
    error('generate_lognorm_mesh:DuplicateNames', ...
        'После округления sigma и mu имена всех 25 папок должны различаться.');
end
end

function A = sampleAreas(nRows,nCols,mu,sigma,areaBounds)
% Rejection sampling preserves the conditional lognormal distribution.
% Never clip values or rescale physical areas to make their sum equal one.
A = exp(mu+sigma*randn(nRows,nCols));
for attempt = 1:100
    rejected = ~isfinite(A) | A < areaBounds(1) | A > areaBounds(2);
    if ~any(rejected(:)), return; end
    A(rejected) = exp(mu+sigma*randn(nnz(rejected),1));
end
error('generate_lognorm_mesh:SamplingFailed', ...
    'Не удалось получить все площади в допустимом диапазоне.');
end

function writeDistributionPdf(pdfFile,sigmaValues,muValues,areaBounds)
% Five vector pages, with linear axes, matching the in-chat area plots.
fig = figure('Visible','off','Color','white','Units','pixels', ...
    'Position',[100 100 1100 680],'Name','Distribution visualization');
cleanup = onCleanup(@() close(fig));
ax = axes('Parent',fig,'Color','white','XColor','black','YColor','black', ...
    'FontName','Arial','FontSize',12,'Box','on');
palette.plotColors = lines(5);
A = logspace(log10(areaBounds(1)),log10(areaBounds(2)),6001).';
A(1) = areaBounds(1);
A(end) = areaBounds(2);
areaUnit = 1e-7;
plotA = [0;areaBounds(1);A;areaBounds(2);areaBounds(2)*1.025];
for sigmaIndex = 1:numel(sigmaValues)
    cla(ax);
    hold(ax,'on');
    colororder(ax,palette.plotColors);
    sigma = sigmaValues(sigmaIndex);
    handles = gobjects(1,5);
    labels = cell(1,5);
    peak = 0;
    for muIndex = 1:5
        mu = muValues(sigmaIndex,muIndex);
        zBounds = (log(areaBounds)-mu)/sigma;
        probabilityInRange = 0.5*diff(erf(zBounds/sqrt(2)));
        density = exp(-0.5*((log(A)-mu)/sigma).^2) ./ ...
            (A*sigma*sqrt(2*pi)*probabilityInRange);
        peak = max(peak,max(density)*areaUnit);
        plotDensity = [0;0;density;0;0]*areaUnit;
        handles(muIndex) = plot(ax,plotA/areaUnit,plotDensity,'LineWidth',1.8);
        labels{muIndex} = ['\mu = ' num2str(mu,'%.2f')];
    end
    hold(ax,'off');
    title(ax,{'Lognormal area distributions', ...
        ['\sigma = ' num2str(sigma,'%.1f') ' | diameters 0.1-1 mm']}, ...
        'Color','black');
    xlabel(ax,'Area A (10^{-7} m^2)','Color','black');
    ylabel(ax,'Density per 10^{-7} m^2','Color','black');
    xlim(ax,[0 max(plotA)/areaUnit]);
    ylim(ax,[0 1.08*peak]);
    grid(ax,'on');
    ax.GridColor = [0.7 0.7 0.7];
    ax.GridAlpha = 0.3;
    legend(ax,handles,labels,'Location','northeast', ...
        'Box','off','TextColor','black','FontSize',11);
    exportgraphics(ax,pdfFile,'ContentType','vector', ...
        'BackgroundColor','white','Append',sigmaIndex > 1);
end
clear cleanup
end

function ensureFolder(folder)
[success,message] = mkdir(folder);
if ~success, error('generate_lognorm_mesh:CreateFolder','%s',message); end
end

function requireNewOutput(folder)
if isfolder(folder) || isfile(folder)
    error('generate_lognorm_mesh:ResultsExist', ...
        ['Результат уже существует: %s\n' ...
         'Чтобы создать новую выборку, сначала переместите прежний результат.'], ...
        folder);
end
end

function removeStaging(folder,resultsFolder)
% Delete only our generated, absolute, direct child of results.
[parent,name] = fileparts(folder);
if ispc
    isChild = strcmpi(parent,resultsFolder);
else
    isChild = strcmp(parent,resultsFolder);
end
if ~isChild || ~endsWith(name,'_lognorm')
    warning('generate_lognorm_mesh:CleanupPath', ...
        'Временная папка не удалена: не прошла проверку пути.');
    return;
end
if isfolder(folder)
    [success,message] = rmdir(folder,'s');
    if ~success, warning('generate_lognorm_mesh:CleanupFailed','%s',message); end
end
end
