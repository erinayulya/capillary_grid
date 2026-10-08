function report = replayTwoRegimeRun(sourceDirectory,outputRoot)
%REPLAYTWOREGIMERUN Проверочный повтор parameters.mat, не точка запуска модели.
% Читает исходный запуск; создаёт отдельную папку MAT и tests_relults.txt.
% Применяет параметры новой физики из main. Основной main не вызывает/не меняет.
% Не затрагивает base workspace, окна и persistent-сессию simulationReport.
setupProject;
data=load(fullfile(sourceDirectory,'parameters.mat'),'parameters');
parameters=data.parameters;
% Читаем только блок констант main, чтобы проверочный повтор не расходился с ним.
mainSource=fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))),'main.m'));
for field={'k','coef','xi','P_crit_width'}
    name=field{1};
    token=regexp(mainSource,['Net\.' name '\s*=\s*([0-9.eE+\-]+)\s*;'],'tokens','once');
    assert(~isempty(token),'Missing constant Net.%s in main.',name);
    parameters.(name)=str2double(token{1});
end
obsolete=intersect(fieldnames(parameters),{'kdyn','bound'});
if ~isempty(obsolete),parameters=rmfield(parameters,obsolete);end
N=parameters;
if nargin<2, outputRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'results'); end
directory=fullfile(outputRoot,['run_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '_two_regime']);
assert(~isfolder(directory),'Verification directory already exists: %s',directory);
mkdir(directory);
save(fullfile(directory,'parameters.mat'),'parameters');
result=struct('directory',directory,'steps',0,'totalTime',0,'totalComputeTime',0, ...
    'startedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'status','Расчёт не завершён.');
dtUsed=0;
for step=0:200
    timer=tic;
    if step>0
        dtUsed=N.dt;
        for key={'H','V'}
            name=key{1};
            for field={'Sat','State','Dir'}
                f=field{1};N.(name).([f '_prev'])=N.(name).(f);
            end
        end
        N=calcSaturation(N);
        N=calcState(N);
        N=calcCanMove(N);
    end
    N=solvePressureFlow(N); % Ровно один вызов на шаг проверочного повтора.
    N=calcTimeStep(N);
    seconds=toc(timer);
    result.steps=step;result.totalTime=result.totalTime+dtUsed;
    result.totalComputeTime=result.totalComputeTime+seconds;
    saveSimulationStep(N,result,dtUsed,seconds);
    if size(N.V.Q,1)>=2 && size(N.V.Q,2)>=2
        fprintf('step=%d V22: Sat=%.12g Move=%g Regime=%g Q=%.12g dt=%.12g\n', ...
            step,N.V.Sat(2,2),N.V.Move(2,2),N.V.Regime(2,2),N.V.Q(2,2),N.dt);
    end
    if any(N.H.State(:,end)==2)
        result.status='Вторая фаза достигла правой границы.';
        break
    elseif ~isfinite(N.dt) || N.dt<=0
        result.status='Остановка: нет конечного положительного шага dt.';
        break
    elseif step==200
        result.status='Остановка: достигнут лимит 200 шагов.';
    end
end
Net=N;
save(fullfile(directory,'summary.mat'),'Net','parameters','result');
report=checkResults(directory);
fprintf('Verification results: %s\n',directory);
end
