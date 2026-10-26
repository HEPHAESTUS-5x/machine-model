%% fix_converters_and_export.m
% Turns on input filtering on every Simulink-PS Converter in machine_x/y/z
% that is set to "provide derivatives" but provides none, keeping the filter
% time constant already in each block, then exports the Model Exchange
% FMI 3.0 FMU with the physical parameters.
% Log: fix_converters.log      Run from the machine-model folder.

here = fileparts(mfilename('fullpath'));
cd(here);
top  = 'multibody_model';
refs = {'machine_x', 'machine_y', 'machine_z'};
logf = fullfile(here, 'fix_converters.log');
fid  = fopen(logf, 'w');
cleanup = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w('MATLAB %s   %s\n\n', version, datestr(now));

evalin('base', 'init_params; identified_params_latest;');
load_system(top);

for r = 1:numel(refs)
    m = refs{r};
    load_system(m);
    bak = fullfile(here, [m '.slx.bak_nofilter']);
    if ~exist(bak, 'file'), copyfile(which([m '.slx']), bak); end
    blks = find_system(m, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'RegExp', 'on', 'ReferenceBlock', '^nesl_utility/Simulink-PS.Converter$');
    for b = 1:numel(blks)
        blk  = blks{b};
        nice = strrep(blk, newline, ' ');
        mode = get_param(blk, 'FilteringAndDerivatives');
        if strcmp(mode, 'provide') && strcmp(get_param(blk, 'UdotUserProvided'), '0')
            try
                set_param(blk, 'FilteringAndDerivatives', 'filter');
                w('%-36s filter ON, order %s, tau = %s s\n', nice, ...
                  get_param(blk, 'SimscapeFilterOrder'), get_param(blk, 'InputFilterTimeConstant'));
            catch e
                w('%-36s FAILED: %s\n', nice, e.message);
            end
        else
            w('%-36s unchanged (%s)\n', nice, mode);
        end
    end
    save_system(m);
    w('-> %s saved\n\n', m);
end

vars  = Simulink.findVars(top, 'SearchReferencedModels', 'on', 'SourceType', 'base workspace');
names = unique({vars.Name});

outd = fullfile(here, 'fmu_test');
if ~exist(outd, 'dir'), mkdir(outd); end
try
    exportToFMU(top, 'FMUType', 'ME', 'FMIVersion', '3.0', ...
        'SaveDirectory', outd, 'FMUName', [top '_ME30'], ...
        'CreateModelAfterGeneratingFMU', 'off', ...
        'ExportedParameters', names);
    w('exportToFMU ME 3.0: OK  ->  %s\n', fullfile(outd, [top '_ME30.fmu']));
catch e
    w('exportToFMU FAILED:\n%s\n', getReport(e, 'extended', 'hyperlinks', 'off'));
end
fprintf('Done. Log written to %s\n', logf);
