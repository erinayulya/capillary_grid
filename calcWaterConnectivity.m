function [WaterConnectedH, WaterConnectedV] = calcWaterConnectivity(Net)

% WaterConnectedH(i,j) = true, если горизонтальный капилляр
% полностью заполненный водой (SatH == 0) связан с правой границей
% через другие полностью водяные капилляры.
%
% WaterConnectedV(i,j) = аналогично для вертикальных капилляров.
%
% Источник связности ТОЛЬКО правая граница.
% Верхняя и нижняя границы непроницаемые.


%% Размеры сети

Ny = size(Net.StateH,1);
Nx = size(Net.StateV,2);


%% Результаты

WaterConnectedH = false(size(Net.StateH));
WaterConnectedV = false(size(Net.StateV));


%% =========================================================
% Очередь BFS
% ==========================================================

% В очереди храним:
%
% type = 1 -> горизонтальный капилляр
% type = 2 -> вертикальный капилляр

maxElements = numel(Net.StateH) + numel(Net.StateV);

queueType = zeros(maxElements,1);
queueI    = zeros(maxElements,1);
queueJ    = zeros(maxElements,1);

head = 1;
tail = 0;


%% =========================================================
% Старт: правая граница
% ==========================================================

% На правой границе находятся последние горизонтальные
% капилляры каждого ряда.

j = size(Net.StateH,2);

for i = 1:Ny

    % Полностью водяной капилляр может быть частью
    % связной водяной области.

    if Net.SatH(i,j) == 0

        WaterConnectedH(i,j) = true;

        tail = tail + 1;

        queueType(tail) = 1;
        queueI(tail) = i;
        queueJ(tail) = j;

    end

end


%% =========================================================
% BFS
% ==========================================================

while head <= tail

    type = queueType(head);
    i    = queueI(head);
    j    = queueJ(head);

    head = head + 1;


    %% =====================================================
    % Если текущий капилляр горизонтальный
    % ======================================================

    if type == 1

        % H(i,j) соединяет два узла:
        %
        % левый  : (i,j)
        % правый : (i,j+1)


        %% -------------------------------------------------
        % Сосед слева: H(i,j-1)
        % --------------------------------------------------

        if j > 1

            if Net.SatH(i,j-1) == 0 && ...
                    ~WaterConnectedH(i,j-1)

                WaterConnectedH(i,j-1) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i;
                queueJ(tail) = j-1;

            end

        end


        %% -------------------------------------------------
        % Через левый узел: V(i-1,j-1)
        % --------------------------------------------------

        if i > 1 && j-1 >= 1 && ...
                j-1 <= size(Net.StateV,2)

            if Net.SatV(i-1,j-1) == 0 && ...
                    ~WaterConnectedV(i-1,j-1)

                WaterConnectedV(i-1,j-1) = true;

                tail = tail + 1;

                queueType(tail) = 2;
                queueI(tail) = i-1;
                queueJ(tail) = j-1;

            end

        end


        %% -------------------------------------------------
        % Через левый узел: V(i,j-1)
        % --------------------------------------------------

        if i <= size(Net.StateV,1) && ...
                j-1 >= 1 && ...
                j-1 <= size(Net.StateV,2)

            if Net.SatV(i,j-1) == 0 && ...
                    ~WaterConnectedV(i,j-1)

                WaterConnectedV(i,j-1) = true;

                tail = tail + 1;

                queueType(tail) = 2;
                queueI(tail) = i;
                queueJ(tail) = j-1;

            end

        end


        %% -------------------------------------------------
        % Сосед справа: H(i,j+1)
        % --------------------------------------------------

        if j < size(Net.StateH,2)

            if Net.SatH(i,j+1) == 0 && ...
                    ~WaterConnectedH(i,j+1)

                WaterConnectedH(i,j+1) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i;
                queueJ(tail) = j+1;

            end

        end


        %% -------------------------------------------------
        % Через правый узел: V(i-1,j)
        % --------------------------------------------------

        if i > 1 && ...
                j <= size(Net.StateV,2)

            if Net.SatV(i-1,j) == 0 && ...
                    ~WaterConnectedV(i-1,j)

                WaterConnectedV(i-1,j) = true;

                tail = tail + 1;

                queueType(tail) = 2;
                queueI(tail) = i-1;
                queueJ(tail) = j;

            end

        end


        %% -------------------------------------------------
        % Через правый узел: V(i,j)
        % --------------------------------------------------

        if i <= size(Net.StateV,1) && ...
                j <= size(Net.StateV,2)

            if Net.SatV(i,j) == 0 && ...
                    ~WaterConnectedV(i,j)

                WaterConnectedV(i,j) = true;

                tail = tail + 1;

                queueType(tail) = 2;
                queueI(tail) = i;
                queueJ(tail) = j;

            end

        end


    %% =====================================================
    % Если текущий капилляр вертикальный
    % ======================================================

    elseif type == 2

        % V(i,j) соединяет:
        %
        % верхний узел : (i,j)
        % нижний узел  : (i+1,j)


        %% -------------------------------------------------
        % Через верхний узел: H(i,j)
        % --------------------------------------------------

        if i >= 1 && ...
                i <= size(Net.StateH,1) && ...
                j <= size(Net.StateH,2)

            if Net.SatH(i,j) == 0 && ...
                    ~WaterConnectedH(i,j)

                WaterConnectedH(i,j) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i;
                queueJ(tail) = j;

            end

        end


        %% -------------------------------------------------
        % Через верхний узел: H(i,j+1)
        % --------------------------------------------------

        if i >= 1 && ...
                i <= size(Net.StateH,1) && ...
                j+1 <= size(Net.StateH,2)

            if Net.SatH(i,j+1) == 0 && ...
                    ~WaterConnectedH(i,j+1)

                WaterConnectedH(i,j+1) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i;
                queueJ(tail) = j+1;

            end

        end


        %% -------------------------------------------------
        % Через верхний узел: V(i-1,j)
        % --------------------------------------------------

        if i > 1

            if Net.SatV(i-1,j) == 0 && ...
                    ~WaterConnectedV(i-1,j)

                WaterConnectedV(i-1,j) = true;

                tail = tail + 1;

                queueType(tail) = 2;
                queueI(tail) = i-1;
                queueJ(tail) = j;

            end

        end


        %% -------------------------------------------------
        % Через нижний узел: H(i+1,j)
        % --------------------------------------------------

        if i+1 <= size(Net.StateH,1)

            if Net.SatH(i+1,j) == 0 && ...
                    ~WaterConnectedH(i+1,j)

                WaterConnectedH(i+1,j) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i+1;
                queueJ(tail) = j;

            end

        end


        %% -------------------------------------------------
        % Через нижний узел: H(i+1,j+1)
        % --------------------------------------------------

        if i+1 <= size(Net.StateH,1) && ...
                j+1 <= size(Net.StateH,2)

            if Net.SatH(i+1,j+1) == 0 && ...
                    ~WaterConnectedH(i+1,j+1)

                WaterConnectedH(i+1,j+1) = true;

                tail = tail + 1;

                queueType(tail) = 1;
                queueI(tail) = i+1;
                queueJ(tail) = j+1;

            end

        end


        %% -------------------------------------------------
        % Через нижний узел: V(i+1,j)
        % --------------------------------------------------

        if i < size(Net.StateV,1)

            if Net.SatV(i+1,j) == 0 && ...
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