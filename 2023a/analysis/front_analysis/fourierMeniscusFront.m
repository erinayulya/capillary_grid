function series = fourierMeniscusFront(fit)
%FOURIERMENISCUSFRONT First ten Fourier harmonics of a representative front.
% fit is the output of interpolateMeniscusFront; no source points are changed.
% Integrates the piecewise-linear mean-X front over its observed Y domain.
% u=(y-domain(1))/period; x_K(y)=a0+sum(a.*cos(2*pi*k*u)+b.*sin(2*pi*k*u)).
% a0/a/b are in fractions of network width; frequencies are cycles per
% normalized network height. The observed interval is periodically extended.
% No window, detrending, extrapolation, or Signal Processing Toolbox is used.
% Empty/single-height fronts have NaN coefficients and no invented curves.
count = 10;
partialCounts = [1 3 6 10];
series = struct('status','unavailable','harmonicCount',count, ...
    'domain',fit.domain,'period',NaN,'a0',NaN,'a',NaN(count,1), ...
    'b',NaN(count,1),'amplitudes',NaN(count,1), ...
    'frequencies',NaN(count,1),'angularFrequencies',NaN(count,1), ...
    'sampleY',zeros(0,1),'partialCounts',partialCounts, ...
    'partialSums',zeros(0,numel(partialCounts)), ...
    'rawPointCount',fit.rawPointCount,'formulaLines',{{}},'formulaText','');
if ~strcmp(fit.method,'linear')
    if strcmp(fit.method,'none')
        series.status = 'no-points';
        lines = {'Ряд Фурье не определён: нет выбранных менисков.'};
    else
        series.status = 'single-height';
        lines = {'Ряд Фурье не определён: только одна высота Y.'};
    end
    series.formulaLines = lines;
    series.formulaText = strjoin(lines,newline);
    return;
end
series.period = diff(fit.domain);
validateattributes(series.period,{'numeric'},{'scalar','positive','finite'});
y0 = fit.domain(1);
period = series.period;
waypoints = (fit.knots.Y(2:end-1)-y0)/period;
front = @(u) ppval(fit.pp,y0+period*u);
series.a0 = integral(front,0,1,'Waypoints',waypoints, ...
    'AbsTol',1e-12,'RelTol',1e-10);
for k = 1:count
    series.a(k) = 2*integral(@(u) front(u).*cos(2*pi*k*u),0,1, ...
        'Waypoints',waypoints,'AbsTol',1e-12,'RelTol',1e-10);
    series.b(k) = 2*integral(@(u) front(u).*sin(2*pi*k*u),0,1, ...
        'Waypoints',waypoints,'AbsTol',1e-12,'RelTol',1e-10);
end
series.amplitudes = hypot(series.a,series.b);
series.frequencies = (1:count)'/period;
series.angularFrequencies = 2*pi*series.frequencies;
u = linspace(0,1,501)';
series.sampleY = y0+period*u;
terms = cos(2*pi*u*(1:count)).*series.a' + ...
    sin(2*pi*u*(1:count)).*series.b';
sums = series.a0+cumsum(terms,2);
series.partialSums = sums(:,partialCounts);
series.status = 'ok';
series.formulaLines = formulaLines(series);
series.formulaText = strjoin(series.formulaLines,newline);
end

function lines = formulaLines(series)
variable = 'y';
if ~isequal(series.domain,[0 1]), variable = 'u'; end
lines = cell(series.harmonicCount+2,1);
lines{1} = sprintf('x10(y) = %.7g',series.a0);
for k = 1:series.harmonicCount
    a = series.a(k); b = series.b(k);
    % Hide integration roundoff only in displayed text; MAT keeps all digits.
    tolerance = 100*eps(max(1,abs(series.a0)));
    if abs(a)<tolerance, a = 0; end
    if abs(b)<tolerance, b = 0; end
    lines{k+1} = sprintf('  %+.7g*cos(%d*pi*%s) %+.7g*sin(%d*pi*%s)', ...
        a,2*k,variable,b,2*k,variable);
end
if strcmp(variable,'y')
    lines{end} = 'Период по y: 1; частоты: 1, 2, ..., 10 циклов на высоту.';
else
    lines{end} = sprintf('u = (y - %.7g)/%.7g; период по y: %.7g.', ...
        series.domain(1),series.period,series.period);
end
end
