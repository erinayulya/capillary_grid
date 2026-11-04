function fit = interpolateMeniscusFront(menisci)
%INTERPOLATEMENISCUSFRONT Piecewise linear representative front x=f(y).
% Equal Y values are grouped: knots use the arithmetic mean X of all menisci.
% Raw points remain unchanged in the coordinate tables. Min/max retain spread.
% pp is a serializable piecewise polynomial, evaluated with ppval(pp,y).
% Only use pp inside domain: ppval itself would extrapolate outside it.
% Zero unique Y: no function. One unique Y: a point, no invented curve.
fit = struct('method','none','pp',[],'domain',[NaN NaN], ...
    'knots',table(zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    'VariableNames',{'Y','Count','X','XMin','XMax'}), ...
    'sampleY',zeros(0,1),'sampleX',zeros(0,1),'rawPointCount',height(menisci));
if isempty(menisci), return; end
validateattributes(menisci.X,{'numeric'},{'column','real','finite','>=',0,'<=',1});
validateattributes(menisci.Y,{'numeric'},{'column','real','finite','>=',0,'<=',1});
groups = groupsummary(menisci,"Y",["mean" "min" "max"],"X");
groups = sortrows(groups,'Y');
fit.knots = table(groups.Y,groups.GroupCount,groups.mean_X,groups.min_X,groups.max_X, ...
    'VariableNames',{'Y','Count','X','XMin','XMax'});
fit.domain = [groups.Y(1) groups.Y(end)];
if height(groups) == 1
    fit.method = 'point';
    fit.sampleY = groups.Y;
    fit.sampleX = groups.mean_X;
else
    fit.method = 'linear';
    slopes = diff(groups.mean_X)./diff(groups.Y);
    fit.pp = mkpp(groups.Y',[slopes groups.mean_X(1:end-1)]);
    fit.sampleY = groups.Y;
    fit.sampleX = groups.mean_X;
end
end
