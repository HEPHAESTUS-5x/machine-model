%% validate_fwd.m
% Forward validation of the axis models: the MEASURED motor torque is fed to the
% Simulink model (machine_x, machine_y, machine_z) and the position and speed it
% produces are compared with the recorded ones.
%
% Two runs per recording:
%  1) continuous: the whole recording in one simulation. No feedback, so a small
%     torque difference makes the position drift (it integrates twice): this is
%     expected, the real machine would do the same without its controller.
%  2) stroke by stroke: the recording is cut where the axis is at rest (the 0.5 s
%     pauses of the part programs). Every stroke is simulated from rest, from the
%     measured position at its start, with the measured torque of that stroke.
%     This is the meaningful comparison: the error cannot grow over more than one stroke.
% Strokes slower than minSpeed are not simulated: with the torque as the only input
% the friction law (breakaway, Stribeck) is unstable there, the model either sticks
% or runs away whatever the parameters.
%
% The parameters are the ones of init_params.m + identified_params_latest.m.
% Results (PNG, white background, CSV, MAT) go to plots_fwd/.
% Run from the machine-model folder:  >> validate_fwd
clear; clc; close all; bdclose all;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));

mdls      = {'machine_x', 'machine_y', 'machine_z'};   % <<< models to validate
useSets   = {'val'};     % <<< 'val' = recordings not used in the fit; {'val', 'fit'} for all of them
doFull    = true;        % <<< continuous run of the whole recording (drifts, for comparison)
doStrokes = true;        % <<< stroke-by-stroke run
restMin   = 0.25;        % [s]  at rest for at least this long = a pause between strokes
lead      = 0.10;        % [s]  rest simulated before each stroke
minSpeed  = 150;         % [mm/min or deg/min] strokes slower than this are not simulated (0 = all)
zoomLen   = 15;          % [s]  length of the zoom window (the fastest part of the recording)
bands     = [150 500 2000 inf];   % [mm/min or deg/min] speed classes of the summary

cfg   = ident_config();
od    = fullfile(here, 'plots_fwd');
if ~exist(od, 'dir'), mkdir(od); end
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
cB = [0.165 0.471 0.784];   % measured
cO = [0.851 0.510 0.169];   % model

fprintf('Loading recordings\n');
D = ident_load(cfg);

for im = 1:numel(mdls)
mdl = mdls{im};
fprintf('\n=============== %s ===============\n', mdl);
M = cfg.sim.models(strcmp({cfg.sim.models.name}, mdl));
if isempty(M), error('fwd:cfg', 'no entry for %s in cfg.sim.models', mdl); end

% every variable of the model, then the identified values (startFile of ident_sim_cl is NOT used)
init_params;
if exist('identified_params_latest.m', 'file')
    identified_params_latest;
end

n     = numel(M.inputs);
axIdx = zeros(1, n);
for j = 1:n
    axIdx(j) = find(strcmp({cfg.axes.name}, M.inputs{j}), 1);
end
Ax = cfg.axes(axIdx);
su = zeros(1, n);                 % model position output (mm, deg) -> SI
for j = 1:n
    if strcmp(Ax(j).kind, 'lin'), su(j) = cfg.unit.lin; else, su(j) = cfg.unit.rot; end
end

for e = 1:numel(D)
    if ~ismember(D(e).use, useSets), continue; end
    has = D(e).has(axIdx);
    if ~any(has), continue; end
    jm = find(has, 1);                     % axis that is compared and plotted
    if strcmp(Ax(jm).kind, 'lin')
        pk = 1e3;           pu = 'mm';   vk = 6e4;            vu = 'mm/min';
    else
        pk = 180 / pi;      pu = 'deg';  vk = 60 * 180 / pi;  vu = 'deg/min';
    end
    Ts = D(e).Ts;
    [~, h1] = ident_sg_kernels(cfg.filt.order, cfg.filt.frame, Ts);
    P = D(e).pos(:, axIdx);
    T = D(e).tau(:, axIdx);
    P(:, ~has) = 0;
    T(:, ~has) = 0;
    t  = D(e).t - D(e).t(1);
    vm = ident_filt(h1, P(:, jm));                       % measured speed [m/s or rad/s]
    if ~any(abs(vm) > Ax(jm).vmin), continue; end        % the axis does not move in this recording
    fprintf('\n--- %s (%s), axis %s ---\n', D(e).name, D(e).use, upper(Ax(jm).name));
    tag = sprintf('fwd_%s_%s', mdl, D(e).name);
    N   = numel(t);
    pm  = (P(:, jm) - P(1, jm)) * pk;                    % measured position from the start [mm or deg]

    %% ---------- 1) continuous run ----------
    if doFull
        vrest = 4 * Ax(jm).vmin;
        rest  = abs(vm) < vrest | isnan(vm);
        k0    = find(movsum(rest, [0 49]) == 50, 1);
        if isempty(k0), k0 = 1; end
        kk = (k0:N).';
        try
            tic;
            U  = [t(kk) - t(k0), T(kk, :)];
            Ps = simseg(mdl, U, t(kk) - t(k0), su, M.posOut);
            fprintf('continuous run: %.0f s\n', toc);
            pfull = nan(N, 1);
            pfull(kk) = Ps(:, jm) * pk + pm(k0);
            vfull = nan(N, 1);
            vfull(kk) = ident_filt(h1, Ps(:, jm));
            f = newFig();
            a1 = subplot(2, 1, 1); hold on;
            plot(t, pm, 'Color', cB); plot(t, pfull, 'Color', cO);
            ylabel(sprintf('position [%s]', pu)); legend('measured', 'model', 'Location', 'best');
            a2 = subplot(2, 1, 2); hold on;
            plot(t, vm * vk, 'Color', cB); plot(t, vfull * vk, 'Color', cO);
            ylabel(sprintf('speed [%s]', vu)); xlabel('t [s]');
            lightAx([a1 a2]);
            title(a1, sprintf('%s, %s: continuous run with the measured torque (drifts: no feedback)', mdl, D(e).name), 'Interpreter', 'none');
            savePng(f, fullfile(od, [tag '_continuous.png']));
        catch err
            warning('fwd:full', 'continuous run failed: %s', err.message);
        end
    end

    %% ---------- 2) stroke by stroke ----------
    if ~doStrokes, continue; end
    vrest = 4 * Ax(jm).vmin;
    rest  = abs(vm) < vrest | isnan(vm);
    nr    = round(restMin / Ts);
    starts = movsum(rest, [0 nr - 1]) == nr;             % a rest of nr samples starts here
    isRest = movsum(double(starts), [nr - 1 0]) > 0;     % samples that belong to such a rest
    mv     = ~isRest;
    d      = diff([0; mv; 0]);
    s0     = find(d == 1);
    s1     = find(d == -1) - 1;
    nl     = round(lead / Ts);
    seg    = [];
    for s = 1:numel(s0)
        i0 = max(s0(s) - nl, 1);
        i1 = min(s1(s), N);
        if (i1 - i0) * Ts < 0.3, continue; end
        vp = prctile(abs(vm(i0:i1)) * vk, 90);          % speed of the stroke [mm/min or deg/min]
        if vp < minSpeed, continue; end
        seg(end+1, :) = [i0, i1, vp]; %#ok<SAGROW>
    end
    ns = size(seg, 1);
    fprintf('%d strokes to simulate (faster than %g %s)\n', ns, minSpeed, vu);
    if ns == 0, continue; end

    pS = nan(N, 1);  vS = nan(N, 1);                    % model, stroke by stroke
    tab = nan(ns, 8);
    tStart = tic;
    for s = 1:ns
        i0 = seg(s, 1); i1 = seg(s, 2);
        ii = (i0:i1).';
        tl = t(ii) - t(i0);
        try
            Ps = simseg(mdl, [tl, T(ii, :)], tl, su, M.posOut);
        catch err
            warning('fwd:stroke', 'stroke %d failed: %s', s, err.message);
            continue
        end
        ps = Ps(:, jm) * pk + pm(i0);                    % model position, starting from the measured one
        vs = ident_filt(h1, Ps(:, jm));
        pS(ii) = ps;  vS(ii) = vs;
        ev = (vs - vm(ii)) * vk;
        tab(s, :) = [seg(s, 3), (t(i1) - t(i0)), max(pm(ii)) - min(pm(ii)), ...
            ps(end) - pm(i1), max(abs(ps - pm(ii))), rmsn(ev), rmsn(vm(ii) * vk), 100 * rmsn(ev) / rmsn(vm(ii) * vk)];
        if mod(s, 5) == 0 || s == ns
            el = toc(tStart);
            fprintf('  stroke %d/%d, %.0f s elapsed, about %.0f s left\n', s, ns, el, el / s * (ns - s));
        end
    end
    tbl = array2table(tab, 'VariableNames', {'speed', 'duration_s', 'travel', 'endErr', 'maxErr', ...
        'velErrRms', 'velRms', 'velErrPct'});
    writetable(tbl, fullfile(od, [tag '_strokes.csv']));
    save(fullfile(od, [tag '_strokes.mat']), 'tbl', 'seg', 't', 'pm', 'pS', 'vm', 'vS', 'mdl', 'stamp');

    fprintf('\n%-22s %8s %12s %12s %12s\n', sprintf('speed [%s]', vu), 'strokes', ...
        sprintf('end err [%s]', pu), sprintf('max err [%s]', pu), 'speed err %');
    for b = 1:numel(bands) - 1
        m = tbl.speed >= bands(b) & tbl.speed < bands(b+1);
        if ~any(m), continue; end
        fprintf('%8g - %-11g %8d %12.2f %12.2f %12.1f\n', bands(b), bands(b+1), nnz(m), ...
            sqrt(mean(tbl.endErr(m).^2, 'omitnan')), sqrt(mean(tbl.maxErr(m).^2, 'omitnan')), ...
            sqrt(mean(tbl.velErrRms(m).^2, 'omitnan') / mean(tbl.velRms(m).^2, 'omitnan')) * 100);
    end

    % whole recording: measured against model, stroke by stroke
    f = newFig();
    a1 = subplot(3, 1, 1); hold on;
    plot(t, pm, 'Color', cB); plot(t, pS, 'Color', cO);
    ylabel(sprintf('position [%s]', pu)); legend('measured', 'model, every stroke from rest', 'Location', 'best');
    a2 = subplot(3, 1, 2); hold on;
    plot(t, vm * vk, 'Color', cB); plot(t, vS * vk, 'Color', cO);
    ylabel(sprintf('speed [%s]', vu));
    a3 = subplot(3, 1, 3); hold on;
    plot(t, pS - pm, 'Color', [0.35 0.35 0.35]);
    ylabel(sprintf('position error [%s]', pu)); xlabel('t [s]');
    lightAx([a1 a2 a3]);
    linkaxes([a1 a2 a3], 'x');
    title(a1, sprintf('%s, %s: measured torque in, model out', mdl, D(e).name), 'Interpreter', 'none');
    savePng(f, fullfile(od, [tag '_strokes.png']));
    % zoom: the fastest zoomLen seconds
    w  = max(round(zoomLen / Ts), 3);
    en = movmean(double(isfinite(vS)) .* (vm * vk).^2, w, 'omitnan');
    [~, ic] = max(en);
    xl = t(ic) + [-0.5 0.5] * zoomLen;
    xlim(a1, max(xl, t(1)));
    for a = [a1 a2 a3], ylim(a, 'auto'); end
    sel = t >= xl(1) & t <= xl(2) & isfinite(pS);
    if any(sel)
        ylim(a1, [min(pm(sel)) max(pm(sel))] + 0.05 * [-1 1] * max(range(pm(sel)), 1));
        ylim(a2, [min(vm(sel)) max(vm(sel))] * vk + 0.1 * [-1 1] * max(range(vm(sel) * vk), 1));
        ylim(a3, [min(pS(sel) - pm(sel)) max(pS(sel) - pm(sel))] + 0.1 * [-1 1] * max(range(pS(sel) - pm(sel)), 1e-3));
    end
    savePng(f, fullfile(od, [tag '_strokes_zoom.png']));
    close(f);

    % error of every stroke against its speed
    f = newFig();
    a1 = subplot(1, 2, 1);
    semilogx(tbl.speed, tbl.endErr, 'o', 'Color', cB, 'MarkerFaceColor', cB, 'MarkerSize', 4); hold on;
    yline(0, 'Color', [0.5 0.5 0.5]);
    xlabel(sprintf('speed of the stroke [%s]', vu)); ylabel(sprintf('position error at the end of the stroke [%s]', pu));
    a2 = subplot(1, 2, 2);
    semilogx(tbl.speed, tbl.velErrPct, 'o', 'Color', cO, 'MarkerFaceColor', cO, 'MarkerSize', 4);
    xlabel(sprintf('speed of the stroke [%s]', vu)); ylabel('rms speed error / rms speed [%]');
    lightAx([a1 a2]);
    sgtitle(sprintf('%s, %s: every stroke simulated from rest', mdl, D(e).name), 'Interpreter', 'none', 'Color', 'k');
    savePng(f, fullfile(od, [tag '_summary.png']));
    close(f);
end
if bdIsLoaded(mdl), close_system(mdl, 0); end
end   % models
fprintf('\nPNG, CSV and MAT files in %s\n', od);

% =====================================================================
function Ps = simseg(mdl, U, tq, su, posOut)
%SIMSEG  One simulation of the model with the torques U = [t, tau...]; position outputs
%   on the grid tq, in SI, starting from 0.
in = Simulink.SimulationInput(mdl);
in = in.setExternalInput(U);       % this already switches LoadExternalInput on
in = in.setModelParameter('StopTime', num2str(U(end, 1), '%.6f'), ...
    'SolverType', 'Variable-step', 'Solver', 'ode23t', 'MaxStep', '2e-3', 'RelTol', '1e-3', ...
    'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
out = sim(in);
if isprop(out, 'ErrorMessage') && ~isempty(out.ErrorMessage)
    error('fwd:sim', '%s', out.ErrorMessage);
end
np = numel(posOut);
Ps = zeros(numel(tq), np);
for j = 1:np
    ts = out.yout.getElement(posOut(j)).Values;
    [tt, iu] = unique(ts.Time);
    yy = double(ts.Data(:));
    Ps(:, j) = interp1(tt, yy(iu), tq, 'linear', 'extrap') * su(j);
end
Ps = Ps - Ps(1, :);
end

function f = newFig()
f = figure('Visible', 'off', 'Position', [0 0 1400 800], 'Color', 'w');
try, theme(f, 'light'); catch, end        % MATLAB with the dark theme (R2025a and later)
end

function lightAx(axs)
% black text on white, whatever the theme of MATLAB
for a = axs(:).'
    set(a, 'Color', 'w', 'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], ...
        'GridColor', [0.75 0.75 0.75], 'GridAlpha', 0.7, 'Box', 'off');
    grid(a, 'on');
    a.Title.Color = 'k';  a.XLabel.Color = [0.15 0.15 0.15];  a.YLabel.Color = [0.15 0.15 0.15];
    lg = findobj(a.Parent, 'Type', 'legend');
    for l = lg(:).'
        l.Color = 'w'; l.TextColor = 'k'; l.EdgeColor = [0.8 0.8 0.8];
    end
end
end

function savePng(f, file)
exportgraphics(f, file, 'Resolution', 130, 'BackgroundColor', 'white');
fprintf('saved %s\n', file);
end

function v = rmsn(x)
v = sqrt(mean(x(isfinite(x)).^2));
end
