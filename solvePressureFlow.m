%% Решение капиллярной сети
% 
% Основная функция, рассчитывающая давления и расходы в капиллярной сети.
% Собирается и итерационно решается нелинейная система уравнений вида:
% (1) сумма расходов в узле = 0
% (2) зависимость расхода от давления на каждом капилляре (от режима)
% (3) граничные условия
% Используется собственный метод Ньютона с уменьшением шага для уменьшения
% невязки и достижения заданной точности.

function Net = solvePressureFlow(Net)
    
    % Подготовка массивов
    Ny = Net.Ny;
    Nx = Net.Nx;
    
    nP  = Ny*(Nx-1);
    nQH = Ny*Nx;
    nQV = (Ny-1)*(Nx-1);
    
    n = nP+nQH+nQV;
    
    idxP = reshape(1:nP,Ny,Nx-1);
    idxQH = nP + reshape(1:nQH,Ny,Nx);
    idxQV = nP+nQH + reshape(1:nQV,Ny-1,Nx-1);
    
    X = zeros(n,1);
    
    % Начальное приближение для P:
    % из предыдущего шага или из граничного условия
    if isfield(Net,'P') && ...
            isequal(size(Net.P),[Ny,Nx+1])
        P0 = Net.P(:,2:Nx);
        X(idxP(:)) = P0(:);
    else
        for i = 1:Ny
            for j = 2:Nx
                X(idxP(i,j-1)) = ...
                    Net.P0*(Nx+1-j)/Nx;
            end
        end
    end
    
    % Начальное приближение для Qh:
    % из предыдущего шага или рассчитывается по режиму
    if isfield(Net,'Qh') && ...
    isequal(size(Net.Qh),[Ny,Nx])
        X(idxQH(:)) = Net.Qh(:);
    else
        % Начальное приближение Q для капилляров с мениском
        for i = 1:Ny
            for j = 1:Nx
                if Net.StateH(i,j) == 1
                    X(idxQH(:)) = 1e-15; % ненулевая малая величина
                end
            end
        end
    end
    
    % Начальное приближение для Qv:
    if isfield(Net,'Qv') && ...
            isequal(size(Net.Qv),[Ny-1,Nx-1])
        X(idxQV(:)) = Net.Qv(:);
    end
    
    %%-------------------------------------------------------
    %% Основной расчет
    %%-------------------------------------------------------

    tol = 1e-10;
    maxIter = 50;
    
    % F - невязка текущего решения
    % J - якобиан
    % dx - шаг Ньютона

    for iter = 1:maxIter
        [F,J] = calcResidualJacobian(...
            Net,X,idxP,idxQH,idxQV);
        err = norm(F,inf);
        if err < tol
            break
        end

        dx = J\(-F); % стандартный шаг Ньютона
        if any(~isfinite(dx))
            error('Newton: получен некорректный шаг.')
        end

        alpha = 1;
        while alpha > 1e-6
            Xtrial = X + alpha*dx; % пробуем полный шаг
            Ftrial = calcResidual(...
                Net,Xtrial,idxP,idxQH,idxQV);
            if norm(Ftrial,inf) < err
                break
            end
            alpha = alpha/2; % уменьшаем шаг, если предыдущий не помог
        end
    
        if alpha <= 1e-6
            error('Newton: не удалось найти допустимый шаг.')
        end
    
        X = Xtrial;
    end
    
    if norm(F,inf) >= tol
        warning('Newton: не достигнута заданная точность.')
    end

    %%-------------------------------------------------------
    %% Подготовка результатов
    %%-------------------------------------------------------
    
    Net.P = zeros(Ny,Nx+1);
    Net.P(:,1) = Net.P0;
    Net.P(:,Nx+1) = 0;
    Net.P(:,2:Nx) = ...
        reshape(X(idxP(:)),Ny,Nx-1);
    
    Net.Qh = ...
        reshape(X(idxQH(:)),Ny,Nx);
    
    Net.Qv = ...
        reshape(X(idxQV(:)),Ny-1,Nx-1);
    
    Net.NewtonIterations = iter;
end
