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
    nP = Net.H.Ny*(Net.H.Nx-1);
    nQH = Net.H.Ny*Net.H.Nx;
    nQV = Net.V.Ny*Net.V.Nx;
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
    for i = 1:Net.H.Ny
        for j = 2:Net.H.Nx
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
    
            % Поток сверху. V(i,:) соединяет верхнюю сторону узла
            % строки i с этим узлом.
            q = X(idxQV(i,j-1));
            F(row) = F(row)+q;
            rowIdx(end+1) = row;
            colIdx(end+1) = idxQV(i,j-1);
            jacVal(end+1) = 1;
    
            % Поток вниз. V(i+1,:) соединяет этот узел с нижней
            % стороной узла строки i.
            q = X(idxQV(i+1,j-1));
            F(row) = F(row)-q;
            rowIdx(end+1) = row;
            colIdx(end+1) = idxQV(i+1,j-1);
            jacVal(end+1) = -1;
        end
    end
    
    %%-------------------------------------------------------
    %% Уравнение Q = f(dp) в капилляре
    %%-------------------------------------------------------
    
    %% Горизонтальные капилляры
    for i = 1:Net.H.Ny
        for j = 1:Net.H.Nx
            row = idxQH(i,j);
            q = X(row);
            if j == 1
                pLeft = Net.H.P0;
            else
                pLeft = X(idxP(i,j-1));
            end
    
            if j == Net.H.Nx
                pRight = 0;
            else
                pRight = X(idxP(i,j));
            end
    
            dp = pLeft-pRight;

            % f - невязка уравнения для конкретного капилляра
            % dfdp, dfdq - производная уравнения по давлению/расходу 
            [f,dfdp,dfdq] = capillaryEquation(...
                Net,dp,q,Net.H.A(i,j),...
                Net.H.Sat(i,j),...
                Net.H.State(i,j),...
                Net.H.Regime(i,j),...
                Net.H.Move(i,j));
    
            F(row) = f;
    
            if j > 1
                rowIdx(end+1) = row;
                colIdx(end+1) = idxP(i,j-1);
                jacVal(end+1) = dfdp;
            end
    
            if j < Net.H.Nx
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
    for i = 1:Net.V.Ny
        for j = 1:Net.V.Nx
            row = idxQV(i,j);
            q = X(row);
    
            if ~Net.VerticalBC && (i == 1 || i == Net.V.Ny)
                % Верхняя и нижняя границы непроницаемы:
                % расход через граничный капилляр равен нулю.
                f = q;
                dfdp = 0;
                dfdq = 1;
            else
                % Давление сверху
                if i == 1
                    pTop = Net.V.P0;
                else
                    pTop = X(idxP(i-1,j));
                end
    
                % Давление снизу
                if i == Net.V.Ny
                    pBottom = 0;
                else
                    pBottom = X(idxP(i,j));
                end
    
                dp = pTop-pBottom;
    
                [f,dfdp,dfdq] = capillaryEquation(...
                    Net,dp,q,Net.V.A(i,j),...
                    Net.V.Sat(i,j),...
                    Net.V.State(i,j),...
                    Net.V.Regime(i,j),...
                    Net.V.Move(i,j));
            end
    
            F(row) = f;
    
            if i > 1
                rowIdx(end+1) = row;
                colIdx(end+1) = idxP(i-1,j);
                jacVal(end+1) = dfdp;
            end
    
            if i < Net.V.Ny
                rowIdx(end+1) = row;
                colIdx(end+1) = idxP(i,j);
                jacVal(end+1) = -dfdp;
            end
    
            rowIdx(end+1) = row;
            colIdx(end+1) = row;
            jacVal(end+1) = dfdq;
        end
    end

    J = sparse(rowIdx,colIdx,jacVal,n,n);

end
