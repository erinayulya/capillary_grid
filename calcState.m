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
    
    for i = 1:Net.H.Nx
        for j = 1:Net.H.Ny
            if Net.H.State(i,j)==1 && Net.H.Sat(i,j)>=1-tol
                Net.H.State(i,j)=2;
                Net.H.Sat(i,j)=1;
                
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
    
    for i=1:Net.V.Nx
        for j=1:Net.V.Ny
            if Net.V.State(i,j)==1 && Net.V.Sat(i,j)>=1-tol
                Net.V.State(i,j)=2;
                Net.V.Sat(i,j)=1;
                if Net.V.Q(i,j)>=0
                    nodeRow=i+1;
                    nodeCol=j;
                    from='U'; % from upper
                else
                    nodeRow=i;
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
    if col <= Net.H.Ny && from ~= 'R'
        if Net.H.State(row,col) == 0 && Net.H.Q(row,col) > 0
            Net.H.State(row,col) = 1;
            Net.H.Sat(row,col) = 0;
        end
    end

    %-------------------------------------------------------
    % Горизонтальный влево
    %-------------------------------------------------------
    if col > 1 && from ~= 'L'
        if Net.H.State(row,col-1) == 0 && Net.H.Q(row,col-1) < 0
            Net.H.State(row,col-1) = 1;
            Net.H.Sat(row,col-1) = 0;
        end
    end

    %-------------------------------------------------------
    % Вертикальный вниз
    %-------------------------------------------------------
    if row <= Net.V.Nx && from ~= 'D'
        if Net.V.State(row,col) == 0 && Net.V.Q(row,col) > 0
            Net.V.State(row,col) = 1;
            Net.V.Sat(row,col) = 0;
        end
    end

    %-------------------------------------------------------
    % Вертикальный вверх
    %-------------------------------------------------------
    if row > 1 && from ~= 'U'
        if Net.V.State(row-1,col) == 0 && Net.V.Q(row-1,col) < 0
            Net.V.State(row-1,col) = 1;
            Net.V.Sat(row-1,col) = 0;
        end
    end
end