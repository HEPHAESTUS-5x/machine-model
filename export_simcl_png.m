%% export_simcl_png.m
% PNG copies of the ident_sim_cl results, in plots_simcl/:
%  - every ident_simcl_*.fig (all models, all runs): full view + _zoom (15 % of the record).
%    Figures already exported are skipped (set force = true to redo them).
%  - missing torque against speed, for every run saved as ident_simcl_<model>_<stamp>.mat
%    (written by ident_sim_cl from now on). Runs made before that have no .mat: for
%    them only the workspace of the LAST ident_sim_cl run can be used.
% Run from the machine-model folder:  >> export_simcl_png
force = false;      % <<< true: export everything again
od = fullfile(pwd, 'plots_simcl');
if ~exist(od, 'dir'), mkdir(od); end

% ---- figures ----
f = dir('ident_simcl_*.fig');
for k = 1:numel(f)
    [~, nm] = fileparts(f(k).name);
    if ~force && exist(fullfile(od, [nm '.png']), 'file'), continue; end
    h = openfig(f(k).name, 'invisible');
    set(h, 'Position', [0 0 1600 900]);
    exportgraphics(h, fullfile(od, [nm '.png']), 'Resolution', 110);
    for a = findobj(h, 'Type', 'axes').'
        xl = xlim(a);
        xlim(a, xl(1) + [0.30 0.45] * diff(xl));
        ylim(a, 'auto');
    end
    exportgraphics(h, fullfile(od, [nm '_zoom.png']), 'Resolution', 110);
    close(h);
    fprintf('saved %s (.png, _zoom.png)\n', nm);
end

% ---- missing torque against speed ----
runs = {};
mf = dir('ident_simcl_*.mat');
for k = 1:numel(mf)
    runs{end+1} = load(mf(k).name); %#ok<SAGROW>
    runs{end}.tag = erase(erase(mf(k).name, 'ident_simcl_'), '.mat');
end
if exist('simA', 'var') && exist('X', 'var') && exist('n', 'var') && exist('mdl', 'var')
    runs{end+1} = struct('X', X, 'simA', {simA}, 'n', n, 'mdl', mdl, 'tag', [mdl '_workspace']);
end
for k = 1:numel(runs)
    R = runs{k};
    for e = 1:numel(R.X)
        for j = find(R.X(e).has)
            png = fullfile(od, sprintf('%s_%s_missing_vs_speed.png', R.tag, R.X(e).name));
            if ~force && exist(png, 'file'), continue; end
            t  = R.X(e).t;
            p  = R.X(e).u(:, 1 + R.n + j);                       % measured position [mm or deg]
            v  = gradient(movmean(p, 11), t) * 60;               % [mm/min or deg/min]
            tc = R.simA{e}.tc(:, j);                             % missing torque [N*m]
            m  = abs(v) > 20;
            h = figure('Visible', 'off', 'Position', [0 0 1200 700]);
            semilogx(abs(v(m)), tc(m) .* sign(v(m)), '.', 'MarkerSize', 2); grid on;
            xlabel('|v| [mm/min or deg/min]'); ylabel('missing torque, in the direction of motion [N*m]');
            title(sprintf('%s, %s (%s): missing torque against speed', R.mdl, R.X(e).name, R.X(e).use), ...
                'Interpreter', 'none');
            exportgraphics(h, png, 'Resolution', 110);
            close(h);
            fprintf('saved %s\n', png);
        end
    end
end
fprintf('PNGs in %s\n', od);
