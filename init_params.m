%% init_params.m
% Nominal values (suffix 0), multipliers (prefix f_) and derived values.
% The identification estimates ONLY the multipliers f_*  (start at 1).
% Replace the placeholder numbers with real values (CAD, datasheet, machine data).

%% ---------------- Axis Y ----------------
m_y0   = 80;            % kg     effective mass         (placeholder)
k_y0   = 2e6;           % N/m    coupling stiffness     (placeholder)
c_y0   = 800;           % N*s/m  coupling damping       (placeholder)
Fc_y0  = 150;           % N      Coulomb force          (placeholder)
dFb_y0 = 0.2*Fc_y0;     % N      breakaway excess over Coulomb (placeholder)
vb_y0  = 500;           % N*s/m  viscous coefficient    (placeholder)
vbrk_y = 2e-3;          % m/s    breakaway velocity (fixed, not estimated)

f_m_y = 1;  f_k_y = 1;  f_c_y = 1;
f_Fc_y = 1;  f_dFb_y = 1;  f_vb_y = 1;

%% ---------------- Axis Z ----------------
m_z0 = 30;   k_z0 = 1e6;   c_z0 = 400;
f_m_z = 1;   f_k_z = 1;    f_c_z = 1;

%% ---------------- Axis X ----------------
m_x0 = 50;   k_x0 = 1e6;   c_x0 = 500;
f_m_x = 1;   f_k_x = 1;    f_c_x = 1;

%% ---------------- Rotary axes ----------------
J_a0 = 0.5;  k_a0 = 1e5;   c_a0 = 50;
f_J_a = 1;   f_k_a = 1;    f_c_a = 1;
J_c0 = 0.8;  k_c0 = 1e5;   c_c0 = 80;
f_J_c = 1;   f_k_c = 1;    f_c_c = 1;

%% ---------------- Derived values (used by blocks that still contain plain names) ----------------
% NOTE: these are computed ONCE here. For the identification to move a parameter,
% the block dialog must contain the product itself, e.g.  m_y0*f_m_y
m_y = m_y0*f_m_y;   k_y = k_y0*f_k_y;   c_y = c_y0*f_c_y;
Fc_y = Fc_y0*f_Fc_y;
Fb_y = Fc_y + dFb_y0*f_dFb_y;
vb_y = vb_y0*f_vb_y;

m_z = m_z0*f_m_z;   k_z = k_z0*f_k_z;   c_z = c_z0*f_c_z;
m_x = m_x0*f_m_x;   k_x = k_x0*f_k_x;   c_x = c_x0*f_c_x;
J_a = J_a0*f_J_a;   k_a = k_a0*f_k_a;   c_a = c_a0*f_c_a;
J_c = J_c0*f_J_c;   k_c = k_c0*f_k_c;   c_c = c_c0*f_c_c;