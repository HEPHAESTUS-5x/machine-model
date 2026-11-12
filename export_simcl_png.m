%% export_simcl_png.m
% Saves PNG copies of the ident_sim_cl figures (full view + a zoom on a few
% strokes), and, if the ident_sim_cl variables are still in the workspace, the
% missing torque against speed for every recording. PNGs go to plots_simcl/.
% Run from the machine-model folder after ident_sim_cl:  >> export_simcl_png
od = fullfile(pwd, 'plots_simcl');
if ~exist(od, 'dir'), mkdir(od); end
f = dir('ident_simcl_*.fig');
[~, i] = sort([f.datenum], 'descend');
f = f(i);
stamp = regexp(f(1).name, '\d{8}_\d{4}', 'match', 'once');     % newest run only
f = f(contains({f.name}, stamp));
for k = 1:numel(f)
    h = openfig(f(k).name, 'invisible');
    set(h, 'Position', [0 0 1600 900]);
    [~, nm] = fileparts(f(k).name);
    exportgraphics(h, fullfile(od, [nm '.png']), 'Resolution', 110);
    ax = findobj(h, 'Type', 'axes');
    for a = ax.'
        xl = xlim(a);
        xlim(a, xl(1) + [0.30 0.45] * diff(xl));                 % 15 % of the record
        ylim(a, 'auto');
    end
    exportgraphics(h, fullfile(od, [nm '_zoom.png']), 'Resolution', 110);
    close(h);
    fprintf('saved %s(.png, _zoom.png)\n', nm);
end

if exist('simA', 'var') && exist('X', 'var') && exist('n', 'var')
    for e = 1:numel(X)
        for j = find(X(e).has)
            t  = X(e).t;
            p  = X(e).u(:, 1 + n + j);                          % measured position [mm]
            v  = gradient(movmean(p, 11), t) * 60;              % [mm/min]
            tc = simA{e}.tc(:, j);                              % missing torque [N*m]
            m  = abs(v) > 20;
            h = figure('Visible', 'off', 'Position', [0 0 1200 700]);
            semilogx(abs(v(m)), tc(m) .* sign(v(m)), '.', 'MarkerSize', 2); grid on;
            xlabel('|v| [mm/min]'); ylabel('missing torque, in the direction of motion [N*m]');
            title(sprintf('%s (%s): missing torque against speed', X(e).name, X(e).use), 'Interpreter', 'none');
            exportgraphics(h, fullfile(od, sprintf('%s_missing_vs_speed.png', X(e).name)), 'Resolution', 110);
            close(h);
            fprintf('saved %s_missing_vs_speed.png\n', X(e).name);
        end
    end
else
    fprintf('ident_sim_cl variables not in the workspace: missing-torque plots skipped\n');
end
fprintf('PNGs in %s\n', od);
