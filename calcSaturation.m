%% Обновление сатураций
%
% Функция пересчитывает сатурации для капилляров с мениском, по которым
% разрешено движение. За динамический шаг dt мениск продвигается на:
% l = l + dt*v, 
% где v = Q/A, Q - расход в капилляре из предыдущего шага.
% Сатурация увеличивается:
% Sat = Sat + dt*v/L

function Net = calcSaturation(Net)

    %%-------------------------------------------------------
    %% Горизонтальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:size(Net.StateH,1)
        for j = 1:size(Net.StateH,2)
            if Net.StateH(i,j)==1 && Net.MoveH(i,j)==1
                v = abs(Net.Qh(i,j))/Net.Ah(i,j);
                Net.SatH(i,j) = min(...
                    1,...
                    Net.SatH(i,j)+v*Net.dt/Net.L...
                );
            end
        end
    end

    %%-------------------------------------------------------
    %% Вертикальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:size(Net.StateV,1)
        for j = 1:size(Net.StateV,2)
            if Net.StateV(i,j)==1 && Net.MoveV(i,j)==1
                v = abs(Net.Qv(i,j))/Net.Av(i,j);
                Net.SatV(i,j) = min(...
                    1,...
                    Net.SatV(i,j)+v*Net.dt/Net.L);
            end
        end
    end
end