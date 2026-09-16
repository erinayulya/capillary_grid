% Выбор режима движения мениска:
% 0 - Пуазейль (нет мениска, для state ~=1)
% 1 - плато: v = (dp*/B)^3
% 2 - переходной: dp* = Aeff*v + B*v^(1/3)
% 3 - вязкий: v = dp*/Aeff
% dp* = dp - pcap

function Net = calcRegime(Net)

    %% Горизонтальные капилляры
    for i = 1:Net.H.Ny
        for j = 1:Net.H.Nx
            if Net.H.State(i,j) ~= 1 || Net.H.Move(i,j) ~= 1
                continue % - нет мениска и Пуазейль или заблокирован
            end
            r = sqrt(Net.H.A(i,j)/pi);
            if j == 1
                pLeft = Net.H.P0;
            else
                pLeft = Net.P(i,j-1);
            end
            if j == Net.H.Nx
                pRight = 0;
            else
                pRight = Net.P(i,j);
            end
            dp = Net.H.Dir(i,j)*(pLeft - pRight);
            Pc = 2*Net.sigma*cos(Net.theta)/r;
            dpStar = dp - Pc;
            Sat = Net.H.Sat(i,j);
            
            Net.H.Regime(i,j) = calcOneRegime(r, Sat, dpStar, Net);
        end
    end
    
    %% Вертикальные капилляры
    for i = 1:Net.V.Ny
        for j = 1:Net.V.Nx
            if Net.V.State(i,j) ~= 1 || Net.V.Move(i,j) ~= 1
                continue
            end
            r = sqrt(Net.V.A(i,j)/pi);
            if i == 1
                pTop = Net.V.P0;
            else
                pTop = Net.P(i-1,j);
            end
            if i == Net.V.Ny
                pBottom = 0;
            else
                pBottom = Net.P(i,j);
            end
            dp = Net.V.Dir(i,j)*(pTop - pBottom);
            Pc = 2*Net.sigma*cos(Net.theta)/r;
            dpStar = dp - Pc;
            Sat = Net.V.Sat(i,j);

            Net.V.Regime(i,j) = calcOneRegime(r, Sat, dpStar, Net);
        end
    end
end


% Функция вычисляет режим 1/2/3 для капилляра с мениском
function Regime = calcOneRegime(r, Sat, dpStar, Net)
    if Net.theta < pi/2
        mu_sm = Net.mu1;
    else
        mu_sm = Net.mu2;
    end
    
    l2 = Sat*Net.L;
    l1 = Net.L-l2;
    k = Net.kdyn;
    Aeff = 8/r^2*(Net.mu1*l1 + Net.mu2*l2) ...
        - 2*k^3/(3*r)*mu_sm*sin(Net.theta);
    
    if Aeff <= 0
        Regime = 1;
        return
    end
    
    alpha = r*Aeff/(2*mu_sm);
    beta = k*sin(Net.theta);
    PiCrit = sqrt(beta^3/alpha);
    Pi = r*dpStar/(2*Net.sigma);
    if Pi < PiCrit/Net.bound
        Regime = 1; % - капиллярное плато
    elseif Pi > Net.bound*PiCrit
        Regime = 3; % - вязкий режим
    else
        Regime = 2; % - переходной (полное уравнение)
    end
end
