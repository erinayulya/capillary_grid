function writeResidualSaturationTables(residualAnalysis,paths)
%WRITERESIDUALSATURATIONTABLES Stage four CSV tables and one MAT output.
% paths: size distribution, individual clusters, composition frequencies,
% channel membership, MAT. The caller publishes files after report success.
if numel(paths)~=5
    error('writeResidualSaturationTables:Paths','Требуются пять выходных путей.');
end
writetable(residualAnalysis.distribution,paths{1});
writetable(residualAnalysis.clusters,paths{2});
writetable(residualAnalysis.composition,paths{3});
writetable(residualAnalysis.channels,paths{4});
save(paths{5},'residualAnalysis','-v7.3');
end
