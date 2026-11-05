%% export_fmu.m
% Exports multibody_model as a Model Exchange FMI 3.0 FMU, with the
% generated C source code packed inside the FMU (sources/ folder) and the
% physical parameters as tunable FMU parameters.
% Does NOT change the models. Log: export_fmu.log
% Run from the machine-model folder:  >> export_fmu

here = fileparts(mfilename('fullpath'));
cd(here);
top  = 'multibody_model';
name = [top '_ME30'];
outd = fullfile(here, 'fmu_test');
logf = fullfile(here, 'export_fmu.log');
fid  = fopen(logf, 'w');
cleanup = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w('MATLAB %s   %s\n\n', version, datestr(now));

evalin('base', 'init_params; if exist(''identified_params_latest.m'', ''file''), identified_params_latest; end');
load_system(top);

vars  = Simulink.findVars(top, 'SearchReferencedModels', 'on', 'SourceType', 'base workspace');
names = unique({vars.Name});
w('Exported parameters: %s\n\n', strjoin(names, ', '));

if ~exist(outd, 'dir'), mkdir(outd); end
try
    exportToFMU(top, 'FMUType', 'ME', 'FMIVersion', '3.0', ...
        'SaveDirectory', outd, 'FMUName', name, ...
        'CreateModelAfterGeneratingFMU', 'off', ...
        'SaveSourceCodeToFMU', 'on', ...
        'ExportedParameters', names);
    fmu = fullfile(outd, [name '.fmu']);
    w('exportToFMU ME 3.0: OK  ->  %s\n\n', fmu);

    % Check that the source code really is inside the FMU
    tmp = tempname; files = unzip(fmu, tmp);
    rel = erase(files, [tmp filesep]);
    src = rel(startsWith(rel, ['sources' filesep]));
    w('Files in FMU: %d   files in sources/: %d\n', numel(rel), numel(src));
    w('  %s\n', src{:});
    rmdir(tmp, 's');
    if isempty(src)
        w('\nWARNING: no sources/ folder in the FMU.\n');
    end
catch e
    w('exportToFMU FAILED:\n%s\n', getReport(e, 'extended', 'hyperlinks', 'off'));
end
fprintf('Done. Log written to %s\n', logf);
