%% run_identification.m
% Parameter identification of the CNC Simulink model with lsqnonlin.
% Run it in the base workspace (press Run). Use it once per stage:
% change only the "free" list and the time window "win" between runs.
%
% Requirements:
%  - block dialogs use  nominal*multiplier, e.g.  m_x0*f_m_x
%  - init_params.m defines the nominals (m_x0, ...) and the multipliers (f_m_x = 1, ...)
%  - the signals to compare are LOGGED in the model (e.g. 'pos_x', 'vel_x')
%  - Simulink input is a matrix u = [time, tau_1 ... tau_5]
clear; clc; close all;

%% ---------------- SETTINGS (edit) ----------------
mdl      = 'multibody_model';                         % <<< model name
sigNames = {'pos_x', 'vel_x'};                            % <<< logged signals in the model
measCols = {'pos_x', 'vel_x'};                            % <<< matching columns in feedback.csv
free     = {'f_m_x','f_k_x','f_c_x','f_Fc_x','f_bv_x'};   % <<< multipliers estimated in THIS stage
nomNames = {'m_x0','k_x0','c_x0','Fc_x0','bv_x0'};        % <<< their nominal values (same order)
lb = 0.3;  ub = 3;                                        % bounds on the multipliers
win = [0 inf];                  % time window [s] used in the cost (e.g. friction part only)
zeroStart = true;               % subtract the initial value from the measured signals
torqueFile   = 'torque.csv';    % first column time [s], then 5 torque columns (torque_in order)
feedbackFile = 'feedback.csv';  % first column time [s] named t, other columns named as measCols

%% ---------------- LOAD PARAMETERS ----------------
init_params;                                              % nominals + multipliers = 1
if exist('identified_params_latest.m', 'file')
    identified_params_latest;                             % values from previous stages
end
x0  = zeros(1, numel(free));  nom = x0;
for i = 1:numel(free)
    x0(i)  = evalin('base', free{i});
    nom(i) = evalin('base', nomNames{i});
end

%% ---------------- LOAD DATA ----------------
T = readtable(torqueFile);
F = readtable(feedbackFile);
u = [T{:,1}, T{:,2:6}];                                   % input for Simulink
tEnd = u(end,1);
mask = F.t >= win(1) & F.t <= win(2);
ctx.t = F.t(mask);
for j = 1:numel(measCols)
    y = F.(measCols{j});
    if zeroStart, y = y - y(1); end
    ctx.meas{j}  = y(mask);
    ctx.scale(j) = std(ctx.meas{j});                      % normalise each signal
    if ctx.scale(j) == 0, ctx.scale(j) = 1; end
end
ctx.mdl = mdl;  ctx.u = u;  ctx.tEnd = tEnd;
ctx.names = free;  ctx.sig = sigNames;  ctx.zeroStart = zeroStart;

%% ---------------- COST BEFORE ----------------
r0 = resFcn(x0, ctx);
ctx.nres = numel(r0);
fprintf('Initial cost (sum of squares): %.4g\n', sum(r0.^2));

%% ---------------- ESTIMATION ----------------
opts = optimoptions('lsqnonlin', 'Display', 'iter', ...
    'FiniteDifferenceStepSize', 1e-2, 'FunctionTolerance', 1e-8, 'StepTolerance', 1e-6);
[x, resnorm, res, ~, ~, ~, J] = lsqnonlin(@(p) resFcn(p, ctx), x0, ...
    lb*ones(size(x0)), ub*ones(size(x0)), opts);

% approximate 1-sigma uncertainty of each multiplier
sigma2 = resnorm / max(numel(res) - numel(x), 1);
se = sqrt(abs(diag(sigma2 * pinv(full(J' * J))))).';

fprintf('\n%-10s %10s %12s %12s %10s\n', 'param', 'mult', 'nominal', 'identified', 'se(mult)');
for i = 1:numel(x)
    fprintf('%-10s %10.4f %12.5g %12.5g %10.3g\n', free{i}, x(i), nom(i), nom(i)*x(i), se(i));
end
fprintf('Final cost: %.4g\n', resnorm);

%% ---------------- SAVE RESULTS ----------------
stamp = datestr(now, 'yyyymmdd_HHMM');
db = struct();
if exist('ident_db.mat', 'file'), load('ident_db.mat', 'db'); end
for i = 1:numel(x)
    db.(free{i}) = struct('value', x(i), 'se', se(i), 'nominal', nom(i), ...
                          'nomName', nomNames{i}, 'date', stamp);
end
save('ident_db.mat', 'db');

fn  = fieldnames(db);
fid = fopen('identified_params_latest.m', 'w');
fprintf(fid, '%% Identified multipliers, updated %s\n', stamp);
fprintf(fid, '%% Run after init_params. Physical value = nominal * multiplier.\n');
for i = 1:numel(fn)
    d = db.(fn{i});
    fprintf(fid, '%s = %.6g;   %% %s: %.6g -> %.6g (+/- %.2g, %s)\n', ...
        fn{i}, d.value, d.nomName, d.nominal, d.nominal*d.value, d.nominal*d.se, d.date);
end
fclose(fid);
copyfile('identified_params_latest.m', ['identified_params_' stamp '.m']);
save(['ident_result_' stamp '.mat'], 'x', 'x0', 'se', 'free', 'nomNames', 'nom', ...
     'resnorm', 'win', 'sigNames', 'measCols');
fprintf('Saved ident_db.mat, identified_params_latest.m and snapshot %s\n', stamp);

%% ---------------- PLOT: measured vs simulated ----------------
for k = 1:2
    if k == 1, p = x0; ttl = 'before'; else, p = x; ttl = 'after'; end
    rr = resFcn(p, ctx);
    n  = numel(ctx.t);
    figure('Name', ['Fit ' ttl]);
    for j = 1:numel(sigNames)
        subplot(numel(sigNames), 1, j);
        e = rr((j-1)*n + (1:n)) * ctx.scale(j);           % sim - meas
        plot(ctx.t, ctx.meas{j}, ctx.t, ctx.meas{j} + e); grid on;
        legend('measured', 'simulated'); ylabel(sigNames{j}, 'Interpreter', 'none');
        if j == 1, title(ttl); end
    end
    savefig(['fit_' ttl '_' stamp '.fig']);
end

%% ---------------- local function ----------------
function r = resFcn(x, c)
    in = Simulink.SimulationInput(c.mdl);
    in = in.setExternalInput(c.u);
    in = in.setModelParameter('StopTime', num2str(c.tEnd));
    for i = 1:numel(c.names)
        in = in.setVariable(c.names{i}, x(i));
    end
    out = sim(in);
    if ~isempty(out.ErrorMessage)
        if isfield(c, 'nres'), r = 1e3 * ones(c.nres, 1); return; end
        error(out.ErrorMessage);
    end
    r = [];
    for j = 1:numel(c.sig)
        ts = out.logsout.get(c.sig{j}).Values;
        ys = resample(ts, c.t).Data(:);
        if c.zeroStart, ys = ys - ys(1); end
        r = [r; (ys - c.meas{j}) / c.scale(j)]; %#ok<AGROW>
    end
end