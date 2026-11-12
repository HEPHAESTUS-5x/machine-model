%% ident_sim.m
% Stage 2 of the identification: refine a few parameters of ONE axis model by
% simulation (output error), starting from the values of ident_rigid.
%
% The model (machine_x, machine_y or machine_z, simulated on its own) is driven
% open loop by the measured motor torques. The velocity it produces is compared
% with the measured velocity; both are obtained from the positions with the same
% zero-phase Savitzky-Golay filter, so the filter cancels out of the comparison
% and the units of the model's velocity outputs do not matter.
% Velocity, not position: in open loop a small friction error makes the
% position drift without bound, while the velocity error stays bounded.
% Each recording is simulated from the first instant where its axes are at rest.
%
% The torque is fed RAW: the Simulink-PS converters already filter it (1 ms).
% The parameters are scale factors on the current values (start 1, bounds in
% ident_config). This replaces run_identification.m.
%
% Run time: one simulation per recording and per function evaluation. Start
% with one or two short recordings.
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));

% mdls = {'machine_x', 'machine_y', 'machine_z'};   % <<< models to refine, one after the other
mdls = 'machine_x'

cfg = ident_config();
for im = 1:numel(mdls)
mdl = mdls{im};
fprintf('\n=============== %s ===============\n', mdl);
M   = cfg.sim.models(strcmp({cfg.sim.models.name}, mdl));
if isempty(M), error('ident:sim', 'no entry for %s in cfg.sim.models', mdl); end
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>

% init_params first (defines EVERY variable the model uses, also the ones that are not
% identified: k, c, A and C inertias...), then the identified values override the
% placeholders. Re-read at each model, so Y starts from what X just wrote.
init_params;
if exist('identified_params_latest.m', 'file')
    identified_params_latest;
end
free = M.free;
base = zeros(1, numel(free));
for i = 1:numel(free)
    base(i) = evalin('base', free{i});
end

%% ---------------- data ----------------
fprintf('Loading recordings\n');
D     = ident_load(cfg);
axIdx = zeros(1, numel(M.inputs));
for j = 1:numel(M.inputs)
    axIdx(j) = find(strcmp({cfg.axes.name}, M.inputs{j}), 1);
end
Ax   = cfg.axes(axIdx);
vmin = [Ax.vmin];
su   = zeros(1, numel(Ax));          % model position output (mm, deg) -> SI
for j = 1:numel(Ax)
    if strcmp(Ax(j).kind, 'lin'), su(j) = cfg.unit.lin; else, su(j) = cfg.unit.rot; end
end

X = struct('name', {}, 'use', {}, 'u', {}, 't', {}, 'vm', {}, 'pm', {}, 'scale', {}, 'h1', {}, 'has', {});
for e = 1:numel(D)
    has = D(e).has(axIdx);                 % axes of this model recorded in this file
    if ~any(has), continue; end            % an axis that was not recorded (e.g. A, C while X moves)
    [~, h1] = ident_sg_kernels(cfg.filt.order, cfg.filt.frame, D(e).Ts);
    P = D(e).pos(:, axIdx);
    T = D(e).tau(:, axIdx);
    P(:, ~has) = 0;                        % ... gets no torque and is not compared
    T(:, ~has) = 0;
    V = zeros(size(P));
    for j = find(has)
        V(:, j) = ident_filt(h1, P(:, j));
    end
    if ~any(any(abs(V(:, has)) > vmin(has))), continue; end   % none of the recorded axes moves
    rest = all(abs(V(:, has)) < vmin(has) | isnan(V(:, has)), 2);
    k0   = find(movsum(rest, [0 49]) == 50, 1);          % 50 samples at rest
    if isempty(k0)
        warning('ident:sim', '%s: never at rest, skipped', D(e).name);
        continue
    end
    kk = (k0:numel(D(e).t)).';
    t  = D(e).t(kk) - D(e).t(k0);
    X(end+1) = struct('name', D(e).name, 'use', D(e).use, 'u', [t, T(kk, :)], 't', t, ...
        'vm', V(kk, :), 'pm', P(kk, :) - P(k0, :), ...
        'scale', max(std(V(kk, :), 0, 1, 'omitnan'), 100 * vmin), 'h1', h1, 'has', has); %#ok<SAGROW>
end
if isempty(X)
    warning('ident:sim', 'no recording where the axes of %s move: skipped', mdl);
    continue
end
isFit = strcmp({X.use}, 'fit');
if ~any(isFit)
    warning('ident:sim', 'all the recordings of %s are marked ''val'': skipped', mdl);
    continue
end
fprintf('%s: %d recordings for the fit, %d for validation\n', mdl, nnz(isFit), nnz(~isFit));

clear ctx
ctx.mdl    = mdl;
ctx.free   = free;
ctx.base   = base;
ctx.posOut = M.posOut;
ctx.su     = su;
ctx.wPos   = cfg.sim.wPos;

%% ---------------- fit ----------------
x0 = ones(1, numel(free));
ctx.X = X(isFit);
r0 = resFcn(x0, ctx);
ctx.nres = numel(r0);
fprintf('Initial cost: %.5g\n', sum(r0.^2));
opts = optimoptions('lsqnonlin', 'Display', 'iter', 'FiniteDifferenceStepSize', 1e-2, ...
    'FunctionTolerance', 1e-6, 'StepTolerance', 1e-4, 'MaxIterations', 30);
[x, resnorm, res, ~, ~, ~, J] = lsqnonlin(@(s) resFcn(s, ctx), x0, ...
    cfg.sim.bounds(1) * x0, cfg.sim.bounds(2) * x0, opts);
sigma2 = resnorm / max(numel(res) - numel(x), 1);
se = sqrt(abs(diag(sigma2 * pinv(full(J' * J))))).';

fprintf('\n%-10s %12s %8s %12s %10s\n', 'variable', 'start', 'scale', 'identified', 'se');
for i = 1:numel(x)
    flag = '';
    if abs(x(i) - cfg.sim.bounds(1)) < 1e-3 || abs(x(i) - cfg.sim.bounds(2)) < 1e-3
        flag = '<- AT THE BOUND: check the model or the rigid result';
    end
    fprintf('%-10s %12.5g %8.4f %12.5g %10.3g  %s\n', free{i}, base(i), x(i), base(i) * x(i), base(i) * se(i), flag);
end
fprintf('Final cost: %.5g (initial %.5g)\n', resnorm, sum(r0.^2));

%% ---------------- save ----------------
store = ident_store('load');
notes = repmat({sprintf('refined by simulation of %s', mdl)}, 1, numel(free));
store = ident_store('set', store, free, base .* x, base .* se, ['sim ' mdl], stamp, notes);
ident_store('write', store, stamp);

%% ---------------- plots: fit and validation recordings ----------------
ctx.X = X;
[~, simB] = resFcn(x0, ctx);
[~, simA] = resFcn(x, ctx);
for e = 1:numel(X)
    f = figure('Name', sprintf('%s %s (%s)', mdl, X(e).name, X(e).use));
    jj = find(X(e).has);
    na = numel(jj);
    for jn = 1:na
        j = jj(jn);
        if strcmp(Ax(j).kind, 'lin'), vk = 6e4; vu = 'mm/min'; else, vk = 60 * 180 / pi; vu = 'deg/min'; end
        subplot(na, 1, jn);
        plot(X(e).t, X(e).vm(:, j) * vk, X(e).t, simB{e}.Vs(:, j) * vk, X(e).t, simA{e}.Vs(:, j) * vk);
        grid on;
        ylabel(sprintf('v_%s [%s]', Ax(j).name, vu));
        eB = rms_nan(simB{e}.Vs(:, j) - X(e).vm(:, j)) * vk;
        eA = rms_nan(simA{e}.Vs(:, j) - X(e).vm(:, j)) * vk;
        title(sprintf('%s (%s), axis %s: rms error %.4g -> %.4g %s', X(e).name, X(e).use, ...
            upper(Ax(j).name), eB, eA, vu), 'Interpreter', 'none');
        if jn == 1, legend('measured', 'before', 'after'); end
    end
    xlabel('t [s]');
    savefig(f, sprintf('ident_sim_%s_%s_%s.fig', mdl, X(e).name, stamp));
end
end   % models

% =====================================================================
function [r, sims] = resFcn(s, c)
r    = [];
sims = cell(1, numel(c.X));
for e = 1:numel(c.X)
    E  = c.X(e);
    in = Simulink.SimulationInput(c.mdl);
    in = in.setExternalInput(E.u);
    % setExternalInput already switches LoadExternalInput on: do not set it again
    in = in.setModelParameter('StopTime', num2str(E.t(end)), ...
        'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
    for i = 1:numel(c.free)
        in = in.setVariable(c.free{i}, s(i) * c.base(i));
    end
    msg = '';
    try
        out = sim(in);
        if isprop(out, 'ErrorMessage'), msg = out.ErrorMessage; end
    catch err
        msg = err.message;
    end
    if ~isempty(msg)
        if isfield(c, 'nres')
            r = 1e3 * ones(c.nres, 1);   % failed simulation: large cost, lsqnonlin steps back
            return
        end
        error('ident:sim', 'simulation of %s failed: %s', c.mdl, msg);
    end
    np = numel(c.posOut);
    Ps = zeros(numel(E.t), np);
    for j = 1:np
        ts = out.yout.getElement(c.posOut(j)).Values;
        [tt, iu] = unique(ts.Time);
        yy = double(ts.Data(:));
        Ps(:, j) = interp1(tt, yy(iu), E.t, 'linear', 'extrap') * c.su(j);
    end
    Ps = Ps - Ps(1, :);
    Vs = zeros(size(Ps));
    for j = 1:np
        Vs(:, j) = ident_filt(E.h1, Ps(:, j));
    end
    for j = find(E.has)
        ev = (Vs(:, j) - E.vm(:, j)) / E.scale(j);
        ev(~isfinite(ev)) = 0;
        r = [r; ev]; %#ok<AGROW>
        if c.wPos > 0
            ep = c.wPos * (Ps(:, j) - E.pm(:, j)) / max(std(E.pm(:, j)), 1e-9);
            r = [r; ep]; %#ok<AGROW>
        end
    end
    sims{e} = struct('Ps', Ps, 'Vs', Vs);
end
end

function v = rms_nan(x)
v = sqrt(mean(x(isfinite(x)).^2));
end
