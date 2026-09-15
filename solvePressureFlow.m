%% Решение капиллярной сети
%
% Основная функция, рассчитывающая давления и расходы в капиллярной сети.
% Собирается и итерационно решается нелинейная система уравнений вида:
% (1) сумма расходов в узле = 0
% (2) зависимость расхода от давления на каждом капилляре (от Regime)
% (3) граничные условия
% Используется собственный метод Ньютона с уменьшением шага для уменьшения
% невязки и достижения заданной точности.

function Net = solvePressureFlow(Net)

    % Подготовка массивов
    nP  = Net.H.Ny*(Net.H.Nx-1);
    nQH = Net.H.Ny*Net.H.Nx;
    nQV = Net.V.Ny*Net.V.Nx;
    
    n = nP+nQH+nQV;
    
    idxP = reshape(1:nP,Net.H.Ny,Net.H.Nx-1);
    idxQH = nP + reshape(1:nQH,Net.H.Ny,Net.H.Nx);
    idxQV = nP+nQH + reshape(1:nQV,Net.V.Ny,Net.V.Nx);
    
    X = zeros(n,1);
    
    % Начальное приближение для P:
    % из предыдущего шага или рассчитывается по граничному условию
    if isfield(Net,'P') && ...
            isequal(size(Net.P),[Net.H.Ny,Net.H.Nx-1])
        X(idxP(:)) = Net.P(:);
    else
        for i = 1:Net.H.Ny
            for j = 1:Net.H.Nx-1
                X(idxP(i,j)) = ...
                    Net.H.P0*(Net.H.Nx-j)/Net.H.Nx;
            end
        end
    end
    
    % Начальное приближение для Qh:
    % из предыдущего шага или рассчитывается по режиму
    if isfield(Net.H,'Q') && ...
            isequal(size(Net.H.Q),[Net.H.Ny,Net.H.Nx])
        X(idxQH(:)) = Net.H.Q(:);
    else
        % Начальное приближение Q для капилляров с мениском
        for i = 1:Net.H.Ny
            for j = 1:Net.H.Nx
                if Net.H.State(i,j) == 1
                    X(idxQH(i,j)) = 1e-9; % малая величина
                end
            end
        end
    end
    
    % Начальное приближение для Qv:
    if isfield(Net.V,'Q') && ...
            isequal(size(Net.V.Q),[Net.V.Ny,Net.V.Nx])
        X(idxQV(:)) = Net.V.Q(:);
    end
    
    %%-------------------------------------------------------
    %% Основной расчет
    %%-------------------------------------------------------
    
    % Невязки расхода имеют порядок 1e-14...1e-9 м3/с, поэтому
    % абсолютный допуск 1e-8 преждевременно принимал старое решение.
    tol = 1e-13;
    maxIter = 50; % максимальное кол-во шагов поиска решения
    
    % F - невязка текущего решения
    % J - якобиан
    % dx - шаг Ньютона
    
    for iter = 1:maxIter
        [F,J] = calcResidualJacobian(...
            Net,X,idxP,idxQH,idxQV);
    
        % Проверка невязки:
        err = norm(F,inf);
        if err < tol
            break % точность достигнута, решение найдено
        end

        % Если точность не достигнута:
        dx = J\(-F);

        if any(~isfinite(dx))
            error('Newton: получен некорректный шаг.')
        end
    
        % Корректировка шага:
        alpha = 1;
        while alpha > 1e-6
            Xtrial = X + alpha*dx;
            [Ftrial, ~] = calcResidualJacobian(...
                Net,Xtrial,idxP,idxQH,idxQV);
            if norm(Ftrial,inf) < err
                break % Xtrial подходит, возвращаемся в начало
            end
            alpha = alpha/2; % адаптирование шага, если невязка выросла
        end
    
        if alpha <= 1e-6
            error('Newton: не удалось найти допустимый шаг.')
        end
    
        X = Xtrial; % новое приближение решения выбрано
    end
    
    if norm(F,inf) >= tol
        disp(['Newton iter = ',num2str(iter),', err = ',num2str(norm(F,inf))])
        warning('Newton: не достигнута заданная точность.')
    end
    
    %%-------------------------------------------------------
    %% Подготовка результатов
    %%-------------------------------------------------------
    
    Net.P = reshape(X(idxP(:)),Net.H.Ny,Net.H.Nx-1);
    
    Net.H.Q = ...
        reshape(X(idxQH(:)),Net.H.Ny,Net.H.Nx);
    
    Net.V.Q = ...
        reshape(X(idxQV(:)),Net.V.Ny,Net.V.Nx);
    
    Net.NewtonIterations = iter;
end
