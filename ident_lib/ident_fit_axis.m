function [R, S] = ident_fit_axis(D, A, cfg)
%IDENT_FIT_AXIS  Rigid inverse-dynamics fit of one axis (equation error, linear least squares).
%
%   motor torque = th1*acc + th2*phiS(v) + th3*phiC(v) + th4*v + th5 [+ th6*sin(q) + th7*cos(q)]
%
%   q, v, acc : load position, velocity, acceleration [SI], from the position with a
%               zero-phase Savitzky-Golay filter
%   phiS, phiC: Stribeck and Coulomb shapes of the Simscape Translational/Rotational
%               Friction block for a breakaway velocity vbrk:
%               F = sqrt(2e)*(Fbrk-Fc)*exp(-(v/vSt)^2)*v/vSt + Fc*tanh(v/vCoul) + f*v
%               vSt = vbrk*sqrt(2), vCoul = vbrk/10
%   The model is linear in th for a given vbrk, which is found by a 1-D search.
%   The torque and every column go through the same zero-phase filter, then
%   are decimated. Samples at rest (|v| < vmin) are not used: there the
%   torque is whatever the position loop needs, not a function of the motion.
%   th1..th4 >= 0 (lsqlin when available).
%
%   R : estimates [] if the axis never moves in a 'fit' recording.
%       R.th  coefficients in motor torque units, R.thM = R.th / A.r in model units
%   S : per-recording series for the plots (filtered torque, prediction, friction part)

R  = [];
ia = find(strcmp({cfg.axes.name}, A.name), 1);
S  = struct('name', {}, 'use', {}, 't', {}, 'q', {}, 'v', {}, 'a', {}, 'y', {}, ...
            'mask', {}, 'base', {}, 'hp', {}, 'yhat', {}, 'yfric', {});
for e = 1:numel(D)
    if ~D(e).has(ia), continue; end
    Ts = D(e).Ts;
    [h0, h1, h2] = ident_sg_kernels(cfg.filt.order, cfg.filt.frame, Ts);
    hp = ident_sg_kernels(cfg.filt.order, cfg.filt.parallel, Ts);
    x  = D(e).pos(:, ia);
    q  = ident_filt(h0, x);
    v  = ident_filt(h1, x);
    a  = ident_filt(h2, x);
    y  = ident_filt(hp, D(e).tau(:, ia));
    % columns that do not depend on vbrk, already through the parallel filter
    base = [ident_filt(hp, a), ident_filt(hp, v), ident_filt(hp, ones(size(v)))];
    if strcmp(A.gravity, 'sincos')
        base = [base, ident_filt(hp, sin(q)), ident_filt(hp, cos(q))]; %#ok<AGROW>
    end
    mask = abs(v) > A.vmin & all(isfinite(base), 2) & isfinite(y);
    if nnz(mask) < 100, continue; end
    S(end+1) = struct('name', D(e).name, 'use', D(e).use, 't', D(e).t, 'q', q, 'v', v, 'a', a, ...
        'y', y, 'mask', mask, 'base', base, 'hp', hp, 'yhat', [], 'yfric', []); %#ok<AGROW>
end
isFit = strcmp({S.use}, 'fit');
isVal = strcmp({S.use}, 'val');
if ~any(isFit), return; end

nd    = max(1, round(cfg.filt.decimate));
lb    = [0; 0; 0; 0; -Inf];
names = {'inertia', 'dFbrk', 'Fc', 'visc', 'offset', 'gsin', 'gcos'};
if strcmp(A.gravity, 'sincos'), lb = [lb; -Inf; -Inf]; end
names = names(1:numel(lb));
p     = numel(lb);

% ---- 1-D search of the breakaway velocity
g   = A.vbrk_grid(:);
sse = zeros(size(g));
for k = 1:numel(g)
    sse(k) = sse_at(S(isFit), g(k), nd, lb);
end
[~, kb] = min(sse);
lo   = log10(g(max(kb - 1, 1)));
hi   = log10(g(min(kb + 1, numel(g))));
lv   = fminbnd(@(z) sse_at(S(isFit), 10^z, nd, lb), lo, hi, optimset('TolX', 1e-3));
vbrk = 10^lv;

% ---- final fit, one pass of outlier rejection
[W, y] = stack(S(isFit), vbrk, nd);
th   = solve(W, y, lb);
res  = y - W * th;
sig  = 1.4826 * median(abs(res - median(res)));
keep = abs(res) < cfg.rigid.outlier * max(sig, eps);
W = W(keep, :);
y = y(keep);
[th, sseF] = solve(W, y, lb);
n  = numel(y);
s2 = sseF / max(n - p, 1);
se = sqrt(abs(diag(s2 * pinv(W' * W))));   % optimistic: residuals are still correlated

R.names       = names;
R.th          = th;
R.se          = se;
R.active      = isfinite(lb) & th <= lb + 1e-6 * max(abs(th));
R.thM         = th / A.r;
R.seM         = se / A.r;
R.vbrk        = vbrk;
R.vbrkAtLimit = (kb == 1 || kb == numel(g));
R.grid        = g;
R.sseGrid     = sse;
R.nFit        = n;
R.nOut        = nnz(~keep);
R.nRecFit     = nnz(isFit);
R.nRecVal     = nnz(isVal);
R.rmsFit      = sqrt(sseF / n);
R.r2Fit       = 1 - sseF / sum((y - mean(y)).^2);
R.cond        = cond(W ./ sqrt(sum(W.^2, 1)));
[Wv, yv] = stack(S(isVal), vbrk, nd);
if isempty(yv)
    R.rmsVal = NaN;
    R.r2Val  = NaN;
else
    ev = yv - Wv * th;
    R.rmsVal = sqrt(mean(ev.^2));
    R.r2Val  = 1 - sum(ev.^2) / sum((yv - mean(yv)).^2);
end

% ---- series for the plots
fr    = [2 3 4];                 % friction columns
other = setdiff(1:p, fr);
for k = 1:numel(S)
    Wk = regressors(S(k), vbrk);
    S(k).yhat  = Wk * th;
    S(k).yfric = S(k).y - Wk(:, other) * th(other);
end
end

% =====================================================================
function W = regressors(s, vbrk)
vs   = vbrk * sqrt(2);
vc   = vbrk / 10;
phiS = sqrt(2 * exp(1)) * exp(-(s.v / vs).^2) .* (s.v / vs);
phiC = tanh(s.v / vc);
W = [s.base(:, 1), ident_filt(s.hp, phiS), ident_filt(s.hp, phiC), s.base(:, 2:end)];
end

function [W, y] = stack(S, vbrk, nd)
W = [];
y = [];
for k = 1:numel(S)
    Wk = regressors(S(k), vbrk);
    ok = find(S(k).mask & all(isfinite(Wk), 2));
    ok = ok(1:nd:end);
    W  = [W; Wk(ok, :)]; %#ok<AGROW>
    y  = [y; S(k).y(ok)]; %#ok<AGROW>
end
end

function s = sse_at(S, vbrk, nd, lb)
[W, y] = stack(S, vbrk, nd);
[~, s] = solve(W, y, lb);
end

function [th, sse] = solve(W, y, lb)
% least squares with lower bounds, columns scaled to unit norm
cn = sqrt(sum(W.^2, 1));
cn(cn == 0) = 1;
Ws  = W ./ cn;
lbs = lb .* cn(:);
if ~isempty(which('lsqlin'))
    opt = optimoptions('lsqlin', 'Display', 'off');
    ths = lsqlin(Ws, y, [], [], [], [], lbs, [], [], opt);
else
    ths = Ws \ y;
    ths = max(ths, lbs);     % crude: install the Optimization Toolbox for a proper bounded fit
end
th  = ths(:) ./ cn(:);
sse = sum((y - W * th).^2);
end
