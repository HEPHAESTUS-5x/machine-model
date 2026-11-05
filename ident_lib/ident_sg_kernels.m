function [h0, h1, h2] = ident_sg_kernels(order, frame, Ts)
%IDENT_SG_KERNELS  Savitzky-Golay kernels: smoothing, 1st and 2nd derivative.
%   The kernels are applied with ident_filt as y(n) = sum_k h(k) x(n+k),
%   k = -hw..hw: symmetric (h0, h2) or antisymmetric (h1), so zero phase.
%   order : polynomial order (>= 2), frame : odd number of samples, Ts : [s]
if mod(frame, 2) == 0
    frame = frame + 1;
end
if order < 2 || order >= frame
    error('ident:sg', 'Savitzky-Golay needs 2 <= order < frame');
end
hw = (frame - 1) / 2;
k  = (-hw:hw).';
P  = pinv(k .^ (0:order));     % (order+1) x frame, least-squares polynomial fit
h0 = P(1, :);
h1 = P(2, :) / Ts;
h2 = 2 * P(3, :) / Ts^2;
end
