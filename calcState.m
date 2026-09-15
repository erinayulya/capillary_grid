%% Обновление состояний капилляров (Net.State)
%
% Функция ищет капилляры, которые находятся в процессе заполнения
% и чья насыщенность достигла 100%. Для такого капилляра 
% меняются: state=1 -> state=2.
% После в processNode() определяется, в каких соседних капиллярах
% на входе нужно создать мениск.

function Net = calcState(Net)

    tol = 1e-12;
    
    %%-------------------------------------------------------
    %% Горизонтальные капилляры
    %%-------------------------------------------------------
    
    for i = 1:Net.H.Ny
        for j = 1:Net.H.Nx
            if Net.H.State(i,j)==1 && Net.H.Sat(i,j)>=1-tol
                Net.H.State(i,j)=2;
                Net.H.Sat(i,j)=1;
                Net.H.Move(i,j)=0;
                Net.H.Dir(i,j)=0;
                Net.H.Regime(i,j)=0;
                
                nodeRow=i;
                if Net.H.Q(i,j)>=0
                    nodeCol=j+1;
                    from='L'; % from left side
                else
                    nodeCol=j;
                    from='R'; % from right side
                end
                Net=processNode(Net,nodeRow,nodeCol,from);
            end
        end
    end
    
    %%-------------------------------------------------------
    %% Вертикальные капилляры
    %%-------------------------------------------------------
    
    for i=1:Net.V.Ny
        for j=1:Net.V.Nx
            if Net.V.State(i,j)==1 && Net.V.Sat(i,j)>=1-tol
                Net.V.State(i,j)=2;
                Net.V.Sat(i,j)=1;
                Net.V.Move(i,j)=0;
                Net.V.Dir(i,j)=0;
                Net.V.Regime(i,j)=0;
                if Net.V.Q(i,j)>=0
                    nodeRow=i;
                    nodeCol=j+1;
                    from='U'; % from upper
                else
                    nodeRow=i-1;
                    nodeCol=j+1;
                    from='D'; % from down
                end
                Net=processNode(Net,nodeRow,nodeCol,from);
            end
        end
    end
end


%% Продвижение мениска из узла
%
% Для капилляра, у которого мениск продвинулся к выходному узлу,
% функция определеяет, у каких из трех соседей нужно на входе создать
% мениск. Если сосед заполнен только вытесняемой фазой и расход направлен 
% от узла с мениском, то мениск создается. 
% Меняется: state=0 -> state=1.

function Net = processNode(Net,row,col,from)

    %-------------------------------------------------------
    % Горизонтальный вправо
    %-------------------------------------------------------
    if row >= 1 && row <= Net.H.Ny && ...
            col >= 1 && col <= Net.H.Nx && from ~= 'R'
        if Net.H.State(row,col) == 0 && Net.H.Q(row,col) > 0
            Net.H.State(row,col) = 1;
            Net.H.Sat(row,col) = 0;
            Net.H.Move(row,col) = 3;
            Net.H.Dir(row,col) = 1;
            Net.H.Regime(row,col) = 0;
        end
    end

    %-------------------------------------------------------
    % Горизонтальный влево
    %-------------------------------------------------------
    if row >= 1 && row <= Net.H.Ny && col > 1 && from ~= 'L'
        if Net.H.State(row,col-1) == 0 && Net.H.Q(row,col-1) < 0
            Net.H.State(row,col-1) = 1;
            Net.H.Sat(row,col-1) = 0;
            Net.H.Move(row,col-1) = 3;
            Net.H.Dir(row,col-1) = -1;
            Net.H.Regime(row,col-1) = 0;
        end
    end

    %-------------------------------------------------------
    % Вертикальный вниз
    %-------------------------------------------------------
    if row < Net.V.Ny && col > 1 && col-1 <= Net.V.Nx && from ~= 'D'
        if Net.V.State(row+1,col-1) == 0 && Net.V.Q(row+1,col-1) > 0
            Net.V.State(row+1,col-1) = 1;
            Net.V.Sat(row+1,col-1) = 0;
            Net.V.Move(row+1,col-1) = 3;
            Net.V.Dir(row+1,col-1) = 1;
            Net.V.Regime(row+1,col-1) = 0;
        end
    end

    %-------------------------------------------------------
    % Вертикальный вверх
    %-------------------------------------------------------
    if row >= 1 && col > 1 && col-1 <= Net.V.Nx && from ~= 'U'
        if Net.V.State(row,col-1) == 0 && Net.V.Q(row,col-1) < 0
            Net.V.State(row,col-1) = 1;
            Net.V.Sat(row,col-1) = 0;
            Net.V.Move(row,col-1) = 3;
            Net.V.Dir(row,col-1) = -1;
            Net.V.Regime(row,col-1) = 0;
        end
    end
end
