function [f,dfdp,dfdq,regime,move] = capillaryEquation(...
    Net,dp,q,A,S,state,regime,move)
%CAPILLARYEQUATION Расход и точная производная новой модели одного мениска.
% dp [Па] и q [м3/с] ориентированы по Dir; v=q/A [м/с].
% Перепад приложен на концах: статическое капиллярное давление не вычитается.
% Regime=1/3 отмечает сторону P_crit, но не переключает формулу в полосе.
% Входной regime не используется: ветвь определяется текущим пробным dp.
% f=q-Q(dp) [м3/с], dfdp [м3/(с*Па)], dfdq=1.
    regime = 0;
    dfdq = 1;

    if state==0 || state==2
        move = 0;
        mu = Net.mu1;
        if state==2, mu = Net.mu2; end
        R = 8*pi*mu*Net.L/A^2;
        f = q-dp/R;
        dfdp = -1/R;
        return
    end
    if state~=1 || ~ismember(move,[1,2,3])
        error('capillaryEquation:InvalidState', ...
            'Мениск требует State=1 и Move=1, 2 или 3.');
    end
    if move==2
        f = q;
        dfdp = 0;
        return
    end
    if dp<=0
        % Обратное продвижение не допускается; положительного порога нет.
        move = 3;
        f = q;
        dfdp = 0;
        return
    end
    move = 1;
    r = sqrt(A/pi);
    muSm = Net.mu1;
    if Net.theta>=pi/2, muSm = Net.mu2; end
    A_class = 8*Net.L/r^2*(Net.mu1*(1-S)+Net.mu2*S);
    A_add = Net.xi*(Net.mu1+Net.mu2)/r;
    Aeff = A_class+A_add;
    B = 2*Net.k*Net.sigma/r*sin(Net.theta)*(muSm/Net.sigma)^(1/3);
    if ~(Net.theta>0 && Net.theta<pi && isfinite(B) && B>0)
        error('capillaryEquation:InvalidPlateauCoefficient', ...
            'Для плато требуется 0<theta<pi и конечный B>0.');
    end
    P_crit = Net.coef*r^(-5/4);
    width = Net.P_crit_width; % Полная ширина, не полуширина.
    regime = 1;
    if dp>P_crit, regime = 3; end

    if dp<=P_crit-width/2
        v = (dp/B)^3;
        dvdp = 3*dp^2/B^3;
    elseif dp>=P_crit+width/2
        v = dp/Aeff;
        dvdp = 1/Aeff;
    else
        t = (dp-P_crit+width/2)/width;
        w = t^3*(10+t*(-15+6*t));
        dwdp = 30*t^2*(1-t)^2/width;
        vPlateau = (dp/B)^3;
        vViscous = dp/Aeff;
        v = (1-w)*vPlateau+w*vViscous;
        dvdp = (1-w)*3*dp^2/B^3+w/Aeff ...
            +dwdp*(vViscous-vPlateau);
    end
    f = q-A*v;
    dfdp = -A*dvdp;
end
