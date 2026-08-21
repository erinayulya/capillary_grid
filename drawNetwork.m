function drawNetwork(Net)

figure(1)
clf
hold on
axis equal

Nx = Net.Nx;
Ny = Net.Ny;

c0 = [0 0.4470 0.7410];   % первая фаза
c2 = [0 0 0];             % вторая фаза (черный)

%%---------------------------------------------------
%% Горизонтальные
%%---------------------------------------------------

for i = 1:Ny

    y = Ny-i;

    for j = 1:Nx

        x1 = j-1;
        x2 = j;

        switch Net.StateH(i,j)

            case 0

                plot([x1 x2],[y y],...
                    'Color',c0,...
                    'LineWidth',4);

            case 2

                plot([x1 x2],[y y],...
                    'Color',c2,...
                    'LineWidth',4);

            case 1

                if Net.Qh(i,j)>=0

                    xm=x1+Net.SatH(i,j);

                    plot([x1 xm],[y y],...
                        'Color',c2,...
                        'LineWidth',4);

                    plot([xm x2],[y y],...
                        'Color',c0,...
                        'LineWidth',4);

                else

                    xm=x2-Net.SatH(i,j);

                    plot([x1 xm],[y y],...
                        'Color',c0,...
                        'LineWidth',4);

                    plot([xm x2],[y y],...
                        'Color',c2,...
                        'LineWidth',4);

                end

                plot(xm,y,...
                    'ro',...
                    'MarkerFaceColor','r',...
                    'MarkerSize',8);

        end
        if Net.StateH(i,j) == 1 && Net.MoveH(i,j) == 1
            text((x1+x2)/2, y+0.12, ...
                sprintf('%d',Net.RegimeH(i,j)), ...
                'HorizontalAlignment','center', ...
                'FontSize',9);
        end
     end

end

%%---------------------------------------------------
%% Вертикальные
%%---------------------------------------------------

for i = 1:Ny-1

    for j = 1:Nx-1

        x=j;

        y1=Ny-i;
        y2=Ny-i-1;

        switch Net.StateV(i,j)

            case 0

                plot([x x],[y1 y2],...
                    'Color',c0,...
                    'LineWidth',4);

            case 2

                plot([x x],[y1 y2],...
                    'Color',c2,...
                    'LineWidth',4);

            case 1

                if Net.Qv(i,j)>=0

                    ym=y1-Net.SatV(i,j);

                    plot([x x],[y1 ym],...
                        'Color',c2,...
                        'LineWidth',4);

                    plot([x x],[ym y2],...
                        'Color',c0,...
                        'LineWidth',4);

                else

                    ym=y2+Net.SatV(i,j);

                    plot([x x],[y1 ym],...
                        'Color',c0,...
                        'LineWidth',4);

                    plot([x x],[ym y2],...
                        'Color',c2,...
                        'LineWidth',4);

                end

                plot(x,ym,...
                    'ro',...
                    'MarkerFaceColor','r',...
                    'MarkerSize',8);

        end
        if Net.StateV(i,j) == 1 && Net.MoveV(i,j) == 1
            text(x+0.12, (y1+y2)/2, ...
                sprintf('%d',Net.RegimeV(i,j)), ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','middle', ...
                'FontSize',9);
        end

    end

end

%%---------------------------------------------------
%% Узлы
%%---------------------------------------------------

%%---------------------------------------------------
% Новое положение менисков
%%---------------------------------------------------

for i=1:Ny

    y=Ny-i;

    for j=0:Nx

        plot(j,y,...
            'ko',...
            'MarkerFaceColor','k',...
            'MarkerSize',6);

    end

end

%%---------------------------------------------------
% Предыдущее положение менисков
%%---------------------------------------------------

if isfield(Net,'SatH_prev')

%% Горизонтальные
for i = 1:Ny
    y = Ny-i;

    for j = 1:Nx

        if Net.StateH_prev(i,j) ~= 1
            continue
        end

        x1 = j-1;
        x2 = j;

        if Net.Qh(i,j) >= 0
            xm = x1 + Net.SatH_prev(i,j);
        else
            xm = x2 - Net.SatH_prev(i,j);
        end

        plot(xm,y,...
            'o',...
            'Color',[0.5 0.5 0.5],...
            'MarkerFaceColor',[0.5 0.5 0.5],...
            'MarkerSize',6);

    end
end


%% Вертикальные
for i = 1:Ny-1
    for j = 1:Nx-1

        if Net.StateV_prev(i,j) ~= 1
            continue
        end

        x = j;

        y1 = Ny-i;
        y2 = Ny-i-1;

        if Net.Qv(i,j) >= 0
            ym = y1 - Net.SatV_prev(i,j);
        else
            ym = y2 + Net.SatV_prev(i,j);
        end

        plot(x,ym,...
            'o',...
            'Color',[0.5 0.5 0.5],...
            'MarkerFaceColor',[0.5 0.5 0.5],...
            'MarkerSize',6);

    end
end

end

xlim([-0.2 Nx+0.2])
ylim([-0.2 Ny-1+0.2])

axis equal
box on

xlabel('x')
ylabel('y')
title('Распространение второй фазы')

drawnow

end