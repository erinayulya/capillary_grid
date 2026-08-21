function [F,J] = calcResidualJacobian(...
    Net,X,idxP,idxQH,idxQV)
    
    Ny = Net.Ny;
    Nx = Net.Nx;
    
    nP = Ny*(Nx-1);
    nQH = Ny*Nx;
    nQV = (Ny-1)*(Nx-1);
    
    n = nP+nQH+nQV;
    
    F = zeros(n,1);
    
    I = [];
    Jcol = [];
    V = [];
    
    %% Узловые уравнения
    
    for i = 1:Ny
    
        for j = 2:Nx
    
            row = idxP(i,j-1);
    
            %% Поток слева
    
            q = X(idxQH(i,j-1));
    
            F(row) = F(row)+q;
    
            I(end+1) = row;
            Jcol(end+1) = idxQH(i,j-1);
            V(end+1) = 1;
    
            %% Поток справа
    
            q = X(idxQH(i,j));
    
            F(row) = F(row)-q;
    
            I(end+1) = row;
            Jcol(end+1) = idxQH(i,j);
            V(end+1) = -1;
    
            %% Вертикальный поток вверх
    
            if i>1
    
                q = X(idxQV(i-1,j-1));
    
                F(row) = F(row)+q;
    
                I(end+1) = row;
                Jcol(end+1) = idxQV(i-1,j-1);
                V(end+1) = 1;
    
            end
    
            %% Вертикальный поток вниз
    
            if i<Ny
    
                q = X(idxQV(i,j-1));
    
                F(row) = F(row)-q;
    
                I(end+1) = row;
                Jcol(end+1) = idxQV(i,j-1);
                V(end+1) = -1;
    
            end
    
        end
    
    end
    
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
    
            [f,dfdp,dfdq] = capillaryEquation(... % - задает уравнение dp = f(Q) от Regime и State
                Net,dp,q,Net.Ah(i,j),...
                Net.SatH(i,j),...
                Net.StateH(i,j),...
                Net.RegimeH(i,j),...
                Net.MoveH(i,j));
    
            F(row) = f;
    
            if j>1
    
                I(end+1) = row;
                Jcol(end+1) = idxP(i,j-1);
                V(end+1) = dfdp;
    
            end
    
            if j<Nx
    
                I(end+1) = row;
                Jcol(end+1) = idxP(i,j);
                V(end+1) = -dfdp;
    
            end
    
            I(end+1) = row;
            Jcol(end+1) = row;
            V(end+1) = dfdq;
    
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
    
            [f,dfdp,dfdq] = capillaryEquation(... % - задает уравнение dp = f(Q) от Regime и State
                Net,dp,q,Net.Av(i,j),...
                Net.SatV(i,j),...
                Net.StateV(i,j),...
                Net.RegimeV(i,j),...
                Net.MoveV(i,j));
    
            F(row) = f;
    
            I(end+1) = row;
            Jcol(end+1) = idxP(i,j);
            V(end+1) = dfdp;
    
            I(end+1) = row;
            Jcol(end+1) = idxP(i+1,j);
            V(end+1) = -dfdp;
    
            I(end+1) = row;
            Jcol(end+1) = row;
            V(end+1) = dfdq;
    
        end
    
    end
    
    J = sparse(I,Jcol,V,n,n);

end