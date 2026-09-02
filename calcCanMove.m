%% Разрешено ли мениску движение (Net.Move)
%
% Функция определяет, может ли мениск продолжить движение в следующем
% динамическом шаге. 
% Условие - связность водной фазы либо правая граница.
% Связность определяется основной функцией calcWaterConnectivity()

function Net = calcCanMove(Net)

    oldMoveH = Net.MoveH;
    oldMoveV = Net.MoveV;
    
    Net.MoveH = zeros(size(Net.StateH));
    Net.MoveV = zeros(size(Net.StateV));
    
    % Ранее заблокированные капилляры остаются заблокированными
    Net.MoveH(oldMoveH==2) = 2;
    Net.MoveV(oldMoveV==2) = 2;
    
    % Определение связности водяной фазы
    [WaterConnectedH, WaterConnectedV] = calcWaterConnectivity(Net);
    
    %%-------------------------------------------------------
    %% Горизонтальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:size(Net.StateH,1)
        for j = 1:size(Net.StateH,2)
            if Net.StateH(i,j)~=1 % пропуск, нет мениска
                continue
            end
            if oldMoveH(i,j)==2 % пропуск, заблокирован
                continue
            end
            
            move = false;
            
            if Net.Qh(i,j) > 0 % движение вправо
                if j == size(Net.StateH,2) % правая граница - выход
                    move = true;
                elseif WaterConnectedH(i,j+1)
                    move = true;
                elseif i <= size(Net.StateV,1) &&  WaterConnectedV(i,j)
                    move = true;
                elseif i > 1 && WaterConnectedV(i-1,j)
                    move = true;
                end
            elseif Net.Qh(i,j) < 0 % движение влево
                if j>1 && WaterConnectedH(i,j-1)
                    move = true;
                elseif i > 1 && WaterConnectedV(i-1,j-1)
                    move = true;
                elseif i <= size(Net.StateV,1) && WaterConnectedV(i,j-1)
                    move = true;
                end
            end
            
            if move
                Net.MoveH(i,j)=1;
            else
                Net.MoveH(i,j)=2;
            end
        end
    end
    
    
    %%-------------------------------------------------------
    %% Вертикальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:size(Net.StateV,1)
        for j = 1:size(Net.StateV,2)
            if Net.StateV(i,j)~=1 % пропуск, нет мениска
                continue
            end
            if oldMoveV(i,j)==2 % пропуск, заблокирован
                continue
            end
            
            move = false;
            
            if Net.Qv(i,j)>0 % движение вниз
                if i < size(Net.StateV,1) && WaterConnectedV(i+1,j)
                    move = true;
                elseif WaterConnectedH(i+1,j) || WaterConnectedH(i+1,j+1)
                    move = true;
                end
            elseif Net.Qv(i,j)<0 % движение вверх
                if i > 1 && WaterConnectedV(i-1,j)
                    move = true;
                elseif WaterConnectedH(i,j) || WaterConnectedH(i,j+1)
                    move = true;
                end
            end
            
            if move
                Net.MoveV(i,j)=1;
            else
                Net.MoveV(i,j)=2;
            end
        end
    end
end