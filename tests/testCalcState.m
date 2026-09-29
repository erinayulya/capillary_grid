function testCalcState()
%TESTCALCSTATE Minimal regression checks for delayed meniscus creation.
setupProject;
targets = {'H',2,3,1; 'H',2,2,-1; 'V',3,2,1; 'V',2,2,-1};
for k=1:size(targets,1)
    N = blankNet();
    key=targets{k,1}; i=targets{k,2}; j=targets{k,3}; dir=targets{k,4};
    if key=='H'
        N.V.State(2,2)=2; N.V.Sat(2,2)=1;
    else
        N.H.State(2,2)=2; N.H.Sat(2,2)=1;
    end
    N=calcState(N);
    assert(N.(key).State(i,j)==0,'Zero flow must not create a meniscus.');
    N.(key).Q(i,j)=-dir;
    N=calcState(N);
    assert(N.(key).State(i,j)==0,'Flow toward the oil node must not create a meniscus.');
    N.(key).Q(i,j)=dir;
    N=calcState(N);
    assert(N.(key).State(i,j)==1 && N.(key).Dir(i,j)==dir, ...
        'A reversed flow away from an existing oil node must create a meniscus.');
    assert(N.(key).Sat(i,j)==0 && N.(key).Move(i,j)==3 && N.(key).Regime(i,j)==0);
    assert(isequaln(calcState(N),N),'Repeated checks must preserve existing menisci.');
end

% Oil in a partial neighbour is available only at its inlet end.
N=blankNet(); N.H.State(2,2)=1; N.H.Sat(2,2)=0.4; N.H.Dir(2,2)=1;
N.V.Q(2,2)=-1;
R=calcState(N);
assert(R.V.State(2,2)==0,'Oil has not reached the shared outlet node.');
N.H.Dir(2,2)=-1;
R=calcState(N);
assert(R.V.State(2,2)==1 && R.V.Dir(2,2)==-1);
N.H.Sat(2,2)=0;
R=calcState(N);
assert(R.V.State(2,2)==1,'An inlet meniscus at Sat=0 still marks an oil node.');

% Completion still creates neighbouring menisci in the same call.
N.H.Dir(2,2)=1; N.H.Sat(2,2)=1;
R=calcState(N);
assert(R.H.State(2,2)==2 && R.H.Sat(2,2)==1 && R.H.Dir(2,2)==0);
assert(R.H.Move(2,2)==0 && R.H.Regime(2,2)==0 && R.V.State(2,2)==1);
fprintf('testCalcState: all checks passed.\n');
end

function N=blankNet()
N=struct();
N.H.A=ones(3,4); N.V.A=ones(4,3);
for key={'H','V'}
    name=key{1}; [N.(name).Ny,N.(name).Nx]=size(N.(name).A);
    for field={'State','Sat','Move','Dir','Regime','Q'}
        N.(name).(field{1})=zeros(size(N.(name).A));
    end
end
end
