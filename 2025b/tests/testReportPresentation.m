classdef testReportPresentation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'reporting')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'visualization')));
        end
    end
    methods (Test)
        function closedBoundariesDoNotListInactivePressures(testCase)
            N = reportNet(); N.VerticalBC = false;
            p = simulationReportPresentation(N,struct());
            text = strjoin(p.boundaryLines,newline);
            testCase.verifyFalse(contains(text,'на верхней границе'));
            testCase.verifyFalse(contains(text,'справа и снизу'));
            testCase.verifyTrue(contains(text,'Давление справа: 0 Па'));
        end
        function openBoundariesListBothPressures(testCase)
            N = reportNet(); N.VerticalBC = true;
            p = simulationReportPresentation(N,struct());
            text = strjoin(p.boundaryLines,newline);
            testCase.verifyTrue(contains(text,'на верхней границе'));
            testCase.verifyTrue(contains(text,'справа и снизу'));
        end
        function disabledUiOptionsHideUnusedCoefficients(testCase)
            N = reportNet();
            options = struct('includeAadd',false,'meniscusModel',1);
            p = simulationReportPresentation(N,struct(),options);
            text = strjoin(p.modelLines,newline);
            testCase.verifyTrue(contains(text,'Учет A_add отключен'));
            testCase.verifyTrue(contains(text,'один режим (вязкий)'));
            testCase.verifyFalse(contains(text,'Коэффициент плато'));
            testCase.verifyFalse(contains(text,'P_crit'));
            testCase.verifyFalse(contains(text,'xi'));
            testCase.verifyEqual(p.modelOptions.meniscusModel,1);
        end
        function oldViscousRunIsRecognizedWithoutUi(testCase)
            N = reportNet(); N.coef = 0; N.P_crit_width = 0; N.xi = 0;
            p = simulationReportPresentation(N,struct());
            testCase.verifyEqual(p.modelOptions.meniscusModel,1);
            testCase.verifyFalse(p.modelOptions.includeAadd);
        end
        function savedOptionsAndLatestGifAreRestored(testCase)
            result = struct('reportModelOptions',struct('includeAadd',false, ...
                'meniscusModel',1,'showMeniscus',true),'gifShowMeniscus',false);
            p = simulationReportPresentation(reportNet(),result);
            testCase.verifyFalse(p.modelOptions.includeAadd);
            testCase.verifyEqual(p.modelOptions.meniscusModel,1);
            testCase.verifyFalse(p.modelOptions.showMeniscus);
        end
        function meniscusPressureIsIndependentOfCriticalThreshold(testCase)
            N = reportNet(); original = N;
            p = simulationReportPresentation(N,struct());
            expected = 2*N.sigma*cos(N.theta)/1e-4;
            testCase.verifyEqual(p.PcapH,expected*ones(2,3),'RelTol',1e-12);
            N.coef = 0; N.P_crit_width = 0;
            other = simulationReportPresentation(N,struct());
            testCase.verifyEqual(other.PcapH,p.PcapH);
            testCase.verifyEqual(other.PcapV,p.PcapV);
            testCase.verifyEqual(original.H.A,N.H.A);
        end
        function adaptiveHalfPageLayout(testCase)
            pageSize = [595.28 841.89];
            slots = [.095 .52 .81 .38;.095 .14 .81 .38];
            small = reportNetworkLayout(3,3,slots,pageSize);
            medium = reportNetworkLayout(7,6,slots,pageSize);
            testCase.verifyGreaterThan(medium.axesPositions(1,3),small.axesPositions(1,3));
            testCase.verifyEqual(small.cellPitchPoints,32);
            testCase.verifyGreaterThanOrEqual(medium.nodeDiameterPoints,8);
            for dimensions = [3 3;7 6;30 20;200 200]'
                fitted = reportNetworkLayout(dimensions(1),dimensions(2),slots,pageSize);
                for index = 1:2
                    box = fitted.axesPositions(index,:);
                    testCase.verifyGreaterThanOrEqual(box(1:2),slots(index,1:2));
                    testCase.verifyLessThanOrEqual(box(1:2)+box(3:4), ...
                        slots(index,1:2)+slots(index,3:4));
                end
                testCase.verifyEqual(fitted.axesPositions(1,3:4),fitted.axesPositions(2,3:4));
                testCase.verifyLessThanOrEqual(fitted.nodeDiameterPoints,.60*fitted.cellPitchPoints);
                testCase.verifyGreaterThan(fitted.axesPositions(1,2),fitted.axesPositions(2,2));
            end
        end
        function reportArtworkContainsVectorObjects(testCase)
            N = reportNet();
            fig = figure('Visible','off','IntegerHandle','off');
            cleanup = onCleanup(@() close(fig));
            snapshot = struct('step',3,'elapsedTime',0.2);
            frame = drawSaturationPressureFrame(fig,N,snapshot,2,4,[50 100],false,[],[.1 .2 .8 .6]);
            testCase.verifyEmpty(findall(fig,'Type','image'));
            testCase.verifyEmpty(findall(fig,'Type','uipanel'));
            testCase.verifyEqual(frame.pressure.CData,N.P(:));
            testCase.verifyTrue(strcmp(frame.menisci.Visible,'off'));
            testCase.verifyEqual(numel(findall(fig,'Type','axes')),2);
            drawnow;
            saturationAxes = ancestor(frame.water,'axes');
            pressureAxes = ancestor(frame.pressure,'axes');
            testCase.verifyEqual(saturationAxes.InnerPosition(3:4), ...
                pressureAxes.InnerPosition(3:4),'AbsTol',1e-12);
            testCase.verifyEqual(saturationAxes.InnerPosition(2), ...
                pressureAxes.InnerPosition(2),'AbsTol',1e-12);
        end
    end
end

function N = reportNet()
N = struct('mu1',1e-3,'mu2',4.3e-3,'L',9e-3,'sigma',7e-2,'theta',pi/4, ...
    'VerticalBC',false,'k',3.29015,'xi',30.079341699546497, ...
    'coef',6.644123616564944e-4,'P_crit_width',4,'P',[100 50;100 50]);
N.H = struct('A',pi*1e-8*ones(2,3),'Ny',2,'Nx',3,'P0',1500, ...
    'Sat',zeros(2,3),'State',zeros(2,3),'Dir',zeros(2,3));
N.V = struct('A',pi*1e-8*ones(3,2),'Ny',3,'Nx',2,'P0',200, ...
    'Sat',zeros(3,2),'State',zeros(3,2),'Dir',zeros(3,2));
end
