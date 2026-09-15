%% Обновление состояния движения менисков (Net.Move)
%
% Move = 0: нет мениска (State ~= 1);
% Move = 1: мениск подвижен;
% Move = 2: мениск защемлен из-за потери связности по воде;
% Move = 3: мениск временно удерживается, так как dP <= Pc.
%
% Мениск с Move = 3 проверяется заново на каждом шаге и может перейти
% в Move = 1. Мениск с Move = 2 остается защемленным.
% Условие движения - связность водной фазы либо правая граница.
% Связность определяется основной функцией calcWaterConnectivity()

function Net = calcCanMove(Net)

    oldMoveH = Net.H.Move;
    oldMoveV = Net.V.Move;
    
    % Move = 0 оставляется только капиллярам без мениска. Все мениски
    % по умолчанию считаются временно удержанными, пока не пройдут
    % проверки связности и капиллярного порога.
    Net.H.Move = 3*(Net.H.State == 1);
    Net.V.Move = 3*(Net.V.State == 1);
    
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
        
            if dir > 0
                if j == 1
                    dP = Net.H.P0 - Net.P(i,1);
                elseif j == Net.H.Nx
                    dP = Net.P(i,j-1);
                else
                    dP = Net.P(i,j-1) - Net.P(i,j);
                end
            else
                if j == 1
                    dP = Net.P(i,1) - Net.H.P0;
                elseif j == Net.H.Nx
                    dP = -Net.P(i,j-1);
                else
                    dP = Net.P(i,j) - Net.P(i,j-1);
                end
            end

            Pc = 2*Net.sigma*cos(Net.theta)/sqrt(Net.H.A(i,j)/pi);
            if move && dP > Pc
                Net.H.Move(i,j)=1;
            elseif move
                Net.H.Move(i,j)=3;
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

            if dir > 0
                if i == 1
                    dP = Net.V.P0 - Net.P(1,j);
                elseif i == Net.V.Ny
                    dP = Net.P(i-1,j);
                else
                    dP = Net.P(i-1,j) - Net.P(i,j);
                end
            else
                if i == 1
                    dP = Net.P(1,j) - Net.V.P0;
                elseif i == Net.V.Ny
                    dP = -Net.P(i-1,j);
                else
                    dP = Net.P(i,j) - Net.P(i-1,j);
                end
            end

            Pc = 2*Net.sigma*cos(Net.theta)/sqrt(Net.V.A(i,j)/pi);
            if move && dP > Pc
                Net.V.Move(i,j)=1;
            elseif move
                Net.V.Move(i,j)=3;
            else
                Net.V.Move(i,j)=2;
            end
        end
    end
end
