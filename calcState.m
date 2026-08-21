function Net = calcState(Net)

tol = 1e-12;

%%-------------------------------------------------------
%% Горизонтальные капилляры
%%-------------------------------------------------------

for i = 1:Net.Ny
    for j = 1:Net.Nx

        if Net.StateH(i,j)==1 && Net.SatH(i,j)>=1-tol

            Net.StateH(i,j)=2;
            Net.SatH(i,j)=1;

            if Net.Qh(i,j)>=0

                nodeRow=i;
                nodeCol=j+1;
                from='L';

            else

                nodeRow=i;
                nodeCol=j;
                from='R';

            end

            Net=processNode(Net,nodeRow,nodeCol,from);

        end

    end
end

%%-------------------------------------------------------
%% Вертикальные капилляры
%%-------------------------------------------------------

for i=1:size(Net.Av,1)
    for j=1:size(Net.Av,2)

        if Net.StateV(i,j)==1 && Net.SatV(i,j)>=1-tol

            Net.StateV(i,j)=2;
            Net.SatV(i,j)=1;

            if Net.Qv(i,j)>=0

                nodeRow=i+1;
                nodeCol=j+1;
                from='U';

            else

                nodeRow=i;
                nodeCol=j+1;
                from='D';

            end

            Net=processNode(Net,nodeRow,nodeCol,from);

        end

    end
end

end


%%==================================================================
%% Обработка одного узла
%%==================================================================

function Net = processNode(Net,row,col,from)

%%-------------------------------------------------------
%% Горизонтальный вправо
%%-------------------------------------------------------

if col<=Net.Nx

    if from~='R'

        if Net.StateH(row,col)==0

            if Net.Qh(row,col)>0

                Net.StateH(row,col)=1;
                Net.SatH(row,col)=0;

            end

        end

    end

end

%%-------------------------------------------------------
%% Горизонтальный влево
%%-------------------------------------------------------

if col>1

    if from~='L'

        if Net.StateH(row,col-1)==0

            if Net.Qh(row,col-1)<0

                Net.StateH(row,col-1)=1;
                Net.SatH(row,col-1)=0;

            end

        end

    end

end

%%-------------------------------------------------------
%% Вертикальный вниз
%%-------------------------------------------------------

if row<Net.Ny

    if col>1 && col<=Net.Nx

        if from~='D'

            if Net.StateV(row,col-1)==0

                if Net.Qv(row,col-1)>0

                    Net.StateV(row,col-1)=1;
                    Net.SatV(row,col-1)=0;

                end

            end

        end

    end

end

%%-------------------------------------------------------
%% Вертикальный вверх
%%-------------------------------------------------------

if row>1

    if col>1 && col<=Net.Nx

        if from~='U'

            if Net.StateV(row-1,col-1)==0

                if Net.Qv(row-1,col-1)<0

                    Net.StateV(row-1,col-1)=1;
                    Net.SatV(row-1,col-1)=0;

                end

            end

        end

    end

end

end