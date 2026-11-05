function runs = ident_plateaus(v, a, mask, t, tmin)
%IDENT_PLATEAUS  Index ranges where the axis moves at constant velocity.
%   Moving (mask), |acc| below 2 % of the largest acceleration, for at least
%   tmin seconds. The first and last 10 % of each plateau are dropped.
runs = {};
amax = max(abs(a(mask)));
if isempty(amax) || ~(amax > 0), return; end
m  = mask(:) & abs(a(:)) < 0.02 * amax;
d  = diff([0; m; 0]);
st = find(d == 1);
en = find(d == -1) - 1;
Ts = median(diff(t));
for j = 1:numel(st)
    if (en(j) - st(j) + 1) * Ts >= tmin
        ii = st(j):en(j);
        c  = round(0.1 * numel(ii));
        runs{end+1} = ii(1 + c:end - c); %#ok<AGROW>
    end
end
end
