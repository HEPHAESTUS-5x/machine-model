%% ident_rigid.m
% Stage 1 of the identification: rigid model of each axis, fitted by linear
% least squares on the logged motor torque and encoder position (TRACE).
%
%   motor torque = J_eff*acc + friction(v) + offset [+ gravity(q)]
%
% Friction has exactly the shape of the Simscape friction blocks (Coulomb,
% breakaway/Stribeck, viscous), so the estimates go straight into the model.
% Velocity and acceleration come from the position with a zero-phase
% Savitzky-Golay filter; the torque and the regressors get the same
% zero-phase filter (see ident_config.m). No simulation is needed, so this
% runs in seconds and its result does not depend on the initial values.
%
% Output: identified_params_latest.m (+ dated copy), ident_store.mat,
%         ident_rigid_<axis>_*.fig. Then ident_sim.m can refine a few
%         parameters by simulating the Simscape model.
%
% Recommended data: the IDENT_<axis> programs (constant-velocity sweeps at
% 9-10 feeds in both directions, plus short BRISK strokes), one or more
% TRACE recordings per axis, at least one kept aside with use = 'val'.
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));

cfg   = ident_config();
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
fprintf('Loading recordings\n');
D = ident_load(cfg);
store = ident_store('load');

for ia = 1:numel(cfg.axes)
    A = cfg.axes(ia);
    if ~ismember(A.name, cfg.rigid.axes), continue; end
    [R, S] = ident_fit_axis(D, A, cfg);
    if isempty(R)
        fprintf('\nAxis %s: does not move in any ''fit'' recording, skipped\n', upper(A.name));
        continue
    end
    print_axis(A, R);
    plot_axis(A, R, S, cfg, stamp);
    [names, vals, ses, notes] = ident_map_axis(A, R);
    store = ident_store('set', store, names, vals, ses, 'rigid', stamp, notes);
    nv = [names; num2cell(vals)];
    fprintf('model variables:');
    fprintf(' %s = %.5g', nv{:});
    fprintf('\n');
end
ident_store('write', store, stamp);

% =====================================================================
function print_axis(A, R)
if strcmp(A.kind, 'lin')
    um = {'kg', 'N', 'N', 'N*s/m', 'N', 'N', 'N'};
    uv = 'm/s';  vk = 6e4;  vu = 'mm/min';  ur = 'm/rad';
else
    um = {'kg*m^2', 'N*m', 'N*m', 'N*m*s/rad', 'N*m', 'N*m', 'N*m'};
    uv = 'rad/s';  vk = 60 * 180 / pi;  vu = 'deg/min';  ur = 'rad/rad';
end
fprintf('\n===== Axis %s   (model transmission r = %.5g %s)\n', upper(A.name), A.r, ur);
fprintf('recordings %d fit / %d val, samples %d (%d outliers dropped), condition number %.3g\n', ...
    R.nRecFit, R.nRecVal, R.nFit, R.nOut, R.cond);
fprintf('%-8s %14s %14s %-10s %7s\n', 'param', 'torque coeff', 'model value', 'unit', 'se [%]');
for i = 1:numel(R.th)
    rel  = 100 * R.se(i) / max(abs(R.th(i)), eps);
    flag = '';
    if R.active(i)
        flag = '<- at the bound 0';
    elseif rel > 20
        flag = '<- POORLY IDENTIFIED';
    end
    fprintf('%-8s %14.5g %14.5g %-10s %7.2f  %s\n', R.names{i}, R.th(i), R.thM(i), um{i}, rel, flag);
end
fprintf('vbrk     %14.5g %s  (= %.4g %s)', R.vbrk, uv, R.vbrk * vk, vu);
if R.vbrkAtLimit
    fprintf('  <- AT THE LIMIT OF THE SEARCH RANGE, widen A.vbrk_grid');
end
fprintf('\nfit: rms %.4g N*m, R2 %.4f', R.rmsFit, R.r2Fit);
if ~isnan(R.rmsVal)
    fprintf('    validation: rms %.4g N*m, R2 %.4f', R.rmsVal, R.r2Val);
end
fprintf('\n(se are optimistic: the residuals are correlated; trust the validation more)\n');
end

function plot_axis(A, R, S, cfg, stamp)
if strcmp(A.kind, 'lin')
    vk = 6e4;  vu = 'mm/min';
else
    vk = 60 * 180 / pi;  vu = 'deg/min';
end
cFit = [0 0.447 0.741];
cVal = [0.850 0.325 0.098];

% ---- friction curve: plateau means against the fitted law
f1 = figure('Name', ['Friction ' upper(A.name)]);
hold on; grid on;
for k = 1:numel(S)
    runs = ident_plateaus(S(k).v, S(k).a, S(k).mask, S(k).t, cfg.rigid.tmin_plateau);
    if strcmp(S(k).use, 'val'), col = cVal; else, col = cFit; end
    for j = 1:numel(runs)
        ii = runs{j};
        vm = mean(S(k).v(ii), 'omitnan');
        fm = mean(S(k).yfric(ii), 'omitnan');
        if vm > 0, mk = 'o'; else, mk = 's'; end
        plot(abs(vm) * vk, abs(fm), mk, 'Color', col, 'MarkerFaceColor', col);
    end
end
vmax = max(abs(vertcat(S.v)), [], 'omitnan');
vg = logspace(log10(A.vmin), log10(max(vmax, 10 * A.vmin)), 300).';
vs = R.vbrk * sqrt(2);
vc = R.vbrk / 10;
ff = R.th(2) * sqrt(2 * exp(1)) * exp(-(vg / vs).^2) .* (vg / vs) + R.th(3) * tanh(vg / vc) + R.th(4) * vg;
plot(vg * vk, ff, 'k-', 'LineWidth', 1.2);
set(gca, 'XScale', 'log');
xlabel(['|feed| [' vu ']']);
ylabel('|friction torque| at the motor [N m]');
title(sprintf('Axis %s friction: o positive, \\Box negative direction; blue fit, orange validation', upper(A.name)));
savefig(f1, sprintf('ident_rigid_%s_friction_%s.fig', A.name, stamp));

% ---- measured vs predicted torque
n  = numel(S);
f2 = figure('Name', ['Torque ' upper(A.name)]);
for k = 1:n
    subplot(n, 1, k);
    yh = S(k).yhat;
    yh(~S(k).mask) = NaN;
    plot(S(k).t, S(k).y, S(k).t, yh);
    grid on;
    ylabel('N m');
    title(sprintf('%s (%s)', S(k).name, S(k).use), 'Interpreter', 'none');
    if k == 1, legend('measured (filtered)', 'rigid model (moving samples)'); end
end
xlabel('t [s]');
savefig(f2, sprintf('ident_rigid_%s_torque_%s.fig', A.name, stamp));
end
