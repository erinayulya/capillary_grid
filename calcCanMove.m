%% Разрешено ли мениску движение (Net.Move)
%
% Функция определяет, может ли мениск продолжить движение в следующем
% динамическом шаге. 
% Условие - связность водной фазы либо правая граница.
% Связность определяется основной функцией calcWaterConnectivity()

function Net = calcCanMove(Net)

    oldMoveH = Net.H.Move;
    oldMoveV = Net.V.Move;
    
    Net.H.Move = zeros(size(Net.H.State));
    Net.V.Move = zeros(size(Net.V.State));
    
    % Ранее заблокированные капилляры остаются заблокированными
    Net.H.Move(oldMoveH==2) = 2;
    Net.V.Move(oldMoveV==2) = 2;
    
    % Определение связности водяной фазы
    [WaterConnectedH, WaterConnectedV] = calcWaterConnectivity(Net);

    %%-------------------------------------------------------
    %% Горизонтальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:Net.H.Ny
        for j = 1:Net.H.Nx
            if Net.H.State(i,j)~=1 % пропуск, нет мениска
                continue
            end
            if oldMoveH(i,j)==2 % пропуск, заблокирован
                continue
            end
            
            move = false;
            
            if Net.H.Q(i,j) > 0 % движение вправо
                if j == Net.H.Nx % правая граница - выход
                    move = true;
                elseif WaterConnectedH(i,j+1)
                    move = true;
                elseif i <= Net.V.Ny &&...
                       j <= Net.V.Nx && WaterConnectedV(i,j)
                    move = true;
                elseif i > 1 && WaterConnectedV(i-1,j)
                    move = true;
                end
            
            elseif Net.H.Q(i,j) < 0 % движение влево
                if j > 1 && WaterConnectedH(i,j-1)
                    move = true;
                elseif i <= Net.V.Ny && WaterConnectedV(i,j-1)
                    move = true;
                elseif i > 1 && WaterConnectedV(i-1,j-1)
                    move = true;
                end
            end
        
            if move
                Net.H.Move(i,j)=1;
            else
                Net.H.Move(i,j)=2;
            end
        end
    end


    %%-------------------------------------------------------
    %% Вертикальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:Net.V.Ny
        for j = 1:Net.V.Nx
            if Net.V.State(i,j)~=1 % пропуск, нет мениска
                continue
            end
            if oldMoveV(i,j)==2 % пропуск, заблокирован
                continue
            end
            
            move = false;
            
            if Net.V.Q(i,j)>0 % движение вниз
                if i == Net.V.Ny % нижняя граница - выход
                    move = true;
                elseif WaterConnectedV(i+1,j)
                    move = true;
                elseif i <= Net.H.Ny && ...
                        (WaterConnectedH(i,j) || WaterConnectedH(i,j+1))
                    move = true;
                end
            
            elseif Net.V.Q(i,j)<0 % движение вверх
                if i == 1 % верхняя граница - вход
                    move = true;
                elseif WaterConnectedV(i-1,j)
                    move = true;
                elseif i-1 <= Net.H.Ny && ...
                        (WaterConnectedH(i-1,j) || WaterConnectedH(i-1,j+1))
                    move = true;
                end
            end
            
            if move
                Net.V.Move(i,j)=1;
            else
                Net.V.Move(i,j)=2;
            end
        end
    end
end