function [fraction,oilVolume,networkVolume] = networkOilSaturation(Net)
%NETWORKOILSATURATION Oil volume / network pore volume, without changing Net.
% Volumes are sum(A*L*phaseFraction), m^3; fraction is dimensionless [0,1].
% Includes every horizontal capillary and all internal vertical capillaries.
% Top/bottom vertical boundary stubs count only when VerticalBC is true.
% State 0/2 means water/oil; State 1 uses Sat, limited to [0,1] for reporting.
% Move, flow, history and connectivity do not exclude trapped/stationary fluid.
% Returns NaN for incomplete/invalid data, so reporting remains optional.
fraction=NaN; oilVolume=NaN; networkVolume=NaN;
if ~isstruct(Net) || ~all(isfield(Net,{'H','V','L','VerticalBC'})) || ...
        ~isnumeric(Net.L) || ~isscalar(Net.L) || ~isreal(Net.L) || ...
        ~isfinite(Net.L) || Net.L<=0 || ~isscalar(Net.VerticalBC)
    return
end
oil=0; total=0;
for key='HV'
    part=Net.(key);
    if ~isstruct(part) || ~all(isfield(part,{'A','Sat','State'})) || ...
            ~isnumeric(part.A) || ~isnumeric(part.Sat) || ~isnumeric(part.State) || ...
            ~isreal(part.A) || ~isreal(part.Sat) || ~isreal(part.State) || ...
            ~isequal(size(part.A),size(part.Sat),size(part.State))
        return
    end
    included=true(size(part.A));
    if key=='V' && ~Net.VerticalBC && ~isempty(included)
        included([1 end],:)=false;
    end
    areas=part.A(included); sat=part.Sat(included); state=part.State(included);
    if any(~isfinite(areas) | areas<=0) || any(~isfinite(sat)) || ...
            any(~ismember(state,[0 1 2]))
        return
    end
    sat=max(0,min(1,sat));
    sat(state==0)=0; sat(state==2)=1;
    volumes=areas*Net.L;
    total=total+sum(volumes);
    oil=oil+sum(volumes.*sat);
end
if ~isfinite(total) || total<=0 || ~isfinite(oil), return; end
oilVolume=oil; networkVolume=total;
fraction=min(1,max(0,oil/total));
end
