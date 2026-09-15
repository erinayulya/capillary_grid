%% Согласование давления, расходов и состояний Move
%
% Для Move = 2 и Move = 3 сначала решается статическая задача Q = 0.
% По ее давлению calcCanMove может перевести временно удержанный мениск
% из 3 в 1. Тогда задача решается повторно уже с подвижным мениском.

function Net = updatePressureFlow(Net)

    maxIter = 10;

    % На первом вызове давления еще нет. Начальный режим менисков уже
    % задан вызывающим кодом, поэтому сначала получаем первое решение.
    if ~isfield(Net,'P')
        Net = solvePressureFlow(Net);
        Net = calcRegime(Net);
        Net = calcCanMove(Net);
        return
    end

    for iter = 1:maxIter
        oldMoveH = Net.H.Move;
        oldMoveV = Net.V.Move;

        Net = calcRegime(Net);
        Net = solvePressureFlow(Net);
        Net = calcCanMove(Net);

        if isequal(Net.H.Move,oldMoveH) && isequal(Net.V.Move,oldMoveV)
            return
        end
    end

    error('Не удалось согласовать состояния Move с давлением и расходами.')
end
