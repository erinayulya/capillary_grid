%% Обновление состояния движения менисков (Net.Move)
%
% Move = 0: нет мениска (State ~= 1);
% Move = 1: движение разрешено по связности; знак dp проверит решатель;
% Move = 2: мениск защемлен из-за потери связности по воде;
% Move = 3: окончательный код удержания задаётся только решателем.
%
% Входные Move=1/3 проверяются одинаково, без чтения давления.
% Мениск с Move = 2 остается защемленным.
% Условие движения - связность водной фазы либо правая граница.
% Связность определяется основной функцией calcWaterConnectivity()

function Net = calcCanMove(Net)

    oldMoveH = Net.H.Move;
    oldMoveV = Net.V.Move;
    
    % Move=1 здесь означает только допуск к проверке давления решателем.
    % После проверки связности недопустимые мениски получают Move=2.
    Net.H.Move = double(Net.H.State == 1);
    Net.V.Move = double(Net.V.State == 1);
    
    % Ранее заблокированные капилляры остаются заблокированными
    Net.H.Move((oldMoveH==2) & (Net.H.State==1)) = 2;
    Net.V.Move((oldMoveV==2) & (Net.V.State==1)) = 2;
    
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
            
            dir = Net.H.Dir(i,j);
            move = false;
            if dir > 0
                if j == 1
                    move = true;
                elseif j == Net.H.Nx
                    move = true;
                elseif WaterConnectedH(i,j+1) || ...
                        WaterConnectedV(i,j) || ...
                        WaterConnectedV(i+1,j)
                    move = true;
                end
            elseif dir < 0
                if j > 1 && (WaterConnectedH(i,j-1) || ...
                        WaterConnectedV(i,j-1) || ...
                        WaterConnectedV(i+1,j-1))
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
            if ~Net.VerticalBC && (i == 1 || i == Net.V.Ny)
                % Закрытый граничный капилляр не может быть подвижным.
                Net.V.Move(i,j)=2;
                continue
            end
            if oldMoveV(i,j)==2 % пропуск, заблокирован
                continue
            end
            
            dir = Net.V.Dir(i,j);
            move = false;
            if dir > 0
                if i == Net.V.Ny
                    move = true;
                elseif WaterConnectedV(i+1,j) || ...
                        WaterConnectedH(i,j) || WaterConnectedH(i,j+1)
                    move = true;
                end
            elseif dir < 0
                if i == 1
                    move = true;
                elseif WaterConnectedV(i-1,j) || ...
                        WaterConnectedH(i-1,j) || WaterConnectedH(i-1,j+1)
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
