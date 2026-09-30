function reports = checkResults(target, options)
%CHECKRESULTS Проверить MAT-снимки и записать tests_relults.txt в каждый запуск.
% target: папка results или один запуск. Без аргумента: results этого проекта.
% options: необязательные допуски (поля перечислены ниже).
% Net и MAT не изменяются. Существующий tests_relults.txt перезаписывается.
% ERROR: нарушение данных/уравнений/переходов. WARNING: дополнительное
% требование пользователя, не гарантированное текущей моделью.
% Только отсутствие ERROR и WARNING даёт итоговую строку "all correct".
if nargin < 1 || isempty(target)
    target = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
end
if nargin < 2, options = struct(); end
tol = struct('flow',1e-19, 'pressure',1e-5, 'saturation',1e-12, ...
    'time',1e-12, 'relative',1e-10);
% flow = Newton tol (1e-8) * qScale (1e-11 м³/с).
% pressure = Newton tol (1e-8) * pScale (1e3 Па): диагностический допуск,
% а не гарантированная погрешность отдельного давления.
assert(isstruct(options) && isscalar(options), 'options must be a scalar struct.');
names = fieldnames(options);
for k = 1:numel(names)
    name = names{k};
    assert(isfield(tol,name), 'Unknown tolerance: %s', name);
    validateattributes(options.(name), {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, name);
    tol.(name) = options.(name);
end
target = char(target);
assert(isfolder(target), 'Results directory does not exist: %s', target);
[ok, attr] = fileattrib(target);
assert(ok, 'Cannot resolve directory: %s', target);
target = attr.Name;
if ~isempty(dir(fullfile(target,'step_*.mat'))) || ...
        isfile(fullfile(target,'summary.mat')) || ...
        isfile(fullfile(target,'parameters.mat'))
    folders = {target};
else
    entries = dir(target);
    folders = {};
    for k = 1:numel(entries)
        e = entries(k);
        if ~e.isdir || ismember(e.name,{'.','..'}), continue; end
        path = fullfile(target,e.name);
        if startsWith(e.name,'run_') || ~isempty(dir(fullfile(path,'step_*.mat')))
            folders{end+1} = path; %#ok<AGROW>
        end
    end
end
assert(~isempty(folders), 'No simulation folders found in %s', target);
reports = struct('directory',{},'report',{},'steps',{}, ...
    'errors',{},'warnings',{},'allCorrect',{});
for k = 1:numel(folders)
    reports(k) = checkRun(folders{k},tol);
end
end

function report = checkRun(folder,tol)
reportPath = fullfile(folder,'tests_relults.txt');
[fid,message] = fopen(reportPath,'w','n','UTF-8');
assert(fid >= 0, 'Cannot write %s: %s', reportPath,message);
closer = onCleanup(@() fclose(fid));
errors = 0; warnings = 0; checked = 0;
context = folder;
fprintf(fid,'ПРОВЕРКА СОГЛАСОВАННОСТИ Net\nПапка: %s\nДата: %s\n', ...
    folder,char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fprintf(fid,['Допуски: Q/баланс=%.4g м³/с; P=%.4g Па; Sat=%.4g; ', ...
    'время=%.4g с; относительный=%.4g.\n'], ...
    tol.flow,tol.pressure,tol.saturation,tol.time,tol.relative);
fprintf(fid,['State=0: вода; State=1: мениск; State=2: нефть.\n', ...
    'Проверки 1 и 7 (Regime=0 у неподвижных) — дополнительные требования.\n', ...
    'MAT с flowLaw=twoRegimeCurrentPressure: Move/Regime/Q проверяются по решённому P.\n', ...
    'Старые MAT без метки: выбор Move проверяется по прежнему P до решения.\n', ...
    'Dir сравнивается со знаком Q только при State=1 и |Q|>допуска.\n', ...
    'Move=2: защемление, а не обязательно недостаток давления.\n', ...
    'WARNING также исключает итог all correct.\n\n']);
files = dir(fullfile(folder,'step_*.mat'));
ids = nan(size(files));
for k = 1:numel(files)
    token = regexp(files(k).name,'^step_(\d+)\.mat$','tokens','once');
    if ~isempty(token), ids(k) = str2double(token{1}); end
end
if any(isnan(ids))
    issue('ERROR','FILES','step_*.mat','Некорректные имена файлов шагов.');
end
[ids,order] = sort(ids);
files = files(order);
if isempty(files)
    issue('ERROR','FILES','step_*.mat','Нет сохранённых шагов; проверка не выполнена.');
elseif ids(1) ~= 0
    issue('ERROR','FILES',files(1).name,'Отсутствует начальный шаг 0.');
end
previous = []; previousId = NaN; last = []; lastId = NaN;
for k = 1:numel(files)
    context = fullfile(folder,files(k).name);
    fprintf(fid,'ШАГ %g: %s\n',ids(k),context);
    before = errors+warnings;
    try
        sample = load(context);
        % Equations/transitions concern the solution, not the pre-solve PDF state.
        if isfield(sample,'solvedNet'), sample.Net = sample.solvedNet; end
        requireSample(sample,ids(k));
        N = sample.Net;
        requireNet(N);
        checkSnapshot(N,isCurrentLaw(sample));
        if ids(k)==0
            if sample.dtUsed~=0 || sample.elapsedTime~=0
                issue('ERROR','TIME','dtUsed/elapsedTime','На шаге 0 оба значения должны быть 0.');
            end
            checkInitial(N,isCurrentLaw(sample));
        elseif ~isempty(previous) && ids(k)==previousId+1
            checkTransition(previous,sample);
        else
            issue('ERROR','9/10','history', ...
                'Нет корректного соседнего предыдущего шага; переход не проверен.');
        end
        if k>1 && ids(k)~=ids(k-1)+1
            issue('ERROR','FILES','step','Пропуск или повтор номера: %g -> %g.',ids(k-1),ids(k));
        end
        previous = sample; previousId = ids(k);
        last = sample; lastId = ids(k);
        checked = checked+1;
    catch exception
        issue('ERROR','DATA','MAT/Net','Проверка шага не завершена: %s',exception.message);
        previous = []; previousId = NaN;
        last = []; lastId = NaN;
    end
    if errors+warnings==before, fprintf(fid,'  all correct (этот шаг)\n'); end
    fprintf(fid,'\n');
end
context = fullfile(folder,'summary.mat');
try
    checkEnding(last,lastId);
catch exception
    issue('ERROR','11','summary','Проверка завершения не выполнена: %s',exception.message);
end
fprintf(fid,'\nПроверено снимков: %d/%d; ERROR: %d; WARNING: %d.\n', ...
    checked,numel(files),errors,warnings);
if errors==0 && warnings==0
    fprintf(fid,'all correct\n');
else
    fprintf(fid,'Есть несоответствия; см. сообщения выше.\n');
end
report = struct('directory',folder,'report',reportPath,'steps',checked, ...
    'errors',errors,'warnings',warnings,'allCorrect',errors==0 && warnings==0);
fprintf('Проверка: %s | ERROR=%d WARNING=%d\n',folder,errors,warnings);

    function issue(level,rule,where,format,varargin)
        if strcmp(level,'ERROR'), errors=errors+1; else, warnings=warnings+1; end
        fprintf(fid,'  [%s][%s] %s | %s: %s\n', ...
            level,rule,context,where,sprintf(format,varargin{:}));
    end

    function edges(level,rule,C,mask,description)
        for e = find(mask(:))'
            issue(level,rule,edgeName(C,e), ...
                '%s State=%g Sat=%.17g Move=%g Dir=%g Regime=%g Q=%.17g м³/с; dP=%.17g Pc=%.17g Па.', ...
                description,C.State(e),C.Sat(e),C.Move(e),C.Dir(e), ...
                C.Regime(e),C.Q(e),C.dP(e),C.Pc(e));
        end
    end

    function checkSnapshot(N,currentLaw)
        C = capillaries(N);
        bounds = [0,N.H.P0];
        if N.VerticalBC, bounds(end+1)=N.V.P0; end
        low = min(bounds); high = max(bounds);
        bad = N.P<low-tol.pressure | N.P>high+tol.pressure;
        for index = find(bad(:))'
            [i,j] = ind2sub(size(N.P),index);
            issue('WARNING','1',sprintf('Net.P(%d,%d)',i,j), ...
                'P=%.17g Па вне [%g,%g] ± %g Па. Капиллярные перепады/изолированные узлы могут нарушать этот дополнительный диапазон.', ...
                N.P(index),low,high,tol.pressure);
        end
        balance = N.H.Q(:,1:end-1)-N.H.Q(:,2:end) + ...
            N.V.Q(1:end-1,:)-N.V.Q(2:end,:);
        for index = find(abs(balance(:))>=tol.flow)'
            [i,j] = ind2sub(size(balance),index);
            issue('ERROR','2',sprintf('node(%d,%d)',i,j), ...
                'Qleft-Qright+Qtop-Qbottom=%.17g м³/с, требуется |баланс|<%g.',balance(index),tol.flow);
        end
        meniscus = C.State==1;
        edges('ERROR','3',C,meniscus & abs(C.Q)>tol.flow & C.Dir.*C.Q<0, ...
            'Расход направлен против Dir.');
        edges('ERROR','3',C,meniscus & ~ismember(C.Dir,[-1,1]), ...
            'У мениска Dir должен быть -1 или +1.');
        edges('ERROR','4',C,C.State==0 & (abs(C.Sat)>tol.saturation | ...
            C.Move~=0 | C.Regime~=0 | C.Dir~=0), ...
            'Первая фаза требует Sat=0, Move=0, Regime=0, Dir=0.');
        edges('ERROR','5',C,C.State==2 & (abs(C.Sat-1)>tol.saturation | ...
            C.Move~=0 | C.Regime~=0 | C.Dir~=0), ...
            'Вторая фаза требует Sat=1, Move=0, Regime=0, Dir=0.');
        edges('ERROR','STATE',C,meniscus & (C.Move==0 | C.Sat>=1-1e-12), ...
            'Сохранённый мениск требует Move=1/2/3 и Sat<1-1e-12 после calcState.');
        held = meniscus & C.Move==3;
        % Legacy Move used old pressure; current-law Move uses solved pressure.
        edges('ERROR','6',C,held & abs(C.Q)>=tol.flow, ...
            'При Move=3 требуется |Q|<допуска расхода.');
        moving = meniscus & C.Move==1;
        edges('ERROR','7',C,moving & ~ismember(C.Regime,[1,2,3]), ...
            'Подвижному мениску требуется Regime=1/2/3.');
        edges('WARNING','7',C,meniscus & ~moving & C.Regime~=0, ...
            'Требование Regime=0 у неподвижного мениска не выполнено.');
        if currentLaw
            checkCurrentLaw(N,C);
        else
            edges('ERROR','7',C,moving & abs(C.Q)<=tol.flow, ...
                'Move=1, но расход численно равен нулю.');
        end
        edges('ERROR','8',C,meniscus & C.Move==2 & abs(C.Q)>=tol.flow, ...
            'При Move=2 требуется |Q|<допуска расхода.');
        edges('ERROR','BC',C,C.closed & abs(C.Q)>=tol.flow, ...
            'Закрытая вертикальная граница требует Q=0.');
        edges('ERROR','BC',C,C.closed & meniscus & C.Move~=2, ...
            'Мениск на закрытой границе должен иметь Move=2.');
        expectedDt = nextTime(C,N.L);
        if ~sameTime(N.dt,expectedDt,tol)
            issue('ERROR','TIME','Net.dt','dt=%.17g, ожидается %.17g с по текущим Sat/Q.',N.dt,expectedDt);
        end
    end

    function checkInitial(N,currentLaw)
        file = fullfile(folder,'parameters.mat');
        if ~isfile(file)
            issue('ERROR','10','parameters.mat','Нет исходного состояния; происхождение начальных менисков не проверено.');
            return;
        end
        data = load(file,'parameters');
        assert(isfield(data,'parameters'),'parameters.mat has no parameters.');
        P = data.parameters;
        compareConstants(P,N);
        for key = {'H','V'}
            name = key{1};
            for field = {'Sat','State','Move','Dir','Regime'}
                f = field{1};
                if currentLaw && ismember(f,{'Move','Regime'})
                    continue % Эти коды определяются первым решением, не параметрами.
                end
                if ~isfield(P.(name),f) || ~isequaln(P.(name).(f),N.(name).(f))
                    issue('ERROR','10',sprintf('Net.%s.%s',name,f), ...
                        'Начальное поле отличается от parameters.mat (до продвижения времени).');
                end
            end
        end
    end

    function compareConstants(A,B)
        for field = {'mu1','mu2','L','sigma','theta','kdyn','bound','VerticalBC'}
            f = field{1};
            assert(isfield(A,f),'Previous parameters missing %s.',f);
            assert(isequaln(A.(f),B.(f)),'Parameter Net.%s changed; transition cannot be checked.',f);
        end
        for key = {'H','V'}
            name = key{1};
            for field = {'A','Nx','Ny','P0'}
                f = field{1};
                assert(isequaln(A.(name).(f),B.(name).(f)), ...
                    'Net.%s.%s changed; transition cannot be checked.',name,f);
            end
        end
    end

    function checkTransition(oldSample,newSample)
        O = oldSample.Net; N = newSample.Net;
        compareConstants(O,N);
        old = capillaries(O); C = capillaries(N);
        edges('ERROR','9',C,old.Move==2 & C.Move~=2, ...
            'На предыдущем шаге Move=2; защемление должно сохраняться.');
        for key = {'H','V'}
            name = key{1};
            for field = {'Sat','State','Dir'}
                f = field{1}; prev = [f '_prev'];
                if ~isfield(N.(name),prev) || ~isequaln(N.(name).(prev),O.(name).(f))
                    issue('ERROR','10',sprintf('Net.%s.%s',name,prev), ...
                        'Копия предыдущего состояния отсутствует или не совпадает с соседним MAT.');
                end
            end
        end
        dt = newSample.dtUsed;
        if ~isfinite(dt) || dt<=0 || ~sameTime(dt,O.dt,tol)
            issue('ERROR','10','dtUsed','dtUsed=%.17g с, прежний Net.dt=%.17g с; нужен конечный положительный прежний dt.',dt,O.dt);
            return;
        end
        if ~sameTime(newSample.elapsedTime,oldSample.elapsedTime+dt,tol)
            issue('ERROR','TIME','elapsedTime','Накопленное время не равно прежнему времени + dtUsed.');
        end
        % Независимое восстановление продвижения и топологии, без calcState.
        expectedSat = old.Sat;
        moving = old.State==1 & old.Move==1;
        expectedSat(moving) = min(1,old.Sat(moving) + ...
            abs(old.Q(moving))./old.A(moving)*dt/O.L);
        filled = old.State==1 & expectedSat>=1-1e-12;
        expectedSat(filled) = 1;
        expectedState = old.State; expectedState(filled)=2;
        expectedDir = old.Dir; expectedDir(filled)=0;
        oilNodes = false(C.nodes,1);
        full = expectedState==2;
        oilEnds = [old.first(full); old.second(full); ...
            old.first(expectedState==1 & expectedDir>0); ...
            old.second(expectedState==1 & expectedDir<0)];
        oilNodes(oilEnds(oilEnds>0)) = true;
        % У нового мениска входной узел определяется ПРЕЖНИМ расходом.
        source = old.first;
        source(old.Q<0) = old.second(old.Q<0);
        born = false(size(old.State));
        eligible = old.State==0 & old.Q~=0 & source>0;
        born(eligible) = oilNodes(source(eligible));
        expectedState(born)=1; expectedSat(born)=0;
        expectedDir(born)=sign(old.Q(born));
        for e = find(C.State~=expectedState)'
            issue('ERROR','10',edgeName(C,e), ...
                'Неожиданное появление/исчезновение или пропущенное распространение: State old=%g, new=%g, expected=%g; Sat old=%.17g expected=%.17g.', ...
                old.State(e),C.State(e),expectedState(e),old.Sat(e),expectedSat(e));
        end
        for e = find(abs(C.Sat-expectedSat)>tol.saturation)'
            issue('ERROR','10',edgeName(C,e), ...
                'Неверное продвижение: Sat=%.17g, expected=%.17g; old Q=%.17g м³/с, dtUsed=%.17g с.', ...
                C.Sat(e),expectedSat(e),old.Q(e),dt);
        end
        edges('ERROR','10',C,C.Dir~=expectedDir, ...
            'Dir изменился у прежнего мениска или не соответствует входу нового/сбросу заполненного.');
        edges('ERROR','10',C,C.Sat<old.Sat-tol.saturation, ...
            'Насыщенность уменьшилась: обратное движение не предусмотрено.');
        % Старый порядок проверяется без переинтерпретации архивных данных.
        reference = N;
        pressureSource = 'решённому P';
        if ~isCurrentLaw(newSample)
            reference.P=O.P;
            pressureSource = 'прежнему P';
        end
        decision = capillaries(reference);
        allowed = waterPath(C);
        expectedMove = zeros(size(C.Move));
        m = C.State==1;
        expectedMove(m)=3;
        expectedMove(m & allowed & decision.dP>decision.Pc)=1;
        trapped = m & (old.Move==2 | ~allowed | C.closed);
        expectedMove(trapped)=2;
        nearThreshold = m & ~trapped & abs(decision.dP-decision.Pc)<=tol.pressure;
        mismatch = C.Move~=expectedMove & ~(nearThreshold & ismember(C.Move,[1,3]));
        for e = find(mismatch)'
            issue('ERROR','6/8/9',edgeName(C,e), ...
                'Move=%g, expected=%g по %s; dP=%.17g, Pc=%.17g Па; путь отвода воды=%d, прежний Move=%g.', ...
                C.Move(e),expectedMove(e),pressureSource,decision.dP(e),decision.Pc(e),allowed(e),old.Move(e));
        end
    end

    function checkCurrentLaw(N,C)
        % Независимая проверка явного расхода, без вызова capillaryEquation.
        mu = N.mu1;
        if N.theta >= pi/2, mu = N.mu2; end
        for e = find(C.State==1 & ~C.closed)'
            r = sqrt(C.A(e)/pi);
            resistance = 8/r^2*N.L*(N.mu1*(1-C.Sat(e))+N.mu2*C.Sat(e)) ...
                -2*N.kdyn^3/(3*r)*mu*sin(N.theta);
            coefficient = 2*N.kdyn*N.sigma*sin(N.theta)/r*(mu/N.sigma)^(1/3);
            excess = max(C.dP(e)-C.Pc(e),0);
            expectedRegime = 0; expectedFlow = 0; expectedMove = 3;
            nearBoundary = false;
            if C.Move(e)==2
                expectedMove = 2;
            elseif excess > 0
                expectedMove = 1;
                if resistance <= 0
                    expectedRegime = 1;
                    expectedFlow = C.A(e)*(excess/coefficient)^3;
                else
                    critical = sqrt(coefficient^3/resistance);
                    nearBoundary = abs(excess-critical)<=tol.pressure;
                    expectedFlow = C.A(e)*min((excess/coefficient)^3,excess/resistance);
                    expectedRegime = 1+2*(excess>critical);
                end
            end
            if abs(C.Dir(e)*C.Q(e)-expectedFlow)>=tol.flow
                issue('ERROR','FLOW',edgeName(C,e), ...
                    'Dir*Q=%.17g, ожидается %.17g м³/с по текущему P.', ...
                    C.Dir(e)*C.Q(e),expectedFlow);
            end
            if C.Move(e)~=expectedMove && abs(C.dP(e)-C.Pc(e))>tol.pressure
                issue('ERROR','6/7',edgeName(C,e),'Move=%g, ожидается %g по текущему P.',C.Move(e),expectedMove);
            end
            if C.Regime(e)~=expectedRegime && ...
                    ~(nearBoundary && ismember(C.Regime(e),[1,3]))
                issue('ERROR','7',edgeName(C,e),'Regime=%g, ожидается %g по текущему P.',C.Regime(e),expectedRegime);
            end
        end
    end

    function checkEnding(sample,id)
        assert(~isempty(sample),'No valid final step; termination cannot be checked.');
        assert(isfile(context),'summary.mat is missing; termination reason is unknown.');
        data = load(context,'result','Net');
        assert(isfield(data,'result') && isstruct(data.result),'summary.mat has no result.');
        R = data.result; N = sample.Net;
        assert(isfield(R,'status') && (ischar(R.status) || isstring(R.status)), ...
            'result.status is missing or invalid.');
        status = char(R.status);
        fprintf(fid,'ЗАВЕРШЕНИЕ: %s\n',status);
        if ~isfield(data,'Net') || ~isequaln(data.Net,N)
            issue('ERROR','11','summary.Net','Итоговый Net не совпадает с решением последнего шага (solvedNet; старый формат: Net).');
        end
        if ~isfield(R,'steps') || ~isequal(R.steps,id)
            issue('ERROR','11','result.steps','Число шагов не соответствует последнему MAT.');
        end
        if ~isfield(R,'totalTime') || ~sameTime(R.totalTime,sample.elapsedTime,tol)
            issue('ERROR','11','result.totalTime','Итоговое модельное время не соответствует последнему MAT.');
        end
        breakthrough = any(N.H.State(:,end)==2);
        declaredBreak = contains(status,'достигла правой границы');
        if breakthrough
            fprintf(fid,'Правая граница достигнута.\n');
            if ~declaredBreak
                issue('ERROR','11','result.status','Правая граница достигнута, но указан другой статус.');
            end
            return;
        end
        if declaredBreak
            issue('ERROR','11','result.status','Заявлен прорыв, но на правой границе нет State=2.');
        end
        C = capillaries(N); m = C.State==1; allowed = waterPath(C);
        fprintf(fid,'Без прорыва: менисков=%d, Move=1: %d, Move=2: %d, Move=3: %d.\n', ...
            nnz(m),nnz(m & C.Move==1),nnz(m & C.Move==2),nnz(m & C.Move==3));
        for e = find(m)'
            if C.closed(e)
                reason = 'закрытая вертикальная граница';
            elseif C.Move(e)==2
                if allowed(e)
                    reason = 'историческое защемление (Move=2 необратим); см. проверки соседних шагов';
                else
                    reason = 'нет пути отвода воды';
                end
            elseif C.Move(e)==3 && C.dP(e)<=C.Pc(e)+tol.pressure
                reason = 'капиллярный порог не превышен';
            elseif C.Move(e)==3
                reason = 'удержание НЕ подтверждено новым давлением';
            else
                reason = 'подвижный мениск';
            end
            fprintf(fid,'  %s: %s; Q=%.17g м³/с, dP=%.17g Pc=%.17g Па.\n', ...
                edgeName(C,e),reason,C.Q(e),C.dP(e),C.Pc(e));
        end
        if contains(status,'нет конечного положительного шага')
            if isfinite(N.dt) && N.dt>0
                issue('ERROR','11','Net.dt','Заявлена остановка по dt, но dt конечен и положителен.');
            end
            if N.dt~=Inf || nextTime(C,N.L)~=Inf
                issue('ERROR','11','Net.dt','Не подтверждено корректное отсутствие следующего события (ожидался +Inf).');
            end
            edges('ERROR','11',C,m & C.Move==1, ...
                'При остановке без следующего события остался Move=1; требуется разобрать нулевой расход/состояние.');
            edges('ERROR','11',C,m & C.Move==3 & ~allowed, ...
                'Нет пути отвода воды: причина остановки должна быть Move=2, а не только капиллярный порог.');
            edges('ERROR','11',C,m & C.Move==3 & C.dP>C.Pc+tol.pressure, ...
                'Остановка из-за недостатка давления не подтверждается: ориентированный dP превышает Pc.');
        elseif contains(status,'достигнут лимит') || contains(status,'Остановлено пользователем')
            fprintf(fid,'Остановка административная; неподвижность всех менисков не требуется.\n');
            if contains(status,'достигнут лимит')
                token = regexp(status,'лимит\s+(\d+)','tokens','once');
                if isempty(token) || id~=str2double(token{1})
                    issue('ERROR','11','result.status','Заявленный лимит не совпадает с числом выполненных шагов.');
                end
            end
        elseif contains(status,'Ошибка')
            issue('ERROR','11','result.status','Расчёт завершился ошибкой: %s',status);
        elseif ~declaredBreak
            issue('ERROR','11','result.status','Причина остановки не распознана; полнота проверки не подтверждена.');
        end
    end
end

function requireSample(S,id)
assert(isstruct(S) && isfield(S,'Net'),'MAT has no Net.');
for field = {'step','dtUsed','elapsedTime'}
    name = field{1};
    assert(isfield(S,name),'MAT missing %s.',name);
    validateattributes(S.(name),{'numeric'},{'scalar','real','finite','nonnegative'});
end
assert(S.step==id && S.step==fix(S.step),'step does not match filename.');
end

function requireNet(N)
assert(isstruct(N) && isscalar(N),'Net must be a scalar struct.');
for field = {'mu1','mu2','L','sigma','theta','kdyn','bound','VerticalBC','dt','P','H','V'}
    assert(isfield(N,field{1}),'Net missing %s.',field{1});
end
for field = {'mu1','mu2','L','sigma','bound'}
    validateattributes(N.(field{1}),{'numeric'},{'scalar','real','finite','positive'});
end
validateattributes(N.theta,{'numeric'},{'scalar','real','finite','>=',0,'<=',pi});
validateattributes(N.kdyn,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(N.VerticalBC,{'logical','numeric'},{'scalar','real','finite'});
assert(ismember(N.VerticalBC,[0,1]),'VerticalBC must be logical.');
validateattributes(N.dt,{'numeric'},{'scalar','real','positive','nonnan'});
for key = {'H','V'}
    C = N.(key{1});
    assert(isstruct(C) && isscalar(C),'Net.%s must be a scalar struct.',key{1});
    for field = {'A','Nx','Ny','P0','Sat','State','Move','Dir','Regime','Q'}
        assert(isfield(C,field{1}),'Net.%s missing %s.',key{1},field{1});
    end
    validateattributes(C.A,{'numeric'},{'2d','nonempty','real','finite','positive'});
    validateattributes(C.P0,{'numeric'},{'scalar','real','finite'});
    validateattributes(C.Nx,{'numeric'},{'scalar','real','finite','integer','positive'});
    validateattributes(C.Ny,{'numeric'},{'scalar','real','finite','integer','positive'});
    assert(isequal(size(C.A),[C.Ny,C.Nx]),'Net.%s Nx/Ny disagree with A.',key{1});
    for field = {'Sat','State','Move','Dir','Regime','Q'}
        value = C.(field{1});
        validateattributes(value,{'numeric'},{'real','finite','size',size(C.A)});
    end
    assert(all(C.Sat(:)>=0 & C.Sat(:)<=1),'Net.%s Sat outside [0,1].',key{1});
    assert(all(ismember(C.State(:),0:2)),'Net.%s invalid State.',key{1});
    assert(all(ismember(C.Move(:),0:3)),'Net.%s invalid Move.',key{1});
    assert(all(ismember(C.Regime(:),0:3)),'Net.%s invalid Regime.',key{1});
    assert(all(ismember(C.Dir(:),-1:1)),'Net.%s invalid Dir.',key{1});
end
assert(N.V.Ny==N.H.Ny+1 && N.H.Nx==N.V.Nx+1,'Incompatible H/V dimensions.');
validateattributes(N.P,{'numeric'},{'real','finite','size',[N.H.Ny,N.V.Nx]});
end

function C = capillaries(N)
% Общая нумерация рёбер: H(:), затем V(:). Узлы — индексы P(:).
% Внешние концы имеют индекс 0; внешние резервуары не соединяются в графе.
for field = {'A','Q','Sat','State','Move','Dir','Regime'}
    name = field{1}; C.(name)=[N.H.(name)(:);N.V.(name)(:)];
end
[rh,ch] = ndgrid(1:N.H.Ny,1:N.H.Nx);
[rv,cv] = ndgrid(1:N.V.Ny,1:N.V.Nx);
C.row=[rh(:);rv(:)]; C.col=[ch(:);cv(:)]; C.nH=numel(N.H.A);
C.nodes=numel(N.P);
Pindex = reshape(1:C.nodes,size(N.P));
h1=[zeros(N.H.Ny,1),Pindex]; h2=[Pindex,zeros(N.H.Ny,1)];
v1=[zeros(1,N.V.Nx);Pindex]; v2=[Pindex;zeros(1,N.V.Nx)];
C.first=[h1(:);v1(:)]; C.second=[h2(:);v2(:)];
C.closed=[false(C.nH,1);~N.VerticalBC & (rv(:)==1 | rv(:)==N.V.Ny)];
C.seeds=[ch(:)==N.H.Nx;N.VerticalBC & rv(:)==N.V.Ny];
C.leftH=[ch(:)==1;false(numel(N.V.A),1)];
deltaH=[N.H.P0*ones(N.H.Ny,1),N.P]-[N.P,zeros(N.H.Ny,1)];
deltaV=[N.V.P0*ones(1,N.V.Nx);N.P]-[N.P;zeros(1,N.V.Nx)];
C.dP=C.Dir.*[deltaH(:);deltaV(:)];
C.Pc=2*N.sigma*cos(N.theta)./sqrt(C.A/pi);
end

function name = edgeName(C,e)
if e<=C.nH, key='H'; else, key='V'; end
name=sprintf('Net.%s(%d,%d)',key,C.row(e),C.col(e));
end

function allowed = waterPath(C)
% Независимый обход по узлам и полностью водяным рёбрам (Sat==0).
n = numel(C.A); edge=(1:n)';
ends=[C.first;C.second]; edge=[edge;edge];
inside=ends>0;
incidence=sparse(ends(inside),edge(inside),1,C.nodes,n);
water=C.Sat==0 & ~C.closed;
connected=water & C.seeds;
while true
    nodes=incidence*double(connected)>0;
    expanded=water & (incidence'*double(nodes)>0);
    updated=connected | expanded;
    if isequal(updated,connected), break; end
    connected=updated;
end
destination=C.second; destination(C.Dir<0)=C.first(C.Dir<0);
allowed=false(n,1);
for e = find(C.State==1 & ~C.closed)'
    if C.leftH(e) && C.Dir(e)>0
        allowed(e)=true; % Специальный случай входа в calcCanMove.
    elseif destination(e)==0
        allowed(e)=~C.leftH(e); % Выход влево текущая модель не разрешает.
    else
        neighbours=find(incidence(destination(e),:));
        neighbours(neighbours==e)=[];
        allowed(e)=any(connected(neighbours));
    end
end
end

function dt = nextTime(C,L)
eligible=C.State==1 & C.Move==1 & C.Sat<1-1e-12 & C.Q~=0;
if any(eligible)
    dt=min((1-C.Sat(eligible))*L./(abs(C.Q(eligible))./C.A(eligible)));
else
    dt=Inf;
end
end

function yes = sameTime(a,b,tol)
yes=isnumeric(a) && isnumeric(b) && isscalar(a) && isscalar(b) && ...
    isreal(a) && isreal(b) && (isequal(a,b) || ...
    (isfinite(a) && isfinite(b) && abs(a-b)<=tol.time+tol.relative*max(abs(a),abs(b))));
end

function yes = isCurrentLaw(sample)
yes = isfield(sample,'flowLaw') && ...
    strcmp(sample.flowLaw,'twoRegimeCurrentPressure');
end
