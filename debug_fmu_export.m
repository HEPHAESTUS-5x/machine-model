%% debug_fmu_export.m
% Runs the FMU export from the command line and writes the full error
% report (with the internal stack) to fmu_export_debug.log.
% Run it from the machine-model folder:  >> debug_fmu_export

here = fileparts(mfilename('fullpath'));
cd(here);
mdl  = 'multibody_model';
logf = fullfile(here, 'fmu_export_debug.log');
outd = fullfile(here, 'fmu_test');
if ~exist(outd, 'dir'), mkdir(outd); end

fid = fopen(logf, 'w');
cleanup = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});

w('MATLAB %s\n%s\n\n', version, datestr(now));

% Parameters go to the base workspace, which is where the blocks read them
evalin('base', 'init_params; identified_params_latest;');

load_system(mdl);
w('Model dirty (unsaved changes): %s\n', get_param(mdl, 'Dirty'));
w('Solver: %s / %s\n', get_param(mdl, 'SolverType'), get_param(mdl, 'Solver'));

% Root ports as Simulink sees them
ins  = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'Inport');
outs = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'Outport');
w('Inports : %s\n', strjoin(get_param(ins,  'Name'), ', '));
w('Outports: %s\n\n', strjoin(get_param(outs, 'Name'), ', '));

% 1) Does the model compile?
try
    set_param(mdl, 'SimulationCommand', 'update');
    w('Model update: OK\n\n');
catch e
    w('Model update FAILED:\n%s\n\n', getReport(e, 'extended', 'hyperlinks', 'off'));
end

% 2) Variables used by the model (incl. referenced models) and their classes
try
    vars = Simulink.findVars(mdl, 'SearchReferencedModels', 'on');
    for k = 1:numel(vars)
        v = vars(k);
        cls = '?';
        try, cls = evalin('base', sprintf('class(%s)', v.Name)); end %#ok<TRYNC>
        w('var %-12s source=%-15s class=%s\n', v.Name, v.SourceType, cls);
    end
    w('\n');
catch e
    w('findVars FAILED: %s\n\n', e.message);
end

% 3) Export attempts: ME 3.0 (what you want) and CS 3.0 (for comparison)
tries = {'ME', '3.0'; 'CS', '3.0'};
for k = 1:size(tries, 1)
    t = tries{k, 1}; v = tries{k, 2};
    w('==== exportToFMU  FMUType=%s  FMIVersion=%s ====\n', t, v);
    try
        exportToFMU(mdl, 'FMUType', t, 'FMIVersion', v, ...
            'SaveDirectory', outd, 'FMUName', sprintf('%s_%s%s', mdl, t, strrep(v, '.', '')), ...
            'CreateModelAfterGeneratingFMU', 'off');
        w('OK\n\n');
    catch e
        w('%s\n', getReport(e, 'extended', 'hyperlinks', 'off'));
        w('-- stack --\n');
        for s = 1:numel(e.stack)
            w('  %s  (line %d)  %s\n', e.stack(s).name, e.stack(s).line, e.stack(s).file);
        end
        w('\n');
    end
end

fprintf('Done. Log written to %s\n', logf);
