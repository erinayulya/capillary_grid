% Основная функция, рассчитывающая давления и расходы в сети
% Собирается система уравнений вида:
% (1) сумма расходов в узле = 0
% (2) зависимость пвсхода от давления на каждом капилляре
% (3) граничные условия
% Используется собственный метод Ньютона в calcResidualJacobian()
% Итог: реальные абсолютные значения давления в узлах и расходов по ребрам
function Net = solvePressureFlow(Net)
    
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
    
    if isfield(Net,'Qh') && ...
    isequal(size(Net.Qh),[Ny,Nx])
    
        X(idxQH(:)) = Net.Qh(:);
    
    else
        % Начальное приближение Q для капилляров с мениском
        for i = 1:Ny
            for j = 1:Nx
    
                if Net.StateH(i,j) ~= 1
                    continue
                end
    
                r = sqrt(Net.Ah(i,j)/pi);
    
                if j == 1
                    pLeft = Net.P0;
                else
                    pLeft = X(idxP(i,j-1));
                end
    
                if j == Nx
                    pRight = 0;
                else
                    pRight = X(idxP(i,j));
                end
    
                dp = pLeft-pRight;
    
                Pc = 2*Net.sigma*cos(Net.theta)/r;
                dpStar = dp-Pc;
    
                if Net.theta < pi/2
                    muSm = Net.mu1;
                else
                    muSm = Net.mu2;
                end
    
                B = 2*Net.kdyn*Net.sigma*sin(Net.theta)/r ...
                    *(muSm/Net.sigma)^(1/3);
    
                c = pi*r^2;
    
                if dpStar > 0
                    X(idxQH(i,j)) = c*(dpStar/B)^3;
                else
                    X(idxQH(i,j)) = 0;
                end
    
            end
        end
    
    end
    
    if isfield(Net,'Qv') && ...
            isequal(size(Net.Qv),[Ny-1,Nx-1])
    
        X(idxQV(:)) = Net.Qv(:);
    
    end
    
    % Основной расчет

    tol = 1e-10;
    maxIter = 50;
    
    for iter = 1:maxIter
    
        [F,J] = calcResidualJacobian(...
            Net,X,idxP,idxQH,idxQV);
    
        err = norm(F,inf);
    
        if err < tol
            break
        end
    
        dx = J\(-F);
    
        if any(~isfinite(dx))
            error('Newton: получен некорректный шаг.')
        end
    
        alpha = 1;
    
        while alpha > 1e-6
    
            Xtrial = X + alpha*dx;
    
            Ftrial = calcResidual(...
                Net,Xtrial,idxP,idxQH,idxQV);
    
            if norm(Ftrial,inf) < err
                break
            end
    
            alpha = alpha/2;
    
        end
    
        if alpha <= 1e-6
            error('Newton: не удалось найти допустимый шаг.')
        end
    
        X = Xtrial;
    
    end
    
    if norm(F,inf) >= tol
        warning('Newton: не достигнута заданная точность.')
    end

    % Подготовка решений
    
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
