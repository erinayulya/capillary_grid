classdef calcStateBirthToleranceTest < matlab.unittest.TestCase
    % Numerical flow noise must not create a meniscus or alter solved Q.
    properties (TestParameter)
        branch = struct( ...
            'right',struct('key','H','row',2,'col',3,'direction',1,'oil','V'), ...
            'left',struct('key','H','row',2,'col',2,'direction',-1,'oil','V'), ...
            'down',struct('key','V','row',3,'col',2,'direction',1,'oil','H'), ...
            'up',struct('key','V','row',2,'col',2,'direction',-1,'oil','H'))
        flow = struct( ...
            'zero',struct('factor',0,'state',0), ...
            'belowTolerance',struct('factor',0.5,'state',0), ...
            'atTolerance',struct('factor',1,'state',0), ...
            'aboveTolerance',struct('factor',2,'state',1))
        flowScale = {1e-8,1e-20}
    end
    methods (TestClassSetup)
        function modelPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'model')));
        end
    end
    methods (Test)
        function birthRequiresResolvedDirection(testCase,branch,flow,flowScale)
            N = blankNet();
            N.(branch.oil).State(2,2) = 2;
            N.(branch.oil).Sat(2,2) = 1;
            N.H.Q(1,1) = flowScale;
            N.(branch.key).Q(branch.row,branch.col) = ...
                branch.direction*flow.factor*64*eps(flowScale);

            actual = calcState(N);

            testCase.verifyEqual(actual.(branch.key).State(branch.row,branch.col),flow.state);
            testCase.verifyEqual(actual.(branch.key).Dir(branch.row,branch.col), ...
                branch.direction*flow.state);
            testCase.verifyEqual(actual.(branch.key).Move(branch.row,branch.col),3*flow.state);
            testCase.verifyEqual(actual.(branch.key).Sat(branch.row,branch.col),0,'AbsTol',eps);
            testCase.verifyEqual(actual.H.Q,N.H.Q,'AbsTol',0);
            testCase.verifyEqual(actual.V.Q,N.V.Q,'AbsTol',0);
        end
        function allZeroFlowsPreserveWaterNeighbours(testCase)
            N = blankNet();
            N.H.State(2,2) = 2;
            N.H.Sat(2,2) = 1;

            actual = calcState(N);

            testCase.verifyEqual(actual,N);
        end
    end
end

function N = blankNet()
N = struct();
N.H.A = ones(3,4); N.V.A = ones(4,3);
for key = {'H','V'}
    name = key{1};
    [N.(name).Ny,N.(name).Nx] = size(N.(name).A);
    for field = {'State','Sat','Move','Dir','Regime','Q'}
        N.(name).(field{1}) = zeros(size(N.(name).A));
    end
end
end
