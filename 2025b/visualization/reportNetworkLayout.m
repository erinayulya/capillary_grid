function layout = reportNetworkLayout(nx,ny,slots,pageSizePoints)
%REPORTNETWORKLAYOUT Fit two networks inside their PDF slots in physical units.
% Small networks use 32 pt per lattice interval. Larger ones fit the slot.
% slots: two normalized [x y width height] rows, saturation then pressure.
validateattributes(nx,{'numeric'},{'scalar','integer','>=',2});
validateattributes(ny,{'numeric'},{'scalar','integer','positive'});
validateattributes(slots,{'numeric'},{'size',[2 4],'real','finite','nonnegative'});
validateattributes(pageSizePoints,{'numeric'},{'size',[1 2],'real','finite','positive'});
scale = pageSizePoints([1 2 1 2]);
boxes = slots.*scale;
span = [nx+.6 ny+1.6];
% Reserve tick labels, titles, legend and the pressure scale inside each slot.
available = [min(boxes(:,3))-104 min(boxes(:,4))-62];
assert(all(available>0),'reportNetworkLayout:SlotSize','Недостаточно места для графика.');
pitch = min([32 available./span]);
plotSize = span*pitch;
positions = zeros(2,4);
for index = 1:2
    positions(index,:) = [boxes(index,1)+28+(boxes(index,3)-104-plotSize(1))/2, ...
        boxes(index,2)+38+(boxes(index,4)-62-plotSize(2))/2,plotSize];
end
bar = [positions(2,1)+positions(2,3)+12 positions(2,2) 10 positions(2,4)];
layout = struct('axesPositions',positions./scale,'colorbarPosition',bar./scale, ...
    'cellPitchPoints',pitch,'nodeDiameterPoints',min(14,.60*pitch), ...
    'lineWidthPoints',min(3,.10*pitch),'meniscusDiameterPoints',min(6,.22*pitch));
end
