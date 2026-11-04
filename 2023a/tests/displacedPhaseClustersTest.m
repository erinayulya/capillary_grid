classdef displacedPhaseClustersTest < matlab.unittest.TestCase
    % Analytic connectivity examples, independent of model/solver functions.
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'analysis','residual_saturation_analysis')));
        end
    end
    methods (Test)
        function oilAtJunctionSeparatesNeighbors(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,1,.4,-1);
            N.H=partial(N.H,1,2,.6,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.distribution.ClusterCount,2);
            testCase.verifyEqual(r.clusters.HorizontalCount,[1;1]);
        end
        function displacedPhaseAtBothEndsJoinsNeighbors(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,1,.4,1);
            N.H=partial(N.H,1,2,.6,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.distribution.ClusterCount,[0;1]);
            testCase.verifyEqual(r.clusters.ChannelCount,2);
        end
        function horizontalVerticalAndFullChannelJoin(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,1,.25,1);
            N.V=partial(N.V,2,1,.5,-1);
            N.H.State(1,2)=0; N.H.Sat(1,2)=0;
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.clusters{1,2:4},[3 2 1]);
            testCase.verifyEqual(r.composition{1,:},[3 2 1 1]);
            testCase.verifyEqual(r.distribution{3,1:4},[3 1 2 1]);
        end
        function verticalDirectionBreaksJunction(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,1,.25,1);
            N.V=partial(N.V,2,1,.5,1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.distribution.ClusterCount,2);
            testCase.verifyEqual(sort(r.clusters.HorizontalCount),[0;1]);
        end
        function zeroSaturationHasBothDisplacedEnds(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,1,0,-1);
            N.H=partial(N.H,1,2,.5,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.clusters.ChannelCount,2);
        end
        function closedStubsNeverCount(testCase)
            N=emptyNet(); N.V.State([1 end],:)=0; N.V.Sat([1 end],:)=0;
            r=displacedPhaseClusters(N);
            testCase.verifyEmpty(r.clusters);
            testCase.verifyEqual(r.poreVolume,16,'AbsTol',1e-12);
        end
        function externalReservoirDoesNotJoinRows(testCase)
            N=emptyNet(); N.H.State(:,1)=0; N.H.Sat(:,1)=0;
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.distribution.ClusterCount,2);
            testCase.verifyTrue(all(r.clusters.TouchesBoundary));
        end
        function openBottomIsOutlet(testCase)
            N=emptyNet(); N.VerticalBC=true;
            N.V=partial(N.V,3,1,.3,1);
            r=displacedPhaseClusters(N);
            testCase.verifyTrue(r.clusters.ConnectedToOutlet);
            testCase.verifyEqual(r.isolatedVolume,0,'AbsTol',1e-12);
            testCase.verifyEqual(r.poreVolume,24,'AbsTol',1e-12);
        end
        function volumeUsesActualAreasAndLengths(testCase)
            N=emptyNet(); N.H.A(1,1)=4;
            N.H=partial(N.H,1,1,.25,1);
            N.H=partial(N.H,1,3,.5,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.displacedVolume,7,'AbsTol',1e-12);
            testCase.verifyEqual(r.displacedSaturation,7/22,'AbsTol',1e-12);
            testCase.verifyEqual(sum(r.clusters.HorizontalCount+r.clusters.VerticalCount), ...
                height(r.channels));
            testCase.verifyEqual(sum(r.distribution.ChannelCount.*r.distribution.ClusterCount), ...
                height(r.channels));
        end
        function waterInjectionAnalyzesOilWithoutChangingNet(testCase)
            N=emptyNet(); N.displacingPhase='water';
            N.H=partial(N.H,1,1,.5,1); original=N;
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.displacedPhase,'oil');
            testCase.verifyEqual(N,original);
        end
        function invalidPartialDirectionRejected(testCase)
            N=emptyNet(); N.H=partial(N.H,1,1,.5,0);
            testCase.verifyError(@() displacedPhaseClusters(N),'displacedPhaseClusters:State');
        end
        function latestNumericSnapshotPrefersSolvedNet(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            Net=emptyNet(); step=9; elapsedTime=1;
            save(fullfile(fixture.Folder,'step_9.mat'),'Net','step','elapsedTime');
            solvedNet=Net; solvedNet.H=partial(solvedNet.H,1,1,.5,1);
            step=10; elapsedTime=2;
            save(fullfile(fixture.Folder,'step_10.mat'),'Net','solvedNet','step','elapsedTime');
            r=analyzeResidualSaturation(fixture.Folder);
            testCase.verifyEqual(r.step,10);
            testCase.verifyEqual(height(r.clusters),1);
            testCase.verifyTrue(isfile(fullfile(r.outputDirectory,'cluster_sizes.csv')));
            testCase.verifyTrue(isfile(fullfile(r.outputDirectory,'residual_saturation.mat')));
        end
        function corruptLatestDoesNotFallBack(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            Net=emptyNet(); step=1; elapsedTime=1;
            save(fullfile(fixture.Folder,'step_1.mat'),'Net','step','elapsedTime');
            save(fullfile(fixture.Folder,'step_2.mat'),'step');
            testCase.verifyError(@() analyzeResidualSaturation(fixture.Folder), ...
                'analyzeResidualSaturation:Snapshot');
        end
        function emptyNetworkHasEmptyHistogram(testCase)
            r=displacedPhaseClusters(emptyNet());
            testCase.verifyEmpty(r.distribution);
            testCase.verifyEqual(r.displacedSaturation,0,'AbsTol',1e-12);
        end
        function wholeRightConnectedClusterExcluded(testCase)
            N=emptyNet();
            N.H.State(1,:)=0; N.H.Sat(1,:)=0;
            N.V=partial(N.V,2,2,.5,-1);
            N.H=partial(N.H,2,1,.5,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(r.excludedRightConnectedClusterCount,1);
            testCase.verifyEqual(r.excludedRightConnectedChannelCount,4);
            testCase.verifyEqual(height(r.clusters),1);
            testCase.verifyEqual(height(r.channels),1);
            testCase.verifyEqual(r.channels.ClusterID,1);
            testCase.verifyEqual(r.displacedVolume,1,'AbsTol',1e-12);
            testCase.verifyEqual(r.excludedRightConnectedVolume,7,'AbsTol',1e-12);
        end
        function oilAtRightEndDoesNotExcludeCluster(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,3,.5,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEqual(height(r.clusters),1);
            testCase.verifyEqual(r.excludedRightConnectedClusterCount,0);
            testCase.verifyFalse(r.clusters.ConnectedToOutlet);
        end
        function displacedPhaseAtRightEndExcludesPartialChannel(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,3,.5,1);
            r=displacedPhaseClusters(N);
            testCase.verifyEmpty(r.clusters);
            testCase.verifyEmpty(r.channels);
            testCase.verifyEmpty(r.distribution);
            testCase.verifyEqual(r.excludedRightConnectedClusterCount,1);
        end
        function zeroSaturationAtRightEndIsExcluded(testCase)
            N=emptyNet();
            N.H=partial(N.H,1,3,0,-1);
            r=displacedPhaseClusters(N);
            testCase.verifyEmpty(r.clusters);
            testCase.verifyEqual(r.excludedRightConnectedChannelCount,1);
        end
    end
end

function N=emptyNet()
N=struct('L',2,'VerticalBC',false);
N.H=struct('A',ones(2,3),'Sat',ones(2,3),'State',2*ones(2,3),'Dir',zeros(2,3));
N.V=struct('A',ones(3,2),'Sat',ones(3,2),'State',2*ones(3,2),'Dir',zeros(3,2));
end

function cap=partial(cap,row,col,sat,direction)
cap.State(row,col)=1; cap.Sat(row,col)=sat; cap.Dir(row,col)=direction;
end
