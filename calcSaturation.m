%% Обновление сатураций (Net.Sat)
%
% Функция пересчитывает сатурации для капилляров с мениском, по которым
% разрешено движение. За динамический шаг dt мениск продвигается на:
% l = l + dt*v, 
% где v = Q/A, Q - расход в капилляре из предыдущего шага.
% Сатурация увеличивается:
% Sat = Sat + dt*v/L

function Net = calcSaturation(Net)
    Net.H = calcSaturationEval(Net.H, Net.dt, Net.L);
    Net.V = calcSaturationEval(Net.V, Net.dt, Net.L);
end


function Net = calcSaturationEval(Net, dt, L)
    [Ny, Nx] = size(Net.A);
    for i = 1:Ny
        for j = 1:Nx
            if Net.State(i,j) == 1 && Net.Move(i,j) == 1
                v = abs(Net.Q(i,j)) / Net.A(i,j);
                Net.Sat(i,j) = min(...
                    1, ...
                    Net.Sat(i,j) + v * dt / L);
            end
        end
    end
end