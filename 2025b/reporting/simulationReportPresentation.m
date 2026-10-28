function presentation = simulationReportPresentation(Net,result,options)
%SIMULATIONREPORTPRESENTATION Labels and reference pressures; never changes Net.
% UI choices override saved report choices; old MAT files use their coefficients.
% P_cap is the static meniscus pressure 2*sigma*cos(theta)/r [Pa], not P_crit.
if nargin < 3, options = struct(); end
saved = struct();
if isfield(result,'reportModelOptions'), saved = result.reportModelOptions; end
choices = struct('includeAadd',isfield(Net,'xi') && Net.xi ~= 0, ...
    'meniscusModel',2,'showMeniscus',true);
if isfield(Net,'coef') && Net.coef == 0 && Net.P_crit_width == 0
    choices.meniscusModel = 1;
end
for field = fieldnames(choices)'
    key = field{1};
    if isfield(saved,key), choices.(key) = saved.(key); end
    if isfield(options,key), choices.(key) = options.(key); end
end
if isfield(result,'gifShowMeniscus') && ~isfield(options,'showMeniscus')
    choices.showMeniscus = result.gifShowMeniscus;
end
validateattributes(choices.includeAadd,{'logical','numeric'},{'scalar','binary'});
validateattributes(choices.showMeniscus,{'logical','numeric'},{'scalar','binary'});
validateattributes(choices.meniscusModel,{'numeric'},{'scalar','integer','>=',1,'<=',2});
boundaryLines = {sprintf('Давление на левой границе: %.12g Па',Net.H.P0)};
if Net.VerticalBC
    boundaryLines = [boundaryLines; ...
        {sprintf('Давление на верхней границе: %.12g Па',Net.V.P0); ...
        'Давление справа и снизу: 0 Па'; 'Верхняя и нижняя границы: открыты'}];
else
    boundaryLines = [boundaryLines; ...
        {'Давление справа: 0 Па'; 'Верхняя и нижняя границы: закрыты'}];
end
if choices.includeAadd
    addLine = 'Учет A_add включен';
    if isfield(Net,'xi'), addLine = sprintf('%s; xi = %.12g',addLine,Net.xi); end
else
    addLine = 'Учет A_add отключен';
end
modelLines = {addLine};
if choices.meniscusModel == 1
    modelLines{end+1,1} = 'Модель - один режим (вязкий)';
else
    modelLines{end+1,1} = 'Модель - два режима (плато и вязкий)';
    if isfield(Net,'k')
        modelLines{end+1,1} = sprintf('Коэффициент плато k: %.12g',Net.k);
        modelLines{end+1,1} = sprintf('P_crit: coef = %.12g Па·м^(5/4); ширина = %.12g Па', ...
            Net.coef,Net.P_crit_width);
    end
end
presentation = struct('boundaryLines',{boundaryLines},'modelLines',{modelLines}, ...
    'modelOptions',choices,'PcapH',2*Net.sigma*cos(Net.theta)./sqrt(Net.H.A/pi), ...
    'PcapV',2*Net.sigma*cos(Net.theta)./sqrt(Net.V.A/pi));
end
