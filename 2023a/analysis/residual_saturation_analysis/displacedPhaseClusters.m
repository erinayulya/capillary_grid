function result = displacedPhaseClusters(Net)
%DISPLACEDPHASECLUSTERS Connected displaced-phase segments in a saved Net.
% A channel counts once if its displaced volume is positive. Two channels
% join only at an internal node touched by displaced phase in BOTH channels.
% Sat=0 exposes both ends even for State=1; Sat=1 exposes neither end.
% Closed vertical boundary stubs and external reservoirs are not graph nodes.
% Whole components touching the right boundary through displaced phase are
% excluded. No Move/Q filter; bottom-connected components are not excluded.
% Output tables: channels (membership), clusters (size/H/V/volume/outlet),
% distribution (counts by size), composition (counts by size and H/V split).
% Volumes are m^3; saturation is dimensionless. Net is never changed.
validateattributes(Net.VerticalBC,{'logical','numeric'},{'scalar','binary'});
validateattributes(Net.L,{'numeric'},{'scalar','real','finite','positive'});
[ny,nx] = size(Net.H.A);
if nx<2 || ny<1 || ~isequal(size(Net.V.A),[ny+1 nx-1])
    error('displacedPhaseClusters:Geometry','Несогласованные размеры H.A и V.A.');
end
phase = 'water';
if isfield(Net,'displacingPhase')
    if strcmp(Net.displacingPhase,'water'), phase = 'oil';
    elseif ~strcmp(Net.displacingPhase,'oil')
        error('displacedPhaseClusters:Phase','Неизвестная вытесняющая фаза.');
    end
end
parts = cell(2,1); nodeParts = cell(2,1);
poreVolume = 0;
for orientation = 1:2
    keys = 'HV'; cap = Net.(keys(orientation));
    validateattributes(cap.A,{'numeric'},{'2d','real','finite','positive'});
    for field = ["State" "Sat" "Dir"]
        validateattributes(cap.(field),{'numeric'}, ...
            {'real','finite','size',size(cap.A)});
    end
    if any(~ismember(cap.State(:),[0 1 2])) || ...
            any(cap.Sat(:)<0 | cap.Sat(:)>1) || ...
            any(cap.State(:)==0 & cap.Sat(:)~=0) || ...
            any(cap.State(:)==2 & cap.Sat(:)~=1) || ...
            any(cap.State(:)==1 & ~ismember(cap.Dir(:),[-1 1]))
        error('displacedPhaseClusters:State','Некорректные State, Sat или Dir.');
    end
    included = true(size(cap.A));
    if orientation==2 && ~Net.VerticalBC, included([1 end],:) = false; end
    poreVolume = poreVolume + sum(cap.A(included))*Net.L;
    selected = included & cap.State~=2 & cap.Sat<1;
    [row,column] = find(selected);
    row=row(:); column=column(:);
    sat=cap.Sat(selected); sat=sat(:);
    direction=cap.Dir(selected); direction=direction(:);
    % A fully displaced-phase channel touches both ends. A genuine partial
    % channel touches only the end opposite the invading-phase entrance.
    first = sat==0 | direction<0;
    second = sat==0 | direction>0;
    if orientation==1
        firstRow=row; firstCol=column-1;
        secondRow=row; secondCol=column;
        outlet = second & column==nx;
    else
        firstRow=row-1; firstCol=column;
        secondRow=row; secondCol=column;
        outlet = second & row==ny+1;
    end
    rightBoundary = outlet & orientation==1;
    internalFirst = firstRow>=1 & firstRow<=ny & firstCol>=1 & firstCol<nx;
    internalSecond = secondRow>=1 & secondRow<=ny & secondCol>=1 & secondCol<nx;
    boundary = (first & ~internalFirst) | (second & ~internalSecond);
    nodes = zeros(numel(row),2);
    use = first & internalFirst;
    nodes(use,1) = firstRow(use)+(firstCol(use)-1)*ny;
    use = second & internalSecond;
    nodes(use,2) = secondRow(use)+(secondCol(use)-1)*ny;
    volume = cap.A(selected)*Net.L.*(1-sat); volume=volume(:);
    parts{orientation} = table(repmat(string(keys(orientation)),numel(row),1), ...
        row,column,sat,direction,volume,outlet,boundary,rightBoundary, ...
        'VariableNames',{'Orientation','CapillaryRow','CapillaryColumn', ...
        'Sat','Dir','DisplacedVolume','ConnectedToOutlet','TouchesBoundary', ...
        'ConnectedToRightBoundary'});
    nodeParts{orientation} = nodes;
end
channels = vertcat(parts{:}); nodes = vertcat(nodeParts{:});
count = height(channels);
if count==0
    membership=zeros(0,1);
else
    % Bipartite incidence avoids quadratic pairwise adjacency at junctions.
    channelIDs = repmat((1:count)',2,1); nodeIDs=nodes(:);
    use = nodeIDs>0;
    network = graph(channelIDs(use),count+nodeIDs(use),[],count+ny*(nx-1));
    components = conncomp(network);
    [~,~,membership] = unique(components(1:count)');
end
channels.ClusterID = membership;
nClusters = max([0;membership]);
if nClusters==0
    sizes=zeros(0,1); h=sizes; v=sizes; volumes=sizes;
    outlets=false(0,1); boundaries=outlets;
    rightConnected=outlets;
else
    sizes=accumarray(membership,1,[nClusters 1]);
    h=accumarray(membership,double(channels.Orientation=="H"),[nClusters 1]);
    v=sizes-h;
    volumes=accumarray(membership,channels.DisplacedVolume,[nClusters 1]);
    outlets=logical(accumarray(membership,double(channels.ConnectedToOutlet), ...
        [nClusters 1],@max));
    boundaries=logical(accumarray(membership,double(channels.TouchesBoundary), ...
        [nClusters 1],@max));
    rightConnected=logical(accumarray(membership,double(channels.ConnectedToRightBoundary), ...
        [nClusters 1],@max));
end
% Filter entire connected components, including their interior channels.
totalDisplacedVolume=sum(volumes);
excludedVolume=sum(volumes(rightConnected));
excludedChannelCount=sum(sizes(rightConnected));
excludedClusterCount=nnz(rightConnected);
keepCluster=~rightConnected;
keepChannel=keepCluster(membership);
newIDs=cumsum(keepCluster);
channels=channels(keepChannel,:);
channels.ClusterID=newIDs(membership(keepChannel));
sizes=sizes(keepCluster); h=h(keepCluster); v=v(keepCluster);
volumes=volumes(keepCluster); outlets=outlets(keepCluster); boundaries=boundaries(keepCluster);
nClusters=nnz(keepCluster);
clusters = table((1:nClusters)',sizes,h,v,volumes,outlets,boundaries, ...
    'VariableNames',{'ClusterID','ChannelCount','HorizontalCount','VerticalCount', ...
    'DisplacedVolume','ConnectedToOutlet','TouchesBoundary'});
maxSize=max([0;sizes]);
distribution = table((1:maxSize)',zeros(maxSize,1),zeros(maxSize,1), ...
    zeros(maxSize,1),zeros(maxSize,1),'VariableNames', ...
    {'ChannelCount','ClusterCount','HorizontalChannels','VerticalChannels','IsolatedClusterCount'});
if nClusters>0
    distribution.ClusterCount=accumarray(sizes,1,[maxSize 1]);
    distribution.HorizontalChannels=accumarray(sizes,h,[maxSize 1]);
    distribution.VerticalChannels=accumarray(sizes,v,[maxSize 1]);
    distribution.IsolatedClusterCount=accumarray(sizes,double(~outlets),[maxSize 1]);
    [splits,~,groups]=unique([sizes h v],'rows');
    composition=array2table([splits accumarray(groups,1)],'VariableNames', ...
        {'ChannelCount','HorizontalCount','VerticalCount','ClusterCount'});
else
    composition=array2table(zeros(0,4),'VariableNames', ...
        {'ChannelCount','HorizontalCount','VerticalCount','ClusterCount'});
end
totalVolume=sum(volumes);
result=struct('displacedPhase',phase,'channels',channels,'clusters',clusters, ...
    'distribution',distribution,'composition',composition,'poreVolume',poreVolume, ...
    'displacedVolume',totalVolume,'displacedSaturation',totalVolume/poreVolume, ...
    'totalDisplacedVolume',totalDisplacedVolume, ...
    'excludedRightConnectedVolume',excludedVolume, ...
    'excludedRightConnectedChannelCount',excludedChannelCount, ...
    'excludedRightConnectedClusterCount',excludedClusterCount, ...
    'isolatedVolume',sum(volumes(~outlets)), ...
    'isolatedSaturation',sum(volumes(~outlets))/poreVolume);
end
