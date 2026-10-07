%% Обновление состояний капилляров (Net.State)
%
% Функция ищет капилляры, которые находятся в процессе заполнения
% и чья насыщенность достигла 100%. Для такого капилляра 
% меняются: state=1 -> state=2.
% Затем на каждом вызове проверяются все узлы с нефтью: в водяных
% соседях создаётся мениск, если расход направлен от такого узла.

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
            end
        end
    end

    % Нефть у внутреннего узла: State=2 с любого конца либо State=1
    % со стороны входа мениска (Dir), в том числе при Sat=0.
    % Маска строится до создания новых менисков; индексы как у Net.P.
    oilNodes = ...
        Net.H.State(:,1:end-1)==2 | ...
        (Net.H.State(:,1:end-1)==1 & Net.H.Dir(:,1:end-1)<0) | ...
        Net.H.State(:,2:end)==2 | ...
        (Net.H.State(:,2:end)==1 & Net.H.Dir(:,2:end)>0) | ...
        Net.V.State(1:end-1,:)==2 | ...
        (Net.V.State(1:end-1,:)==1 & Net.V.Dir(1:end-1,:)<0) | ...
        Net.V.State(2:end,:)==2 | ...
        (Net.V.State(2:end,:)==1 & Net.V.Dir(2:end,:)>0);
    [rows,cols] = find(oilNodes);
    for k = 1:numel(rows)
        Net = processNode(Net,rows(k),cols(k)+1);
    end
end


%% Продвижение мениска из узла
%
% Для узла с нефтью функция проверяет всех водяных соседей на каждом шаге.
% Если сосед заполнен только вытесняемой фазой и расход направлен
% от узла с мениском, то мениск создается. 
% Меняется: state=0 -> state=1.

function Net = processNode(Net,row,col)

    %-------------------------------------------------------
    % Горизонтальный вправо
    %-------------------------------------------------------
    if row >= 1 && row <= Net.H.Ny && ...
            col >= 1 && col <= Net.H.Nx
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
    if row >= 1 && row <= Net.H.Ny && col > 1
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
    if row < Net.V.Ny && col > 1 && col-1 <= Net.V.Nx
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
    if row >= 1 && col > 1 && col-1 <= Net.V.Nx
        if Net.V.State(row,col-1) == 0 && Net.V.Q(row,col-1) < 0
            Net.V.State(row,col-1) = 1;
            Net.V.Sat(row,col-1) = 0;
            Net.V.Move(row,col-1) = 3;
            Net.V.Dir(row,col-1) = -1;
            Net.V.Regime(row,col-1) = 0;
        end
    end
end
