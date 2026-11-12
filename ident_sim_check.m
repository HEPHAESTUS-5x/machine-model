%% ident_sim_check.m
% ONE simulation of one axis model on a short piece of one recording, before
% running ident_sim (which needs about 60 of them). It shows:
%   - how long one simulation takes  -> estimate of the ident_sim run time
%   - measured vs simulated velocity -> whether the model is close to the data
%     (it should follow the shape; ringing, drift or opposite sign = model problem)
% Uses the same data, filter, solver and parameters as ident_sim.
% Run from the machine-model folder:  >> ident_sim_check
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));

mdl  = 'machine_x';        % <<< machine_x, machine_y or machine_z
rec  = 'IDEN_X_DYN_1';     % <<< a recording where that axis moves
tsim = 30;                 % <<< seconds simulated (from the first rest)

cfg = ident_config();
M   = cfg.sim.models(strcmp({cfg.sim.models.name}, mdl));
init_params;
if exist('identified_params_latest.m', 'file')
    identified_params_latest;
end

cfg.data = cfg.data(contains({cfg.data.torque}, rec));
if isempty(cfg.data), error('recording %s is not listed in ident_config.m', rec); end
D = ident_load(cfg);

axIdx = zeros(1, numel(M.inputs));
for j = 1:numel(M.inputs)
    axIdx(j) = find(strcmp({cfg.axes.name}, M.inputs{j}), 1);
end
Ax   = cfg.axes(axIdx);
vmin = [Ax.vmin];
has  = D.has(axIdx);
if ~any(has), error('%s has none of the axes of %s', rec, mdl); end

[~, h1] = ident_sg_kernels(cfg.filt.order, cfg.filt.frame, D.Ts);
P = D.pos(:, axIdx);  T = D.tau(:, axIdx);
P(:, ~has) = 0;       T(:, ~has) = 0;
V = zeros(size(P));
for j = find(has), V(:, j) = ident_filt(h1, P(:, j)); end
rest = all(abs(V(:, has)) < vmin(has), 2);
k0   = find(movsum(rest, [0 49]) == 50, 1);
kk   = (k0 : min(numel(D.t), k0 + round(tsim / D.Ts))).';
t    = D.t(kk) - D.t(k0);

in = Simulink.SimulationInput(mdl);
in = in.setExternalInput([t, T(kk, :)]);
in = in.setModelParameter('StopTime', num2str(t(end)), ...
    'SolverType', 'Variable-step', 'Solver', 'ode23t', 'MaxStep', '2e-3', 'RelTol', '1e-3', ...
    'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
fprintf('Simulating %s on %s, %.0f s ...\n', mdl, rec, t(end));
tic;
out = sim(in);
el = toc;
if isprop(out, 'ErrorMessage') && ~isempty(out.ErrorMessage), error(out.ErrorMessage); end

% time of a full ident_sim run: one evaluation = all 'fit' recordings of the axis
nFitSec = 0;
for e = 1:numel(ident_config().data)
    E = ident_config().data(e);
    if strcmp(E.use, 'fit') && contains(E.torque, ['_' upper(M.inputs{1}) '_'])
        Tt = readtable(E.torque, 'VariableNamingRule', 'preserve');
        nFitSec = nFitSec + Tt.t(end) - Tt.t(1);
    end
end
fprintf('One simulation of %.0f s took %.1f s (%.2f x real time)\n', t(end), el, el / t(end));
fprintf('ident_sim estimate: %.0f s of fit data x about 60 evaluations = %.0f min\n', ...
    nFitSec, el / t(end) * nFitSec * 60 / 60);

figure('Name', sprintf('%s on %s', mdl, rec));
jj = find(has);
for n = 1:numel(jj)
    j  = jj(n);
    ts = out.yout.getElement(M.posOut(j)).Values;
    [tt, iu] = unique(ts.Time);
    yy = double(ts.Data(:));
    if strcmp(Ax(j).kind, 'lin'), su = cfg.unit.lin; vk = 6e4; vu = 'mm/min';
    else,                         su = cfg.unit.rot; vk = 60 * 180 / pi; vu = 'deg/min'; end
    Ps = interp1(tt, yy(iu), t, 'linear', 'extrap') * su;
    Vs = ident_filt(h1, Ps - Ps(1));
    err = sqrt(mean((Vs - V(kk, j)).^2, 'omitnan'));
    subplot(numel(jj), 1, n);
    plot(t, V(kk, j) * vk, t, Vs * vk);
    grid on; legend('measured', 'model'); ylabel(sprintf('v_%s [%s]', Ax(j).name, vu));
    title(sprintf('%s, axis %s: rms error %.4g %s (rms of the measured %.4g)', rec, ...
        upper(Ax(j).name), err * vk, vu, sqrt(mean(V(kk, j).^2)) * vk), 'Interpreter', 'none');
    fprintf('Axis %s: rms velocity error %.4g %s, rms measured %.4g %s\n', upper(Ax(j).name), ...
        err * vk, vu, sqrt(mean(V(kk, j).^2)) * vk, vu);
end
xlabel('t [s]');
