function [allMenisci,mobileMenisci,geometry] = meniscusCoordinates(Net,step,elapsedTime)
%MENISCUSCOORDINATES Read menisci in a unit square without changing Net.
% Tables: Step, Time (s), Orientation (H/V), CapillaryRow, CapillaryColumn,
% X, Y, Sat, Dir, Move.
% All State=1 menisci count, including Sat=0 and stationary menisci.
% The mobile subset follows the requested rule Move~=2 (also includes 0/3).
% Closed vertical boundary stubs are excluded. Open stubs extend Y bounds.
validateattributes(step,{'numeric'},{'scalar','real','finite','integer','nonnegative'});
validateattributes(elapsedTime,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(Net.VerticalBC,{'logical','numeric'},{'scalar','binary'});
[ny,nx] = size(Net.H.A);
if nx < 2 || ny < 1 || ~isequal(size(Net.V.A),[ny+1 nx-1])
    error('meniscusCoordinates:Geometry','Несогласованные размеры H.A и V.A.');
end
openBoundary = logical(Net.VerticalBC);
heightInCells = max(1,ny-1+2*double(openBoundary));
geometry = struct('Nx',nx,'Ny',ny,'VerticalBC',openBoundary, ...
    'xBounds',[0 nx],'yBounds',[-double(openBoundary) ny-1+double(openBoundary)], ...
    'xScale',nx,'yScale',heightInCells);
parts = cell(2,1);
keys = 'HV';
for k = 1:2
    cap = Net.(keys(k));
    expectedSize = size(cap.A);
    for field = ["State" "Sat" "Dir" "Move"]
        validateattributes(cap.(field),{'numeric'}, ...
            {'real','finite','size',expectedSize});
    end
    if any(~ismember(cap.State(:),[0 1 2])) || any(~ismember(cap.Move(:),[0 1 2 3]))
        error('meniscusCoordinates:State','Неизвестный код State или Move.');
    end
    selected = cap.State == 1;
    if k == 2 && ~openBoundary, selected([1 end],:) = false; end
    [row,column] = find(selected);
    row = row(:); column = column(:);
    sat = cap.Sat(selected);
    direction = cap.Dir(selected);
    movement = cap.Move(selected);
    sat = sat(:); direction = direction(:); movement = movement(:);
    if any(~ismember(direction,[-1 1])) || any(sat < -1e-10 | sat > 1+1e-10)
        error('meniscusCoordinates:Meniscus','Некорректные Sat или Dir у мениска.');
    end
    sat = max(0,min(1,sat)); % Roundoff only; the source Net is never changed.
    if k == 1
        x = column-1+sat;
        reverse = direction < 0;
        x(reverse) = column(reverse)-sat(reverse);
        y = ny-row;
    else
        x = column;
        y = ny-row+1-sat;
        reverse = direction < 0;
        y(reverse) = ny-row(reverse)+sat(reverse);
    end
    x = x/nx;
    y = (y+double(openBoundary))/heightInCells;
    n = numel(sat);
    parts{k} = table(repmat(step,n,1),repmat(elapsedTime,n,1), ...
        repmat(string(keys(k)),n,1),row,column,x,y,sat,direction,movement, ...
        'VariableNames',{'Step','Time','Orientation','CapillaryRow','CapillaryColumn', ...
        'X','Y','Sat','Dir','Move'});
end
allMenisci = vertcat(parts{:});
allMenisci.Properties.VariableUnits = {'','s','','','','1','1','1','',''};
allMenisci.Properties.Description = 'State=1; normalized geometry; closed stubs excluded';
mobileMenisci = allMenisci(allMenisci.Move ~= 2,:);
mobileMenisci.Properties.Description = 'State=1 and Move~=2; includes temporarily held menisci';
end
