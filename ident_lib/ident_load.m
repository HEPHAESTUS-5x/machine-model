function D = ident_load(cfg)
%IDENT_LOAD  Reads the recordings listed in cfg.data, in SI units on a uniform time grid.
%   D(e).t   [s]            D(e).Ts  sample time [s]
%   D(e).tau (N x nAxes)    motor torque [N*m]
%   D(e).pos (N x nAxes)    load position [m or rad]
%   D(e).has (1 x nAxes)    true if the recording has both columns of the axis
%   D(e).name, D(e).use     file name, 'fit' or 'val'
if isempty(cfg.data)
    error('ident:data', 'no recordings listed: add them to cfg.data in ident_config.m');
end
nAx = numel(cfg.axes);
D = struct('name', {}, 'use', {}, 't', {}, 'Ts', {}, 'tau', {}, 'pos', {}, 'has', {});
for e = 1:numel(cfg.data)
    E = cfg.data(e);
    T = readtable(E.torque, 'VariableNamingRule', 'preserve');
    if isempty(E.feedback)
        F = T;
    else
        F = readtable(E.feedback, 'VariableNamingRule', 'preserve');
    end
    [tT, iT] = unique(T.(cfg.col.time));  T = T(iT, :);
    [tF, iF] = unique(F.(cfg.col.time));  F = F(iF, :);
    Ts = median(diff(tF));
    jit = std(diff(tF)) / Ts;
    if jit > 0.01
        warning('ident:jitter', '%s: sample time jitter %.1f %%, resampled to %.4g s', E.torque, 100 * jit, Ts);
    end
    t = (max(tT(1), tF(1)) : Ts : min(tT(end), tF(end))).';
    tau = nan(numel(t), nAx);
    pos = nan(numel(t), nAx);
    has = false(1, nAx);
    for ia = 1:nAx
        A = cfg.axes(ia);
        if ~ismember(A.tau, T.Properties.VariableNames) || ~ismember(A.pos, F.Properties.VariableNames)
            continue
        end
        if strcmp(A.kind, 'lin'), su = cfg.unit.lin; else, su = cfg.unit.rot; end
        tau(:, ia) = interp1(tT, double(T.(A.tau)), t, 'linear') * cfg.unit.tau;
        pos(:, ia) = interp1(tF, double(F.(A.pos)), t, 'linear') * su;
        has(ia) = true;
    end
    [~, nm] = fileparts(E.torque);
    D(end+1) = struct('name', nm, 'use', E.use, 't', t, 'Ts', Ts, 'tau', tau, 'pos', pos, 'has', has); %#ok<AGROW>
    fprintf('  %-28s %-3s  %7.1f s  Ts = %.4g s  axes: %s\n', nm, E.use, t(end) - t(1), Ts, ...
        strjoin({cfg.axes(has).name}, ' '));
end
end
