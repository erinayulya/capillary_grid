function testCheckResults()
%TESTCHECKRESULTS Положительные и намеренно повреждённые MAT-наборы.
% Создаёт изолированную папку в tmp/; сохранённые results не меняет.
root=fileparts(fileparts(mfilename('fullpath')));
if ~isfolder(fullfile(root,'tmp')), mkdir(fullfile(root,'tmp')); end
suite=tempname(fullfile(root,'tmp'));
mkdir(suite);
count=0;
base=sequence();
checkCase('valid',base,'Вторая фаза достигла правой границы.','',true);

% New files expose the PDF state as Net; equation checks must use solvedNet.
samples=base;
for index=1:numel(samples)
    samples{index}.solvedNet=samples{index}.Net;
    if index>1, samples{index}.Net.P(:)=-999; end
end
checkCase('display_and_solution',samples,'Вторая фаза достигла правой границы.','',true);

samples=base; samples{2}.Net.P=101;
checkCase('pressure',samples,'Вторая фаза достигла правой границы.','[WARNING][1]',false);
samples=base; samples{2}.Net.H.Q(1)=samples{2}.Net.H.Q(1)+2e-19;
checkCase('balance',samples,'Вторая фаза достигла правой границы.','[ERROR][2]',false);
samples=base; samples{2}.Net.H.Q(1)=samples{2}.Net.H.Q(1)+1e-21;
checkCase('balance_tolerance',samples,'Вторая фаза достигла правой границы.','',true);
samples=base; samples{2}.Net.H.Q=-samples{2}.Net.H.Q;
checkCase('reverse_flow',samples,'Вторая фаза достигла правой границы.','[ERROR][3]',false);
samples=base; samples{1}.Net.V.Move(1)=1;
checkCase('water_state',samples,'Вторая фаза достигла правой границы.','[ERROR][4]',false);
samples=base; samples{3}.Net.H.Regime(1)=3;
checkCase('oil_state',samples,'Вторая фаза достигла правой границы.','[ERROR][5]',false);
samples=base; samples{2}.Net.H.Move(2)=3; samples{2}.Net.H.Regime(2)=0;
checkCase('held_pressure_flow',samples,'Вторая фаза достигла правой границы.','[ERROR][6]',false);
samples=base; samples{2}.Net.H.Regime(2)=0;
checkCase('moving_regime',samples,'Вторая фаза достигла правой границы.','[ERROR][7]',false);
samples=base; samples{2}.Net.H.Q(:)=0; samples{2}.Net.dt=Inf;
checkCase('moving_zero_flow',samples,'Вторая фаза достигла правой границы.','[ERROR][7]',false);
samples=base; samples{2}.Net.H.Move(2)=2; samples{2}.Net.H.Regime(2)=0;
checkCase('trapped_flow',samples,'Вторая фаза достигла правой границы.','[ERROR][8]',false);
samples=base; samples{1}.Net.V.State(1)=1; samples{1}.Net.V.Dir(1)=1;
samples{1}.Net.V.Move(1)=2;
checkCase('lost_trap',samples,'Вторая фаза достигла правой границы.','[ERROR][9]',false);
samples=base; samples{2}.Net.V.State(1)=1; samples{2}.Net.V.Move(1)=2;
samples{2}.Net.V.Dir(1)=1;
checkCase('unexpected_birth',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.H.State(2)=0; samples{2}.Net.H.Dir(2)=0;
samples{2}.Net.H.Move(2)=0; samples{2}.Net.H.Regime(2)=0;
checkCase('missing_birth',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.H.State(1)=0; samples{2}.Net.H.Sat(1)=0;
checkCase('disappeared_meniscus',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.H.Dir(2)=-1;
checkCase('reverse_direction',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.H.Sat(2)=0.2;
checkCase('wrong_displacement',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.H.Sat_prev(1)=0.2;
checkCase('bad_history',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.dtUsed=2*samples{2}.dtUsed;
checkCase('bad_time',samples,'Вторая фаза достигла правой границы.','[ERROR][10]',false);
samples=base; samples{2}.Net.P=NaN;
checkCase('nan',samples,'Вторая фаза достигла правой границы.','[ERROR][DATA]',false);
samples=base; samples{2}.Net.H.Nx=3;
checkCase('dimensions',samples,'Вторая фаза достигла правой границы.','[ERROR][DATA]',false);
checkCase('limit',base(1:2),'Остановка: достигнут лимит 1 шагов.','',true);
checkCase('false_stop',base(1),'Остановка: нет конечного положительного шага dt.','[ERROR][11]',false);
checkCase('false_breakthrough',base(1),'Вторая фаза достигла правой границы.','[ERROR][11]',false);

held=base{1}; held.Net.H.Move(1)=3; held.Net.H.Regime(1)=0;
held.Net.H.Q(:)=0; held.Net.dt=Inf; held.Net.H.P0=1; held.Net.P=0;
checkCase('valid_capillary_stop',{held},'Остановка: нет конечного положительного шага dt.','',true);
equal=held; equal.Net.H.P0=2*equal.Net.sigma*cos(equal.Net.theta)/sqrt(equal.Net.H.A(1)/pi);
checkCase('threshold_equality',{equal},'Остановка: нет конечного положительного шага dt.','',true);
stale=held; stale.Net.H.Regime(1)=3;
checkCase('inactive_regime',{stale},'Остановка: нет конечного положительного шага dt.','[WARNING][7]',false);
lag=held; lag.Net.H.P0=100;
checkCase('held_new_pressure',{lag},'Остановлено пользователем.','',true);
checkCase('false_capillary_stop',{lag},'Остановка: нет конечного положительного шага dt.','[ERROR][11]',false);
open=held; open.Net.VerticalBC=true; open.Net.V.P0=200; open.Net.P=150;
checkCase('open_boundary_pressure',{open},'Остановка: нет конечного положительного шага dt.','',true);
negative=held; negative.Net.H.P0=-100; negative.Net.P=-50;
checkCase('negative_boundary_pressure',{negative},'Остановка: нет конечного положительного шага dt.','',true);

checkCase('branching',branchingSequence(),'Остановка: достигнут лимит 1 шагов.','',true);
checkCase('vertical_reverse',verticalReverseSequence(),'Остановка: достигнут лимит 1 шагов.','',true);
checkCase('horizontal_reverse',horizontalReverseSequence(),'Вторая фаза достигла правой границы.','',true);

% Повреждённый MAT и отсутствующий шаг не должны давать all correct.
folder=writeCase('gap',base,'Вторая фаза достигла правой границы.');
delete(fullfile(folder,'step_000001.mat'));
expect(folder,'[ERROR][9/10]',false);
folder=writeCase('corrupt',base,'Вторая фаза достигла правой границы.');
fid=fopen(fullfile(folder,'step_000001.mat'),'w'); fprintf(fid,'not a MAT file'); fclose(fid);
expect(folder,'[ERROR][DATA]',false);
folder=writeCase('no_summary',base,'Вторая фаза достигла правой границы.');
delete(fullfile(folder,'summary.mat'));
expect(folder,'[ERROR][11]',false);
folder=writeCase('no_parameters',base,'Вторая фаза достигла правой границы.');
delete(fullfile(folder,'parameters.mat'));
expect(folder,'[ERROR][10]',false);

fprintf('testCheckResults: %d cases passed. Fixtures: %s\n',count,suite);

    function checkCase(name,samples,status,token,correct)
        folder=writeCase(name,samples,status);
        expect(folder,token,correct);
    end
    function folder=writeCase(name,samples,status)
        folder=fullfile(suite,['run_' name]); mkdir(folder);
        parameters=samples{1}.Net;
        save(fullfile(folder,'parameters.mat'),'parameters');
        for index=1:numel(samples)
            item=samples{index};
            save(fullfile(folder,sprintf('step_%06d.mat',item.step)),'-struct','item');
        end
        Net=samples{end}.Net;
        if isfield(samples{end},'solvedNet'), Net=samples{end}.solvedNet; end
        result=struct('steps',samples{end}.step,'totalTime',samples{end}.elapsedTime,'status',status);
        save(fullfile(folder,'summary.mat'),'Net','result');
    end
    function expect(folder,token,correct)
        report=checkResults(folder);
        assert(report.allCorrect==correct,'Unexpected result for %s',folder);
        text=fileread(report.report);
        if ~isempty(token), assert(contains(text,token),'Missing %s in %s',token,folder); end
        if correct, assert(endsWith(strtrim(text),'all correct')); end
        count=count+1;
    end
end

function samples=sequence()
N=blankNet(1,1);
N.H.State(1)=1; N.H.Move(1)=1; N.H.Dir(1)=1; N.H.Regime(1)=3;
N.H.Q(:)=1e-8; N.P=50; N.dt=0.1;
samples={snapshot(N,0,0,0)};
O=N; N=history(N,O);
N.H.State=[2,1]; N.H.Sat=[1,0]; N.H.Move=[0,1];
N.H.Dir=[0,1]; N.H.Regime=[0,3];
samples{2}=snapshot(N,1,0.1,0.1);
O=N; N=history(N,O);
N.H.State(:)=2; N.H.Sat(:)=1; N.H.Move(:)=0;
N.H.Dir(:)=0; N.H.Regime(:)=0; N.dt=Inf;
samples{3}=snapshot(N,2,0.1,0.2);
end

function samples=branchingSequence()
N=blankNet(2,2); q=1e-8;
N.P=[60,20;30,10]; N.H.Q=[2*q,q,q;0,q,q]; N.V.Q(2,1)=q;
N.H.State(1,1)=1; N.H.Move(1,1)=1; N.H.Dir(1,1)=1; N.H.Regime(1,1)=3;
N.dt=0.05; samples={snapshot(N,0,0,0)};
O=N; N=history(N,O);
N.H.State(1,1)=2; N.H.Sat(1,1)=1; N.H.Move(1,1)=0;
N.H.Dir(1,1)=0; N.H.Regime(1,1)=0;
N.H.State(1,2)=1; N.H.Move(1,2)=1; N.H.Dir(1,2)=1; N.H.Regime(1,2)=3;
N.V.State(2,1)=1; N.V.Move(2,1)=1; N.V.Dir(2,1)=1; N.V.Regime(2,1)=3;
N.dt=0.1; samples{2}=snapshot(N,1,0.05,0.05);
end

function samples=verticalReverseSequence()
N=blankNet(2,1); q=1e-8;
N.P=[20;60]; N.H.Q=[0,q;q,0]; N.V.Q=[0;-q;0];
N.V.State(2)=1; N.V.Move(2)=1; N.V.Dir(2)=-1; N.V.Regime(2)=3;
N.dt=0.1; samples={snapshot(N,0,0,0)};
O=N; N=history(N,O);
N.V.State(2)=2; N.V.Sat(2)=1; N.V.Move(2)=0;
N.V.Dir(2)=0; N.V.Regime(2)=0;
N.H.State(1,2)=1; N.H.Move(1,2)=1; N.H.Dir(1,2)=1; N.H.Regime(1,2)=3;
samples{2}=snapshot(N,1,0.1,0.1);
end

function samples=horizontalReverseSequence()
N=blankNet(1,1); N.H.P0=-100; N.P=-50; N.H.Q(:)=-1e-8;
N.H.State(2)=1; N.H.Move(2)=1; N.H.Dir(2)=-1; N.H.Regime(2)=3;
N.dt=0.1; samples={snapshot(N,0,0,0)};
O=N; N=history(N,O);
N.H.State=[1,2]; N.H.Sat=[0,1]; N.H.Move=[2,0];
N.H.Dir=[-1,0]; N.H.Regime(:)=0; N.H.Q(:)=0; N.P=-100; N.dt=Inf;
samples{2}=snapshot(N,1,0.1,0.1);
end

function N=blankNet(rows,cols)
N=struct('mu1',1e-3,'mu2',4e-3,'L',1e-3,'sigma',1e-3, ...
    'theta',pi/4,'kdyn',2,'bound',2,'VerticalBC',false);
N.H.A=ones(rows,cols+1)*1e-6; N.V.A=ones(rows+1,cols)*1e-6;
for key={'H','V'}
    name=key{1}; [N.(name).Ny,N.(name).Nx]=size(N.(name).A);
    for field={'Sat','State','Move','Dir','Regime','Q'}
        N.(name).(field{1})=zeros(size(N.(name).A));
    end
end
N.H.P0=100; N.V.P0=0; N.P=zeros(rows,cols); N.dt=Inf;
end

function N=history(N,O)
for key={'H','V'}
    name=key{1};
    for field={'Sat','State','Dir'}
        f=field{1}; N.(name).([f '_prev'])=O.(name).(f);
    end
end
end

function S=snapshot(N,step,dt,time)
S=struct('Net',N,'step',step,'dtUsed',dt,'elapsedTime',time);
end
