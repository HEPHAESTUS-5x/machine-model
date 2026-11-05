function y = ident_filt(h, x)
%IDENT_FILT  Zero-phase FIR: y(n) = sum_k h(k) x(n+k), k = -hw..hw.
%   Samples whose window reaches past the ends or touches a NaN are NaN.
x  = x(:);
h  = h(:);
hw = (numel(h) - 1) / 2;
bad = ~isfinite(x);
x(bad) = 0;
y = conv(x, flipud(h), 'same');
if any(bad)
    touch = conv(double(bad), ones(numel(h), 1), 'same') > 0;
    y(touch) = NaN;
end
n = numel(y);
y(1:min(hw, n)) = NaN;
y(max(n - hw + 1, 1):n) = NaN;
end
