%% ident_sim_cl.m
% Stage 2 of the identification ON THE SIMULINK MODEL, in closed loop.
%
% Why closed loop: driven open loop by the measured torque, the model sits on a
% knife edge at constant speed (motor torque = friction): with friction a few %
% too high it stalls, a few % too low it runs away. The real axis does not,
% because its speed controller corrects it every 2 ms.
% So here the model (machine_x/y/z, unchanged, copied into harness_<model>.slx by
% ident_make_harness) gets the measured torque PLUS the output of a "virtual
% controller" (PID on the position error) that keeps it on the measured motion:
%     model torque = measured torque + tcorr
% tcorr is the torque the model is missing (or has in excess) to reproduce the
% real motion. With the right parameters it is about zero; the fit adjusts the
% parameters (cfg.sim.models(..).free, as scale factors) to make it as small as
% possible. Everything the model contains counts: Simscape friction law, coupling
% spring/damper, input filters, gravity force.
%
% checkOnly = true: one simulation of 30 s per model, plot, no fit (minutes).
% Run from the machine-model folder:  >> ident_sim_cl
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));

mdls      = {'machine_x'};   % <<< machine_x, machine_y, machine_z (one after the other)
checkOnly = false;           % <<< true: quick check (first 30 s of every recording, no fit); false: identification
fbw       = 10;              % [Hz] bandwidth of the virtual position loop (below the 37 Hz coupling)
vfit      = 20;              % [mm/min or deg/min] samples slower than this are left out of the fit:
                             % stick and pre-sliding, which a static friction law cannot reproduce
decim     = 10;              % residual: 1 sample in 10 (20 ms), less correlated

cfg = ident_config();
for im = 1:numel(mdls)
mdl = mdls{im};
fprintf('\n=============== %s (closed loop) ===============\n', mdl);
M = cfg.sim.models(strcmp({cfg.sim.models.name}, mdl));
if isempty(M), error('ident:sim', 'no entry for %s in cfg.sim.models', mdl); end
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>

% init_params first (every variable of the model), then the identified values
init_params;
if exist('identified_params_latest.m', 'file')
    identified_params_latest;
end
free = M.free;
base = zeros(1, numel(free));
for i = 1:numel(free)
    base(i) = evalin('base', free{i});
end

n     = numel(M.inputs);
axIdx = zeros(1, n);
for j = 1:n
    axIdx(j) = find(strcmp({cfg.axes.name}, M.inputs{j}), 1);
end
Ax   = cfg.axes(axIdx);
vmin = [Ax.vmin];
su   = zeros(1, n);                          % model position unit (mm, deg) -> SI
for j = 1:n
    if strcmp(Ax(j).kind, 'lin'), su(j) = cfg.unit.lin; else, su(j) = cfg.unit.rot; end
end

%% ---------------- virtual controller gains ----------------
% plant: motor torque -> position [mm or deg] ~ 1/(g s^2), g = inertia seen by the
% motor per unit of the position output. PID tuned for fbw Hz, damping 0.7.
inertVar = struct('x', 'm_x', 'y', 'm_y0*f_m_y', 'z', 'm_z', 'a', 'J_a', 'c', 'J_c');
w = 2 * pi * fbw;
K = struct('P', {}, 'I', {}, 'D', {}, 'N', {});
for j = 1:n
    g = evalin('base', inertVar.(Ax(j).name)) * Ax(j).r * su(j);   % N*m per (mm/s^2 or deg/s^2)
    K(j).P = g * w^2;
    K(j).D = 2 * 0.7 * w * g;
    K(j).I = K(j).P * w / 5;
    K(j).N = 10 * w;
end
h = ident_make_harness(mdl, M, K);
fprintf('Test bench %s.slx built (virtual controller %.0f Hz)\n', h, fbw);

%% ---------------- data ----------------
fprintf('Loading recordings\n');
D = ident_load(cfg);
X = struct('name', {}, 'use', {}, 'u', {}, 't', {}, 'tau', {}, 'scale', {}, 'has', {}, 'w', {});
for e = 1:numel(D)
    has = D(e).has(axIdx);
    if ~any(has), continue; end
    [~, h1] = ident_sg_kernels(cfg.filt.order, cfg.filt.frame, D(e).Ts);
    P = D(e).pos(:, axIdx);
    T = D(e).tau(:, axIdx);
    P(:, ~has) = 0;
    T(:, ~has) = 0;
    V = zeros(size(P));
    for j = find(has), V(:, j) = ident_filt(h1, P(:, j)); end
    if ~any(any(abs(V(:, has)) > vmin(has))), continue; end
    rest = all(abs(V(:, has)) < vmin(has) | isnan(V(:, has)), 2);
    k0   = find(movsum(rest, [0 49]) == 50, 1);
    if isempty(k0), warning('ident:sim', '%s: never at rest, skipped', D(e).name); continue; end
    kk = (k0:numel(D(e).t)).';
    if checkOnly, kk = kk(1:min(end, round(30 / D(e).Ts))); end
    t    = D(e).t(kk) - D(e).t(k0);
    pref = (P(kk, :) - P(k0, :)) ./ su;              % mm or deg, from 0
    wk = false(numel(kk), n);                        % samples used in the residual
    wk(1:decim:end, :) = true;
    wk = wk & abs(V(kk, :)) > vfit * su / 60;
    X(end+1) = struct('name', D(e).name, 'use', D(e).use, 'u', [t, T(kk, :), pref], 't', t, ...
        'tau', T(kk, :), 'scale', max(std(T(kk, :), 0, 1), 0.05), 'has', has, 'w', wk); %#ok<SAGROW>
end
if isempty(X), warning('ident:sim', 'no recording where the axes of %s move: skipped', mdl); continue; end
isFit = strcmp({X.use}, 'fit');
if ~any(isFit), warning('ident:sim', 'no ''fit'' recording for %s: skipped', mdl); continue; end
fprintf('%s: %d recordings for the fit, %d for validation\n', mdl, nnz(isFit), nnz(~isFit));

clear ctx
ctx.h = h; ctx.n = n; ctx.free = free; ctx.base = base; ctx.decim = decim;

%% ---------------- fit ----------------
x0 = ones(1, numel(free));
ctx.X = X(isFit);
tic;
r0 = resFcn(x0, ctx);
fprintf('Initial cost: %.5g   (one evaluation %.0f s)\n', sum(r0.^2), toc);
x = x0; se = nan(size(x0)); resnorm = sum(r0.^2);
if ~checkOnly
    ctx.nres = numel(r0);
    opts = optimoptions('lsqnonlin', 'Display', 'iter', 'FiniteDifferenceStepSize', 1e-2, ...
        'FunctionTolerance', 1e-6, 'StepTolerance', 1e-4, 'MaxIterations', 15);
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

    store = ident_store('load');
    notes = repmat({sprintf('refined by closed-loop simulation of %s', mdl)}, 1, numel(free));
    store = ident_store('set', store, free, base .* x, base .* se, ['simcl ' mdl], stamp, notes);
    ident_store('write', store, stamp);
end

%% ---------------- plots: torque the model needs vs measured ----------------
ctx.X = X;
[~, simB] = resFcn(x0, ctx);
if checkOnly, simA = simB; else, [~, simA] = resFcn(x, ctx); end
for e = 1:numel(X)
    f = figure('Name', sprintf('%s %s (%s)', mdl, X(e).name, X(e).use));
    jj = find(X(e).has);
    for k = 1:numel(jj)
        j = jj(k);
        subplot(numel(jj), 1, k);
        plot(X(e).t, X(e).tau(:, j), X(e).t, X(e).tau(:, j) + simB{e}.tc(:, j));
        if ~checkOnly, hold on; plot(X(e).t, X(e).tau(:, j) + simA{e}.tc(:, j)); end
        grid on;
        ylabel(sprintf('tau_%s [N*m]', Ax(j).name));
        wj = X(e).w(:, j);                 % rms over the samples used in the fit (moving)
        eB = sqrt(mean(simB{e}.tc(wj, j).^2)); eA = sqrt(mean(simA{e}.tc(wj, j).^2));
        title(sprintf('%s (%s), axis %s: rms missing torque (moving, > vfit) %.3g -> %.3g N*m (rms of the torque %.3g)', ...
            X(e).name, X(e).use, upper(Ax(j).name), eB, eA, sqrt(mean(X(e).tau(:, j).^2))), 'Interpreter', 'none');
        if checkOnly, legend('measured', 'model needs');
        else, legend('measured', 'model needs, before', 'model needs, after'); end
        fprintf('%s %s axis %s: rms missing torque %.3g N*m (torque rms %.3g), max position error %.3g\n', ...
            X(e).name, X(e).use, upper(Ax(j).name), eA, sqrt(mean(X(e).tau(:, j).^2)), simA{e}.pe(j));
    end
    xlabel('t [s]');
    if ~checkOnly, savefig(f, sprintf('ident_simcl_%s_%s_%s.fig', mdl, X(e).name, stamp)); end
end
end   % models

% =====================================================================
function [r, sims] = resFcn(s, c)
persistent nEval
if isempty(nEval), nEval = 0; end
nEval = nEval + 1;
tEval = tic;
r    = [];
sims = cell(1, numel(c.X));
for e = 1:numel(c.X)
    E  = c.X(e);
    in = Simulink.SimulationInput(c.h);
    in = in.setExternalInput(E.u);
    in = in.setModelParameter('StopTime', num2str(E.t(end)), ...
        'SolverType', 'Variable-step', 'Solver', 'ode23t', 'MaxStep', '2e-3', 'RelTol', '1e-3', ...
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
            r = 1e3 * ones(c.nres, 1);
            return
        end
        error('ident:sim', 'simulation of %s failed: %s', c.h, msg);
    end
    tc = zeros(numel(E.t), c.n);
    pe = zeros(1, c.n);
    for j = 1:c.n
        ts = out.yout.getElement(j).Values;                 % tcorr
        [tt, iu] = unique(ts.Time); yy = double(ts.Data(:));
        tc(:, j) = interp1(tt, yy(iu), E.t, 'linear', 'extrap');
        ts = out.yout.getElement(c.n + j).Values;           % model position
        [tt, iu] = unique(ts.Time); yy = double(ts.Data(:));
        pe(j) = max(abs(interp1(tt, yy(iu), E.t, 'linear', 'extrap') - E.u(:, 1 + c.n + j)));
    end
    for j = find(E.has)
        r = [r; tc(E.w(:, j), j) / E.scale(j)]; %#ok<AGROW>
    end
    sims{e} = struct('tc', tc, 'pe', pe);
end
fprintf('  evaluation %d: %.0f s, cost %.4g\n', nEval, toc(tEval), sum(r.^2));
end
