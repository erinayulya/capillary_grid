%% Масштабирование давлений, расходов и невязок
%
% Масштаб невязки выбирается по единицам уравнения: Па или м3/с.

function [xScale,fScale] = pressureFlowScaling(Net,idxP,idxQH,idxQV)

    pScale = 1e3; % Па
    qScale = 1e-11; % м3/с

    n = numel(idxP)+numel(idxQH)+numel(idxQV);
    xScale = qScale*ones(n,1);
    xScale(idxP(:)) = pScale;
    fScale = qScale*ones(n,1);

    pressureH = Net.H.State==1 & Net.H.Move==1 & ...
        (Net.H.Regime==2 | Net.H.Regime==3);
    pressureV = Net.V.State==1 & Net.V.Move==1 & ...
        (Net.V.Regime==2 | Net.V.Regime==3);

    if ~Net.VerticalBC
        pressureV([1,end],:) = false;
    end

    fScale(idxQH(pressureH)) = pScale;
    fScale(idxQV(pressureV)) = pScale;
end
