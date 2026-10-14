%% Расчет динамического шага (Net.dt)
%
% Шаг — минимум аналитических вязких оценок времени до заполнения.
% Локальный перепад фиксирован; Q и Regime для оценки не используются.
% Насыщенность по-прежнему обновляется по фактическому Q в calcSaturation.

function Net = calcTimeStep(Net)

    dpH = [Net.H.P0*ones(Net.H.Ny,1),Net.P] - ...
        [Net.P,zeros(Net.H.Ny,1)];
    dpV = [Net.V.P0*ones(1,Net.V.Nx);Net.P] - ...
        [Net.P;zeros(1,Net.V.Nx)];
    tminH = calcTimeStepEval(Net.H, Net, dpH);
    tminV = calcTimeStepEval(Net.V, Net, dpV);
    
    Net.dt = min(tminH, tminV);

    % Предупреждение об остановке нужно только до достижения выхода.
    if isinf(Net.dt) && ~any(Net.H.State(:,end)==2)
        hasMovingH = any(Net.H.Move(:) == 1);
        hasMovingV = any(Net.V.Move(:) == 1);
        if ~hasMovingH && ~hasMovingV
            warning('Подвижных капилляров нет. Все заблокированы или давления не хватает.');
        end
    end
end


function tmin = calcTimeStepEval(Cap, Net, dp)

    tmin = Inf;
    for i = 1:Cap.Ny
        for j = 1:Cap.Nx
            if Cap.State(i,j)==1 && Cap.Move(i,j)==1
                A = Cap.A(i,j);
                S = Cap.Sat(i,j);
    
                p = Cap.Dir(i,j)*dp(i,j);
                if S < 1-1e-12 && p > 0
                    r = sqrt(A/pi);
                    Aadd = Net.xi*(Net.mu1+Net.mu2)/r;
                    t = Net.L*(1-S)/p*(4*Net.L/r^2* ...
                        (Net.mu1*(1-S)+Net.mu2*(1+S))+Aadd);
                    tmin = min(tmin,t);
                end
            end
        end
    end
end
