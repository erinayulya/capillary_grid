function Net = calcCanMove(Net)

    oldMoveH = Net.MoveH;
    oldMoveV = Net.MoveV;
    
    Net.MoveH = zeros(size(Net.StateH));
    Net.MoveV = zeros(size(Net.StateV));
    
    Net.MoveH(oldMoveH==2) = 2;
    Net.MoveV(oldMoveV==2) = 2;
    
    [WaterConnectedH, WaterConnectedV] = calcWaterConnectivity(Net);
    
    
    %% Горизонтальные капилляры
    
    for i = 1:size(Net.StateH,1)
        for j = 1:size(Net.StateH,2)
        
            if Net.StateH(i,j)~=1
                continue
            end
            
            if oldMoveH(i,j)==2
                continue
            end
            
            move = false;
            
            if j == size(Net.StateH,2)
                move = true;
            elseif WaterConnectedH(i,j+1)
                move = true;
            end
            
            if move
                Net.MoveH(i,j)=1;
            else
                Net.MoveH(i,j)=2;
            end
        
        end
    end
    
    
    %% Вертикальные капилляры
    
    for i = 1:size(Net.StateV,1)
        for j = 1:size(Net.StateV,2)
        
            if Net.StateV(i,j)~=1
                continue
            end
            
            if oldMoveV(i,j)==2
                continue
            end
            
            move = false;
            
            if Net.Qv(i,j)>0
            
                if i < size(Net.StateV,1)
                    if WaterConnectedV(i+1,j)
                        move = true;
                    end
                end
            
            elseif Net.Qv(i,j)<0
            
                if i > 1
                    if WaterConnectedV(i-1,j)
                        move = true;
                    end
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