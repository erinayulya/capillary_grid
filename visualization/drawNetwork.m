function drawNetwork(Net,move)

if nargin < 2
    move = false;
end

figure
hold on
axis equal

Nx = Net.H.Nx;
Ny = Net.H.Ny;

c0 = [0 0.4470 0.7410];   % первая фаза
c2 = [0 0 0];             % вторая фаза (черный)

%%---------------------------------------------------
%% Горизонтальные
%%---------------------------------------------------

for i = 1:Net.H.Ny

    y = Ny-i;

    for j = 1:Net.H.Nx

        x1 = j-1;
        x2 = j;

        switch Net.H.State(i,j)

            case 0

                plot([x1 x2],[y y],...
                    'Color',c0,...
                    'LineWidth',4);

            case 2

                plot([x1 x2],[y y],...
                    'Color',c2,...
                    'LineWidth',4);

            case 1

                if Net.H.Dir(i,j) > 0

                    xm = x1 + Net.H.Sat(i,j);

                    plot([x1 xm],[y y],...
                        'Color',c2,...
                        'LineWidth',4);

                    plot([xm x2],[y y],...
                        'Color',c0,...
                        'LineWidth',4);

                else

                    xm = x2 - Net.H.Sat(i,j);

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

        if move
            drawMoveMarker((x1+x2)/2,y+0.12,Net.H.Move(i,j));
        end

    end

end

%%---------------------------------------------------
%% Вертикальные
%%---------------------------------------------------

for i = 1:Net.V.Ny

    for j = 1:Net.V.Nx

        x = j;

        y1 = Ny-i+1;
        y2 = Ny-i;

        isClosedBoundary = ~Net.VerticalBC && ...
            (i == 1 || i == Net.V.Ny);

        if isClosedBoundary

            plot([x x],[y1 y2],...
                'Color',[0.6 0.6 0.6],...
                'LineWidth',4);

        else

        switch Net.V.State(i,j)

            case 0

                plot([x x],[y1 y2],...
                    'Color',c0,...
                    'LineWidth',4);

            case 2

                plot([x x],[y1 y2],...
                    'Color',c2,...
                    'LineWidth',4);

            case 1

                if Net.V.Dir(i,j) > 0

                    ym = y1 - Net.V.Sat(i,j);

                    plot([x x],[y1 ym],...
                        'Color',c2,...
                        'LineWidth',4);

                    plot([x x],[ym y2],...
                        'Color',c0,...
                        'LineWidth',4);

                else

                    ym = y2 + Net.V.Sat(i,j);

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

        end

        if move && ~isClosedBoundary
            drawMoveMarker(x+0.12,(y1+y2)/2,Net.V.Move(i,j));
        end

    end

end


%%---------------------------------------------------
%% Узлы
%%---------------------------------------------------

for i = 1:Ny

    y = Ny-i;

    for j = 1:Nx-1

        plot(j,y,...
            'ko',...
            'MarkerFaceColor','k',...
            'MarkerSize',6);

    end

end


%%---------------------------------------------------
%% Предыдущее положение менисков
%%---------------------------------------------------

if isfield(Net.H,'Sat_prev')

    %% Горизонтальные

    for i = 1:Net.H.Ny

        y = Ny-i;

        for j = 1:Net.H.Nx

            if Net.H.State_prev(i,j) ~= 1
                continue
            end

            x1 = j-1;
            x2 = j;

            if Net.H.Dir_prev(i,j) > 0
                xm = x1 + Net.H.Sat_prev(i,j);
            else
                xm = x2 - Net.H.Sat_prev(i,j);
            end

            plot(xm,y,...
                'o',...
                'Color',[0.5 0.5 0.5],...
                'MarkerFaceColor',[0.5 0.5 0.5],...
                'MarkerSize',6);

        end

    end

    %% Вертикальные

    for i = 1:Net.V.Ny

        for j = 1:Net.V.Nx

            if Net.V.State_prev(i,j) ~= 1
                continue
            end

            x = j;

            y1 = Ny-i+1;
            y2 = Ny-i;

            if Net.V.Dir_prev(i,j) > 0
                ym = y1 - Net.V.Sat_prev(i,j);
            else
                ym = y2 + Net.V.Sat_prev(i,j);
            end

            plot(x,ym,...
                'o',...
                'Color',[0.5 0.5 0.5],...
                'MarkerFaceColor',[0.5 0.5 0.5],...
                'MarkerSize',6);

        end

    end

end


axis equal

xl = xlim;
yl = ylim;

dx = diff(xl);
dy = diff(yl);

xlim(xl + [-0.05 0.05]*dx)
ylim(yl + [-0.05 0.05]*dy)

box on

xlabel('x')
ylabel('y')
title('Распространение второй фазы')

drawnow

end


function drawMoveMarker(x,y,moveState)

switch moveState
    case 0
        color = [0.8 0.8 0.8];
    case 1
        color = [0 0.6 0];
    case 2
        color = 'r';
    case 3
        color = [0.5 0.5 0.5];
    otherwise
        return
end

plot(x,y,...
    'o',...
    'MarkerEdgeColor',color,...
    'MarkerFaceColor',color,...
    'MarkerSize',5);

end
