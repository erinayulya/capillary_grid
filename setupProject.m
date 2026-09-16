function setupProject()
%SETUPPROJECT Add only the active project folders to the MATLAB path.
% Paths are relative to this file, independent of the current directory.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(root,'model'), fullfile(root,'solver'), ...
    fullfile(root,'visualization'), fullfile(root,'reporting'));
end
