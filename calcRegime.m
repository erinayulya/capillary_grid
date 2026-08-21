% Выбор режима движения мениска:
% 0 - Пуазейль (нет мениска, для state ~=1)
% 1 - плато: v = (dp*/B)^3
% 2 - переходной: dp* = Aeff*v + B*v^(1/3)
% 3 - вязкий: v = dp*/Aeff
% dp* = dp - pcap

function Net = calcRegime(Net)
    
    %% Горизонтальные капилляры
    for i = 1:Net.Ny
        for j = 1:Net.Nx
            if Net.StateH(i,j) ~= 1 || Net.MoveH(i, j)==2
               continue % - нет мениска и Пуазейль или заблокирован
          end
    
          r = sqrt(Net.Ah(i,j)/pi);
          dp = Net.P(i,j) - Net.P(i,j+1);
          Pc = 2*Net.sigma*cos(Net.theta)/r;
          dpStar = dp - Pc;
          Sat = Net.SatH(i,j);
    
          Net.RegimeH(i,j) = calcOneRegime(r, Sat, dpStar, Net);
        end
    end
    
    %% Вертикальные капилляры
    for i = 1:Net.Ny-1
        for j = 1:Net.Nx-1
    
          if Net.StateV(i,j) ~= 1 || Net.MoveV(i, j)==2
              continue
          end
    
           r = sqrt(Net.Av(i,j)/pi);
           dp = Net.P(i,j+1) - Net.P(i+1,j+1);
           Pc = 2*Net.sigma*cos(Net.theta)/r;
           dpStar = dp - Pc;
           Sat = Net.SatV(i,j);
    
           Net.RegimeV(i,j) = calcOneRegime(r, Sat, dpStar, Net);
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
    
    PiCrit = (beta/alpha)^(3/2);
    
    Pi = r*dpStar/(2*Net.sigma);
    
    if Pi < PiCrit/2
        Regime = 1; % - капиллярное плато
    elseif Pi > 2*PiCrit
        Regime = 3; % - вязкий режим
    else
        Regime = 2; % - переходной (полное уравнение)
    end
end