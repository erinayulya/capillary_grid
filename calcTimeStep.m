function Net = calcTimeStep(Net)

tmin = Inf;

for i = 1:size(Net.StateH,1)
    for j = 1:size(Net.StateH,2)

        if Net.StateH(i,j)==1 && Net.MoveH(i,j)==1

            A = Net.Ah(i,j);
            S = Net.SatH(i,j);

            if S < 1-1e-12

                v = abs(Net.Qh(i,j))/A;

                if v>0
                    t = (1-S)*Net.L/v;
                    tmin = min(tmin,t);
                end

            end

        end

    end
end

for i = 1:size(Net.StateV,1)
    for j = 1:size(Net.StateV,2)

        if Net.StateV(i,j)==1 && Net.MoveV(i,j)==1

            A = Net.Av(i,j);
            S = Net.SatV(i,j);

            if S < 1-1e-12

                v = abs(Net.Qv(i,j))/A;

                if v>0
                    t = (1-S)*Net.L/v;
                    tmin = min(tmin,t);
                end

            end

        end

    end
end

Net.dt = tmin;

end
