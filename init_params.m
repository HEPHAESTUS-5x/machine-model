%% init_params.m
% Nominal values (suffix 0), multipliers (prefix f_) and derived values.
% The identification estimates ONLY the multipliers f_*  (start at 1).
% Replace the placeholder numbers with real values (CAD, datasheet, machine data).

%% ---------------- Axis Y ----------------
m_y0   = 80;            % kg     effective mass         (placeholder)
k_y0   = 2e8;           % N/m    coupling stiffness     (placeholder: ball screw drive 1e8-4e8 N/m)
c_y0   = 1.5e5;         % N*s/m  coupling damping       (placeholder: damping ratio ~0.1 with ~2.8 t)
% (2e6 / 800 gave a 4 Hz resonance with damping ratio 0.005: the simulated axis rang
%  for seconds after every move and ident_sim could not fit anything)
Fc_y0  = 150;           % N      Coulomb force          (placeholder)
dFb_y0 = 0.2*Fc_y0;     % N      breakaway excess over Coulomb (placeholder)
vb_y0  = 500;           % N*s/m  viscous coefficient    (placeholder)
vbrk_y = 2e-3;          % m/s    breakaway velocity (fixed, not estimated)

f_m_y = 1;  f_k_y = 1;  f_c_y = 1;
f_Fc_y = 1;  f_dFb_y = 1;  f_vb_y = 1;

%% ---------------- Axis Z ----------------
% Z: the spring and damper are ROTATIONAL (before the leadscrew). Same axial stiffness and
% damping as X, Y: 2e8 N/m and 1.2e5 N*s/m reflected through r = 20 mm/(2*pi)
% (was 1e6 N*m/rad = 1e11 N/m, 1.2 kHz, and 400 N*m*s/rad = 4e7 N*s/m: strongly overdamped and stiff)
m_z0 = 30;   k_z0 = 2e8*(0.020/(2*pi))^2;   c_z0 = 1.2e5*(0.020/(2*pi))^2;
f_m_z = 1;   f_k_z = 1;    f_c_z = 1;

%% ---------------- Axis X ----------------
m_x0 = 50;   k_x0 = 2e8;   c_x0 = 1.7e5;   % k, c placeholders: 37 Hz, damping ratio ~0.1 with 3.7 t (was 1e6/500: 2.6 Hz, 0.004)
f_m_x = 1;   f_k_x = 1;    f_c_x = 1;

%% ---------------- Rotary axes ----------------
% TABLE side since fix_models_v2 (gearboxes A1 2880/37, C1 642/7 in machine_x).
% J includes the reflected motor inertia; placeholders until ident_rigid, from a first look at the
% A and C recordings. k, c: first mode ~40 Hz, damping ratio ~0.1 (placeholders, not identified).
J_a0 = 150;  k_a0 = 1e7;   c_a0 = 8e3;
f_J_a = 1;   f_k_a = 1;    f_c_a = 1;
J_c0 = 25;   k_c0 = 1.6e6; c_c0 = 1.3e3;
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

%% ---------------- Added for the identification (ident_config / fix_model_for_ident) ----------------
% Placeholders, overwritten by identified_params_latest.m once ident_rigid has run.
% X and Z friction (Translational Friction blocks, enabled by fix_model_for_ident)
Fc_x = 200;   Fb_x = 1.2*Fc_x;   bv_x = 1000;   vbrk_x = 2e-3;
Fc_z = 200;   Fb_z = 1.2*Fc_z;   vb_z = 1000;   vbrk_z = 2e-3;
% Z gravity as its own force: m_z also holds the reflected rotor inertia
Fg_z = m_z*9.81;
% A and C friction (Rotational Friction blocks added by fix_model_for_ident)
% table side (motor-side values / gear ratio), placeholders until ident_rigid
Tc_a = 230;   Tb_a = 1.2*Tc_a;   bv_a = 350;    vbrk_a = 0.01;
Tc_c = 110;   Tb_c = 1.2*Tc_c;   bv_c = 100;    vbrk_c = 0.01;
% A gravity (fix_models_v2): load torque = -(G_a*sin(a+q0_a) + Gc_a*cos(a+q0_a) + T0_a)
%   a    = model angle, starts from 0 [rad]
%   q0_a = absolute A angle at the start of the recordings (IDEN_A_*: -3781.342 deg in the TRACE)
% G_a, Gc_a, T0_a come from ident_rigid with the same absolute angle, so they fit together.
% (the old G_a = 2.94 was motor-side and is not valid with the gearbox)
G_a = 0;   Gc_a = 0;   T0_a = 0;
q0_a = -3781.342*pi/180;
% constant offsets found by the rigid fit (fix_models_v2 puts them in the models)
F0_x = 0;   F0_y = 0;   T0_c = 0;

%% ---------------- Dynamic friction (LuGre, fix_models_v3) ----------------
% Same static law as before (Fc, Fb, bv, vbrk) plus the pre-sliding:
%   xps = displacement at the Coulomb force while the axis is "stuck"
%         (bristle stiffness sigma0 = Fc/xps). Linear axes: a few micrometres;
%         rotary axes: table side, 5e-5 rad = 10 arcsec. Refined by ident_sim_cl.
%   zb  = damping ratio of the bristles on the moving mass (sigma1 = 2*zb*sqrt(sigma0*m)); not identified.
% Switch between LuGre and the static blocks with friction_model('lugre' / 'static').
xps_x = 5e-6;   xps_y = 25e-6;  xps_z = 10e-6;  % m  (Y: start from the X result; Z: started away from it on purpose)
xps_a = 5e-5;   xps_c = 5e-5;                   % rad
zb_x = 1;   zb_y = 0.3; zb_z = 0.6; zb_a = 1;   zb_c = 1;   % Y: start from the X result (0.28); Z: away from it
