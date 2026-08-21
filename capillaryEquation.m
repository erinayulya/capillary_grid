% Функция математически задает уравнение dp=f(Q) 
% в зависимости от state и regime

function [F,dfdp,dfdq] = capillaryEquation(...
    Net,dp,q,A,S,state,regime,move)

    R = 8*pi*Net.mu1*Net.L/A^2;
    
    if state==0 % только вода, Пуазейль
    
        F = q-dp/R;
    
        dfdp = -1/R;
        dfdq = 1;
    
        return
    end

    if state==1 && move==2 % заблокированные капилляры

        F=q;
        dfdp=0;
        dfdq=1;

        return
    end
    
    if state==2 % только нефть, Пуазейль
    
        R = 8*pi*Net.mu2*Net.L/A^2;
    
        F = q-dp/R;
    
        dfdp = -1/R;
        dfdq = 1;
    
        return
    end
    
    % ===== Капилляр с мениском =====
    
    r = sqrt(A/pi);
    
    Pc = 2*Net.sigma*cos(Net.theta)/r;
    
    dpStar = dp-Pc;
    
    l2 = S*Net.L;
    l1 = Net.L-l2;
    
    if Net.theta < pi/2
        muSm = Net.mu1;
    else
        muSm = Net.mu2;
    end
    
    k = Net.kdyn;
    
    Aeff = ...
        8/r^2*(Net.mu1*l1+Net.mu2*l2) ...
        -2*k^3/(3*r)*muSm*sin(Net.theta);
    
    B = ...
        2*k*Net.sigma*sin(Net.theta)/r ...
        *(muSm/Net.sigma)^(1/3);
    
    switch regime
    
        case 1
    
            % Капиллярное плато
    
            c = pi*r^2;
    
            F = q-c*(dpStar/B)^3;
    
            dfdp = -3*c*dpStar^2/B^3;
            dfdq = 1;
    
        case 2
    
            % Полная модель
    
            v = q/A;
            v13 = realCubeRoot(v);
    
            F = dpStar-Aeff*v-B*v13;
    
            dfdp = 1;
    
            if abs(v)<1e-14
                vreg = 1e-14;
            else
                vreg = v;
            end
    
            dfdq = ...
                -Aeff/A ...
                -B/(3*A*abs(vreg)^(2/3));
    
        case 3
    
            % Вязкая асимптота
    
            F = dpStar-Aeff*(q/A);
    
            dfdp = 1;
            dfdq = -Aeff/A;
    
        otherwise
    
            % При неизвестном режиме используем полную модель
    
            v = q/A;
            v13 = realCubeRoot(v);
    
            F = dpStar-Aeff*v-B*v13;
    
            dfdp = 1;
    
            if abs(v)<1e-14
                vreg = 1e-14;
            else
                vreg = v;
            end
    
            dfdq = ...
                -Aeff/A ...
                -B/(3*A*abs(vreg)^(2/3));
    
    end
end



function y = realCubeRoot(x)
    y = sign(x)*abs(x)^(1/3);
end