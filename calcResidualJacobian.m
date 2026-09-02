%% Якобиан и невязка системы уравнений
% 
% Функция возвращает вектор невязок F и Якобиан J системы уравнений для 
% текущего приближения решения.
% Система состоит из уравнений 2 видов:
% (1) Баланс расходов в узле: Q_left - Q_right + Q_up - Q_down = 0
% (2) Зависимость расхода от давления на каждом капилляре: Q = f(dp)
% Якобиан содержит производные невязок по давлениям и расходам.
% Вид уравнения для капилляра определяется функцией capillaryEquation().

function [F,J] = calcResidualJacobian(...
    Net,X,idxP,idxQH,idxQV)
    
    % Подготовка массивов
    Ny = Net.Ny;
    Nx = Net.Nx;
    
    nP = Ny*(Nx-1);
    nQH = Ny*Nx;
    nQV = (Ny-1)*(Nx-1);
    n = nP+nQH+nQV; % число неизвестных

    F = zeros(n,1); % вектор невязок

    % Якобиан:
    % J(rowIdx, colIdx) = jacVal
    rowIdx = []; % номер строки
    colIdx = []; % номер столбца
    jacVal = []; % значение элемента Якобиана

    % X = [P Qh Qv] - вектор всех неизвестных
    
    %%-------------------------------------------------------
    %% Баланс в узле 
    %%-------------------------------------------------------
    % F_node = Q_left - Q_right + Q_up - Q_down
    for i = 1:Ny
        for j = 2:Nx
            row = idxP(i,j-1); % номер уравнения баланса

            % Поток слева к узлу
            q = X(idxQH(i,j-1));
            F(row) = F(row)+q;
            rowIdx(end+1) = row;
            colIdx(end+1) = idxQH(i,j-1);
            jacVal(end+1) = 1;
    
            % Поток справа
            q = X(idxQH(i,j));
            F(row) = F(row)-q;
            rowIdx(end+1) = row;
            colIdx(end+1) = idxQH(i,j);
            jacVal(end+1) = -1;
    
            % Поток вверх
            if i>1 
                q = X(idxQV(i-1,j-1));
                F(row) = F(row)+q;
                rowIdx(end+1) = row;
                colIdx(end+1) = idxQV(i-1,j-1);
                jacVal(end+1) = 1;
            end
    
            % Поток вниз
            if i<Ny
                q = X(idxQV(i,j-1));
                F(row) = F(row)-q;
                rowIdx(end+1) = row;
                colIdx(end+1) = idxQV(i,j-1);
                jacVal(end+1) = -1;
            end
        end
    end
    
    %%-------------------------------------------------------
    %% Уравнение Q = f(dp) в капилляре
    %%-------------------------------------------------------
    
    %% Горизонтальные капилляры
    for i = 1:Ny
        for j = 1:Nx
            row = idxQH(i,j);
            q = X(row);

            if j==1
                pLeft = Net.P0;
            else
                pLeft = X(idxP(i,j-1));
            end
    
            if j==Nx
                pRight = 0;
            else
                pRight = X(idxP(i,j));
            end
    
            dp = pLeft-pRight;
    
            % f - невязка уравнения для конкретного капилляра
            % dfdp, dfdq -производная уравнения по давлению/расходу         
            [f,dfdp,dfdq] = capillaryEquation(...
                Net,dp,q,Net.Ah(i,j),...
                Net.SatH(i,j),...
                Net.StateH(i,j),...
                Net.RegimeH(i,j),...
                Net.MoveH(i,j));
    
            F(row) = f; % формируется вектор невязок
    
            if j>1
                rowIdx(end+1) = row;
                colIdx(end+1) = idxP(i,j-1);
                jacVal(end+1) = dfdp;
            end
    
            if j<Nx
                rowIdx(end+1) = row;
                colIdx(end+1) = idxP(i,j);
                jacVal(end+1) = -dfdp;
            end
    
            rowIdx(end+1) = row;
            colIdx(end+1) = row;
            jacVal(end+1) = dfdq;
        end
    end
    
    %% Вертикальные капилляры
    
    for i = 1:Ny-1
        for j = 1:Nx-1
            row = idxQV(i,j);
            q = X(row);
            pTop = X(idxP(i,j));
            pBottom = X(idxP(i+1,j));
    
            dp = pTop-pBottom;
    
            [f,dfdp,dfdq] = capillaryEquation(...
                Net,dp,q,Net.Av(i,j),...
                Net.SatV(i,j),...
                Net.StateV(i,j),...
                Net.RegimeV(i,j),...
                Net.MoveV(i,j));
    
            F(row) = f;
    
            rowIdx(end+1) = row;
            colIdx(end+1) = idxP(i,j);
            jacVal(end+1) = dfdp;
    
            rowIdx(end+1) = row;
            colIdx(end+1) = idxP(i+1,j);
            jacVal(end+1) = -dfdp;
    
            rowIdx(end+1) = row;
            colIdx(end+1) = row;
            jacVal(end+1) = dfdq;
        end
    end
    
    J = sparse(rowIdx,colIdx,jacVal,n,n);

end