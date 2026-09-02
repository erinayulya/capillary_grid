%% Выбор зависимости Q=f(dp) в капилляре
%
% Функция определяет вид уравнения Q=f(dp) в зависимости от state и regime
% капилляра и возвращает для заданного приближения dp и q:
% f - невязку уравнения
% dfdp - производную уравнения по давлению
% dfdq - производную уравнения по расходу.
%
% В функции реализовано несколько вариантов уравнений:
% (1) Пуазейль, если капилляр заполнен одной фазой
% (2) Нет течения, если мениск в капилляре заблокирован
% (3) 3 режима течения с мениском:
% - капиллярное плато
% - переходной режим
% - вязкое течение

function [f,dfdp,dfdq] = capillaryEquation(...
    Net,dp,q,A,S,state,regime,move)
    
    %%-------------------------------------------------------
    %% Одна фаза, нет мениска
    %%-------------------------------------------------------
    if state==0 || state==2
        if state==0 % только вода
            mu = Net.mu1;
        else % только нефть
            mu = Net.mu2;
        end
        R = 8*pi*mu*Net.L/A^2;
        f = q-dp/R;
        dfdp = -1/R;
        dfdq = 1;
        return
    end

    %%-------------------------------------------------------
    %% Две фазы, мениск
    %%-------------------------------------------------------
    %% Заблокированный мениск
    if state==1 && move==2 
        f=q;
        dfdp=0;
        dfdq=1;
        return
    end

    %% Подвижный мениск
    % Подготовка параметров
    r = sqrt(A/pi);
    Pc = 2*Net.sigma*cos(Net.theta)/r;
    dpStar = dp-Pc; % dp* = dp - Pc
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
    
    % Выбор режима движения мениска
    switch regime
        case 1 % Капиллярное плато
            c = pi*r^2;
            f = q-c*(dpStar/B)^3;
            dfdp = -3*c*dpStar^2/B^3;
            dfdq = 1;
    
        case 2 % Полная модель
            v = q/A;
            v13 = realCubeRoot(v);
            f = dpStar-Aeff*v-B*v13;
            dfdp = 1;
            if abs(v)<1e-14
                vreg = 1e-14;
            else
                vreg = v;
            end
            dfdq = ...
                -Aeff/A ...
                -B/(3*A*abs(vreg)^(2/3));
    
        case 3 % Вязкая асимптота
            f = dpStar-Aeff*(q/A);
            dfdp = 1;
            dfdq = -Aeff/A;
    end
end

% Вспомогательная функция для расчета кубического корня
function y = realCubeRoot(x)
    y = sign(x)*abs(x)^(1/3);
end