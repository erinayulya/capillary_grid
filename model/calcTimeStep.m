%% Расчет динамического шага (Net.dt)
%
% Функция расчитывает динамический шаг моделирования вытеснения.
% Среды всех капилляров с мениском, для которых разрешено движение,
% рассчитывается время достижения мениска выхода.
% dt - минимальное такое время.

function Net = calcTimeStep(Net)

    tminH = calcTimeStepEval(Net.H, Net);
    tminV = calcTimeStepEval(Net.V, Net);
    
    Net.dt = min(tminH, tminV);

    % Если dt = Inf
    if isinf(Net.dt)
        hasMovingH = any(Net.H.Move(:) == 1);
        hasMovingV = any(Net.V.Move(:) == 1);
        if ~hasMovingH && ~hasMovingV
            warning('Подвижных капилляров нет. Все заблокированы или давления не хватает.');
        end
    end
end


function tmin = calcTimeStepEval(Cap, Net)

    tmin = Inf;
    for i = 1:Cap.Ny
        for j = 1:Cap.Nx
            if Cap.State(i,j)==1 && Cap.Move(i,j)==1
                A = Cap.A(i,j);
                S = Cap.Sat(i,j);
    
                if S < 1-1e-12
                    v = abs(Cap.Q(i,j))/A;
                    t = (1-S)*Net.L/v;
                    tmin = min(tmin,t);
                end
            end
        end
    end
end
