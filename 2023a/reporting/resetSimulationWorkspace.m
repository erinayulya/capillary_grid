function resetSimulationWorkspace(openingInterface)
%RESETSIMULATIONWORKSPACE Clear previous in-memory results and all figure windows.
% main consumes only fresh runParameters and the one-shot runRecordResults flag.
% run calls with true to clear the base workspace before creating its UI.
% Saved files and MATLAB's path are not changed.
if nargin < 1, openingInterface = false; end
delete(findall(groot,'Type','figure'));
clear simulationReport
if openingInterface
    evalin('base','clearvars');
else
    evalin('caller', [ ...
        'clearvars -except runParameters runRecordResults; ' ...
        'if exist(''runParameters'',''var''), Net = runParameters; end; ' ...
        'clear runParameters;']);
end
end
