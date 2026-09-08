%% Есть ли связность по воде
%
% Функция маркирует капилляры с помощью промежуточной
% переменной WaterConnected, если они полностью заполненны
% водой (Sat=0) и связаны с правой или нижней границей через другие
% полностью водяные капилляры, т.е. имеют связность по воде.
% Источник связности: правая и нижняя границы.

function [WaterConnectedH, WaterConnectedV] = calcWaterConnectivity(Net)
   
    WaterConnectedH = false(size(Net.H.State));
    WaterConnectedV = false(size(Net.V.State));
    
    %% =========================================================
    %% Очередь BFS
    %% ==========================================================
    
    % В очереди хранится:
    %
    % type = 1 -> горизонтальный капилляр
    % type = 2 -> вертикальный капилляр
    
    maxElements = numel(Net.H.State) + numel(Net.V.State);
    
    queueType = zeros(maxElements,1);
    queueI    = zeros(maxElements,1);
    queueJ    = zeros(maxElements,1);
    
    head = 1;
    tail = 0;
    
    %% =========================================================
    %% Старт: правая и нижняя границы
    %% =========================================================
    
    % На правой границе находятся последние горизонтальные
    % капилляры каждого ряда.
    
    j = Net.H.Nx;
    
    for i = 1:Net.H.Ny
        % Полностью водяной капилляр может быть частью
        % связной водяной области.
        if Net.H.Sat(i,j) == 0
            WaterConnectedH(i,j) = true;
            tail = tail + 1;
            queueType(tail) = 1;
            queueI(tail) = i;
            queueJ(tail) = j;
        end
    end

    % На нижней границе находятся последние вертикальные
    % капилляры каждого столбца.
    
    i = Net.V.Ny;
    
    for j = 1:Net.V.Nx
        if Net.V.Sat(i,j) == 0
            WaterConnectedV(i,j) = true;
            tail = tail + 1;
            queueType(tail) = 2;
            queueI(tail) = i;
            queueJ(tail) = j;
        end
    end
    
    
    %% =========================================================
    %% BFS
    %% ==========================================================
    
    while head <= tail
    
        type = queueType(head);
        i    = queueI(head);
        j    = queueJ(head);
    
        head = head + 1;

        % =====================================================
        % Если текущий капилляр горизонтальный
        % ======================================================
    
        if type == 1
    
            % H(i,j) соединяет два узла:
            %
            % левый  : (i,j)
            % правый : (i,j+1)
    
            % -------------------------------------------------
            % Сосед слева: H(i,j-1)
            % --------------------------------------------------
    
            if j > 1
                if Net.H.Sat(i,j-1) == 0 && ...
                        ~WaterConnectedH(i,j-1)
                    WaterConnectedH(i,j-1) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i;
                    queueJ(tail) = j-1;
                end
            end
    
            % -------------------------------------------------
            % Через левый узел: V(i-1,j-1)
            % --------------------------------------------------
    
            if i > 1 && j-1 >= 1 && ...
                    j-1 <= Net.V.Nx
                if Net.V.Sat(i-1,j-1) == 0 && ...
                        ~WaterConnectedV(i-1,j-1)
                    WaterConnectedV(i-1,j-1) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i-1;
                    queueJ(tail) = j-1;
                end
            end

            % -------------------------------------------------
            % Через левый узел: V(i,j-1)
            % --------------------------------------------------
    
            if i <= Net.V.Ny && ...
                    j-1 >= 1 && ...
                    j-1 <= Net.V.Nx
                if Net.V.Sat(i,j-1) == 0 && ...
                        ~WaterConnectedV(i,j-1)
                    WaterConnectedV(i,j-1) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i;
                    queueJ(tail) = j-1;
                end
            end
    
            % -------------------------------------------------
            % Сосед справа: H(i,j+1)
            % --------------------------------------------------
    
            if j < Net.H.Nx
                if Net.H.Sat(i,j+1) == 0 && ...
                        ~WaterConnectedH(i,j+1)
                    WaterConnectedH(i,j+1) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i;
                    queueJ(tail) = j+1;
                end
            end
    
            % -------------------------------------------------
            % Через правый узел: V(i-1,j)
            % --------------------------------------------------
    
            if i > 1 && ...
                    j <= Net.V.Nx
                if Net.V.Sat(i-1,j) == 0 && ...
                        ~WaterConnectedV(i-1,j)
                    WaterConnectedV(i-1,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i-1;
                    queueJ(tail) = j;
                end
            end
    
            % -------------------------------------------------
            % Через правый узел: V(i,j)
            % --------------------------------------------------
    
            if i <= Net.V.Ny && ...
                    j <= Net.V.Nx
                if Net.V.Sat(i,j) == 0 && ...
                        ~WaterConnectedV(i,j)
                    WaterConnectedV(i,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i;
                    queueJ(tail) = j;
                end
            end
    
    
        % =====================================================
        % Если текущий капилляр вертикальный
        % ======================================================
    
        elseif type == 2
    
            % V(i,j) соединяет:
            %
            % верхний узел : (i,j)
            % нижний узел  : (i+1,j)
    
            % -------------------------------------------------
            % Через верхний узел: H(i,j)
            % --------------------------------------------------
    
            if i >= 1 && ...
                    i <= Net.H.Ny && ...
                    j <= Net.H.Nx
                if Net.H.Sat(i,j) == 0 && ...
                        ~WaterConnectedH(i,j)
                    WaterConnectedH(i,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i;
                    queueJ(tail) = j;
                end
            end
    
            % --------------------------------------------------
            % Через верхний узел: H(i,j+1)
            % --------------------------------------------------
    
            if i >= 1 && ...
                    i <= Net.H.Ny && ...
                    j+1 <= Net.H.Nx
                if Net.H.Sat(i,j+1) == 0 && ...
                        ~WaterConnectedH(i,j+1)
                    WaterConnectedH(i,j+1) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i;
                    queueJ(tail) = j+1;
                end
            end
    
    
            % -------------------------------------------------
            % Через верхний узел: V(i-1,j)
            % --------------------------------------------------
    
            if i > 1
                if Net.V.Sat(i-1,j) == 0 && ...
                        ~WaterConnectedV(i-1,j)
                    WaterConnectedV(i-1,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i-1;
                    queueJ(tail) = j;
                end
            end
    
            % -------------------------------------------------
            % Через нижний узел: H(i+1,j)
            % --------------------------------------------------
    
            if i+1 <= Net.H.Ny
                if Net.H.Sat(i+1,j) == 0 && ...
                        ~WaterConnectedH(i+1,j)
                    WaterConnectedH(i+1,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i+1;
                    queueJ(tail) = j;
                end
            end
    
            % -------------------------------------------------
            % Через нижний узел: H(i+1,j+1)
            % --------------------------------------------------
    
            if i+1 <= Net.H.Ny && ...
                    j+1 <= Net.H.Nx
                if Net.H.Sat(i+1,j+1) == 0 && ...
                        ~WaterConnectedH(i+1,j+1)
                    WaterConnectedH(i+1,j+1) = true;
                    tail = tail + 1;
                    queueType(tail) = 1;
                    queueI(tail) = i+1;
                    queueJ(tail) = j+1;
                end
            end
    
            % -------------------------------------------------
            % Через нижний узел: V(i+1,j)
            % --------------------------------------------------
    
            if i < Net.V.Ny
                if Net.V.Sat(i+1,j) == 0 && ...
                        ~WaterConnectedV(i+1,j)
                    WaterConnectedV(i+1,j) = true;
                    tail = tail + 1;
                    queueType(tail) = 2;
                    queueI(tail) = i+1;
                    queueJ(tail) = j;
                end
            end
        end
    end
end