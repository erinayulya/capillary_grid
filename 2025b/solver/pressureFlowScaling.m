%% Масштабирование давлений, расходов и невязок
%
% Все активные уравнения записаны в м3/с, включая вязкую ветвь.

function [xScale,fScale] = pressureFlowScaling(Net,idxP,idxQH,idxQV)

    pScale = 1e3; % Па
    qScale = 1e-11; % м3/с

    n = numel(idxP)+numel(idxQH)+numel(idxQV);
    xScale = qScale*ones(n,1);
    xScale(idxP(:)) = pScale;
    fScale = qScale*ones(n,1);

end
