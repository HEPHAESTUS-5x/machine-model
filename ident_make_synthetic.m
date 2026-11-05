%% ident_make_synthetic.m
% Writes synthetic recordings with KNOWN parameters to data_synthetic/, to
% check the identification chain before the machine data exist:
%   1) run this script
%   2) set useSynthetic = true in ident_config.m
%   3) run ident_rigid and compare with the values printed here
%      (expect about 1-2 % on the mass, less on the friction)
%   4) set useSynthetic = false again
% The motion copies the IDENT_<axis> programs: constant-velocity sweeps at
% several feeds in both directions with dwells, then short fast strokes.
% Recordings at 2 ms, positions quantised (1 um, 0.0001 deg), torque noise.
clear; clc;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here, 'ident_lib'));
cfg  = ident_config();
outd = fullfile(here, 'data_synthetic');
if ~exist(outd, 'dir'), mkdir(outd); end
rng(1);
Ts  = 0.002;    % recording
dtf = 2e-4;     % generation step

% true values in MODEL units (kg, N, N*s/m, m/s / kg*m^2, N*m, N*m*s/rad, rad/s)
tr.y = struct('m', 400, 'Fc', 300, 'dF',  80, 'fv', 2000, 'vbrk', 2e-3, 'off',   20, 'gs', 0, 'gc', 0);
tr.z = struct('m', 250, 'Fc', 250, 'dF',  60, 'fv', 1500, 'vbrk', 3e-3, 'off', 1800, 'gs', 0, 'gc', 0);
tr.a = struct('m', 2.5, 'Fc',   6, 'dF', 1.5, 'fv',    3, 'vbrk', 0.02, 'off',  0.3, 'gs', 4, 'gc', 0.5);

linFeeds = [10 30 100 300 600 1200 2500 5000 10000] / 6e4;   % m/s
rotFeeds = [30 100 300 1000 3000 6000 10000] / 60 * pi / 180; % rad/s
jobs = { ...
    'Y_fit', 'y', linFeeds,                          0.150,  1.5, [0.002 0.010 0.040], 10000 / 6e4; ...
    'Z_fit', 'z', linFeeds,                          0.150,  1.5, [0.002 0.010 0.040], 10000 / 6e4; ...
    'A_fit', 'a', rotFeeds,                          pi / 3, 10,  [2 10 30] * pi / 180, 10000 / 60 * pi / 180; ...
    'Y_val', 'y', [20 50 200 800 2000 8000] / 6e4,   0.150,  1.5, [0.005 0.020],       8000 / 6e4};

axNames = {cfg.axes.name};
for j = 1:size(jobs, 1)
    [fname, ax, feeds, dmax, amax, strokes, vfast] = jobs{j, :};
    P  = tr.(ax);
    A  = cfg.axes(strcmp(axNames, ax));
    % ---- velocity profile: sweeps, then fast strokes (raised-cosine ramps)
    v = zeros(round(1 / dtf), 1);
    for V = feeds
        d = min(dmax, 4 * V);
        v = [v; move(d, V, amax, dtf); zeros(round(1.5 / dtf), 1); ...
                -move(d, V, amax, dtf); zeros(round(1.5 / dtf), 1)]; %#ok<AGROW>
    end
    for d = strokes
        for rep = 1:3
            v = [v; move(d, vfast, amax, dtf); zeros(round(0.3 / dtf), 1); ...
                    -move(d, vfast, amax, dtf); zeros(round(0.3 / dtf), 1)]; %#ok<AGROW>
        end
    end
    q = cumsum(v) * dtf;
    a = gradient(v, dtf);
    % ---- motor torque = r * (m*a + F(v) + offset + gravity), Simscape friction law
    vs  = P.vbrk * sqrt(2);
    vc  = P.vbrk / 10;
    F   = sqrt(2 * exp(1)) * P.dF * exp(-(v / vs).^2) .* (v / vs) + P.Fc * tanh(v / vc) + P.fv * v;
    tau = A.r * (P.m * a + F + P.off + P.gs * sin(q) + P.gc * cos(q));
    % ---- sample, add noise, quantise
    k   = (1:round(Ts / dtf):numel(v)).';
    t   = (k - 1) * dtf;
    tau = tau(k) + 0.01 * A.r * P.Fc * randn(numel(k), 1);
    if strcmp(A.kind, 'lin')
        pos = round(q(k) / 1e-6) * 1e-6 / cfg.unit.lin;           % mm
    else
        pos = round(q(k) / cfg.unit.rot / 1e-4) * 1e-4;            % deg
    end
    % ---- table with all the axes (the others at rest, small torque noise)
    T = table(t, 'VariableNames', {'t'});
    for i = 1:numel(cfg.axes)
        B = cfg.axes(i);
        if strcmp(B.name, ax)
            T.(B.tau) = tau;
            T.(B.pos) = pos;
        else
            T.(B.tau) = 0.01 * randn(numel(k), 1);
            T.(B.pos) = zeros(numel(k), 1);
        end
    end
    writetable(T, fullfile(outd, [fname '.csv']));
    fprintf('%-6s axis %s: %6.1f s, %d samples\n', fname, upper(ax), t(end), numel(t));
end

fprintf('\nExpected results (model units, compare with ident_rigid):\n');
for ax = {'y', 'z', 'a'}
    P = tr.(ax{1});
    A = cfg.axes(strcmp(axNames, ax{1}));
    M = A.map;
    fprintf('axis %s: %s = %g, %s = %g, breakaway (Fc + dF) = %g, %s = %g, %s = %g, offset = %g', ...
        upper(ax{1}), M.mass, P.m, M.Fc, P.Fc, P.Fc + P.dF, M.visc, P.fv, M.vbrk, P.vbrk, P.off);
    if strcmp(A.gravity, 'sincos')
        fprintf(', %s = %g, %s = %g', M.gsin, P.gs, M.gcos, P.gc);
    end
    fprintf('\n');
end

% =====================================================================
function v = move(d, V, amax, dtf)
% velocity profile of a move of length d at feed V, raised-cosine ramps
Tr = max(1.5 * V / amax, 0.02);
Tc = max(d / V - Tr, 0);
u  = (0:dtf:Tr).' / Tr;
vr = V * (1 - cos(pi * u)) / 2;
v  = [vr; V * ones(round(Tc / dtf), 1); flipud(vr)];
end
