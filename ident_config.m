function cfg = ident_config()
%IDENT_CONFIG  Settings for ident_rigid.m, ident_sim.m and ident_make_synthetic.m.
%   Edit this file, not the scripts.

%% ---------------- Data: one entry per TRACE recording ----------------
% Each recording is processed on its own: derivatives never cross from one
% file to the next, so recordings of different lengths and start times are fine.
%   torque   : CSV with t and tau_x tau_y tau_z tau_a tau_c   [s, N*m at the motor]
%   feedback : CSV with t and pos_x pos_y pos_z pos_a pos_c    [s, mm, deg]
%              ('' when the positions are in the torque file). vel_* columns are ignored.
%   use      : 'fit' = used for the estimate, 'val' = held out, only to validate it
% Export the data RAW (no filtering in Python): all the filtering is done here,
% the same way on torque and positions.
useSynthetic = false;   % true -> use the files written by ident_make_synthetic
if useSynthetic
    d = 'data_synthetic';
    cfg.data = struct( ...
        'torque',   {fullfile(d, 'Y_fit.csv'), fullfile(d, 'Z_fit.csv'), fullfile(d, 'A_fit.csv'), fullfile(d, 'Y_val.csv')}, ...
        'feedback', {'', '', '', ''}, ...
        'use',      {'fit', 'fit', 'fit', 'val'});
else
    cfg.data = struct('torque', {}, 'feedback', {}, 'use', {});
    % CSVs made by logs-plots/trace_to_ident.py from the TRACE exports (t, tau_*, pos_*, vel_*)
    cfg.data(end+1) = struct('torque', 'data/IDEN_X_1.csv',      'feedback', '', 'use', 'fit');
    % cfg.data(end+1) = struct('torque', 'data/IDEN_Y_1.csv', 'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_X_FRIC_1.csv', 'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_X_DYN_1.csv',  'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_X_VAL_1.csv',  'feedback', '', 'use', 'val');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Y_FRIC_1.csv', 'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Y_DYN_1.csv',  'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Y_VAL_1.csv',  'feedback', '', 'use', 'val');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Y_1.csv',      'feedback', '', 'use', 'val');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Z_FRIC_1.csv', 'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Z_DYN_1.csv',  'feedback', '', 'use', 'fit');
    cfg.data(end+1) = struct('torque', 'data/IDEN_Z_VAL_1.csv',  'feedback', '', 'use', 'val');
    % one line per recording (keep the CSVs in data/), e.g.
    % cfg.data(end+1) = struct('torque', 'data/IDENT_Y_1_torque.csv', 'feedback', 'data/IDENT_Y_1_feedback.csv', 'use', 'fit');
    % cfg.data(end+1) = struct('torque', 'data/IDENT_Y_2_torque.csv', 'feedback', 'data/IDENT_Y_2_feedback.csv', 'use', 'val');
end

cfg.col.time = 't';
cfg.unit.tau = 1;        % torque column  -> N*m
cfg.unit.lin = 1e-3;     % linear position column -> m    (file in mm)
cfg.unit.rot = pi/180;   % rotary position column -> rad  (file in deg)

%% ---------------- Zero-phase filtering ----------------
% Velocity and acceleration come from the position with a Savitzky-Golay
% filter (symmetric FIR = zero phase). The torque and every column of the
% regressor go through the SAME zero-phase smoothing filter ("parallel
% filtering"), so both sides of  tau = W*theta  get identical delay (none)
% and identical attenuation. 21 samples x 2 ms = 42 ms, cutoff about 35 Hz:
% above the content of the jerk-limited ramps, below the noise.
cfg.filt.order    = 3;    % SG polynomial order (>= 2)
cfg.filt.frame    = 21;   % SG frame for the derivatives [samples, odd]
cfg.filt.parallel = 21;   % frame of the smoothing applied to torque and regressors [samples, odd]
cfg.filt.decimate = 10;   % keep 1 sample in N after filtering (less correlated residuals)

%% ---------------- Rigid fit (ident_rigid) ----------------
cfg.rigid.axes         = {'x', 'y', 'z', 'a', 'c'};  % an axis that never moves is skipped
cfg.rigid.tmin_plateau = 0.2;   % [s] shortest constant-velocity plateau shown in the friction plot
cfg.rigid.outlier      = 5;     % residuals beyond this many robust sigmas are dropped once

%% ---------------- Axes ----------------
% r = load displacement per motor radian IN THE SIMSCAPE MODEL [m/rad or rad/rad].
%   X, Y, Z : ball screw, lead 20 mm (MD31030), gear 1/1 (MD31050/31060)  ->  r = 0.020/(2*pi)
%             read on the machine 2026-11-12; MD32000 = 40000 mm/min = 2000 rpm, MD32100 = -1
%             THE SIMSCAPE MODELS MUST USE THE SAME r: X, Y: Gear Box ratio 1 and Wheel and Axle R = 20/(2*pi) mm;
%             Z: Leadscrew lead 20 mm.
%   A, C : the motor torque acts directly on the inertia        ->  r = 1
% r converts the fitted coefficients (motor torque per unit of load motion)
% into the parameters of the blocks. It must match the MODEL. Check the model
% against the real machine data (MD31030 leadscrew pitch, MD31050/MD31060
% gear ratio) and, if you change the model, change r here too.
%
% gravity: 'none'   ->  no gravity term
%          'const'  ->  constant force (Z): written to the 'offset' variable
%          'sincos' ->  Gs*sin(q) + Gc*cos(q) (A tilt), plus the constant offset
% map: workspace variable that receives each estimate. A missing field is not written.
%   mass  effective mass / inertia (load + reflected rotor inertia)
%   Fc    Coulomb force/torque              Fbrk  breakaway force (total)
%   dFb   breakaway excess over Coulomb      visc  viscous coefficient
%   vbrk  breakaway velocity                 offset constant force (gravity on Z)
%   gsin, gcos  gravity torque coefficients (A); the model applies -G_a*sin(a)
% reset: multipliers set back to 1, because the nominal now holds the identified value.
r_screw = 0.020/(2*pi);   % [m/rad] ball screw lead 20 mm, direct drive (same on X, Y, Z)
cfg.axes = [ ...
    axis_def('x', 'lin', 'tau_x', 'pos_x', r_screw, 'none', ...
        struct('mass', 'm_x', 'Fc', 'Fc_x', 'Fbrk', 'Fb_x', 'visc', 'bv_x', 'vbrk', 'vbrk_x', 'offset', 'F0_x'), {}), ...
    axis_def('y', 'lin', 'tau_y', 'pos_y', r_screw, 'none', ...
        struct('mass', 'm_y0', 'Fc', 'Fc_y0', 'dFb', 'dFb_y0', 'visc', 'vb_y0', 'vbrk', 'vbrk_y', 'offset', 'F0_y'), ...
        {'f_m_y', 'f_Fc_y', 'f_dFb_y', 'f_vb_y'}), ...
    axis_def('z', 'lin', 'tau_z', 'pos_z', r_screw, 'const', ...
        struct('mass', 'm_z', 'Fc', 'Fc_z', 'Fbrk', 'Fb_z', 'visc', 'vb_z', 'vbrk', 'vbrk_z', 'offset', 'Fg_z'), {}), ...
    axis_def('a', 'rot', 'tau_a', 'pos_a', 1, 'sincos', ...
        struct('mass', 'J_a', 'Fc', 'Tc_a', 'Fbrk', 'Tb_a', 'visc', 'bv_a', 'vbrk', 'vbrk_a', 'offset', 'T0_a', ...
               'gsin', 'G_a', 'gcos', 'Gc_a'), {}), ...
    axis_def('c', 'rot', 'tau_c', 'pos_c', 1, 'none', ...
        struct('mass', 'J_c', 'Fc', 'Tc_c', 'Fbrk', 'Tb_c', 'visc', 'bv_c', 'vbrk', 'vbrk_c', 'offset', 'T0_c'), {})];

%% ---------------- Simulation refinement (ident_sim) ----------------
% Each axis model is simulated on its own, driven by the measured torques.
%   inputs : axes of the root inports, in inport order
%   posOut : root outport that gives the position of each of those axes (mm or deg)
%   free   : workspace variables scaled by the fit (start = current value, scale 1)
% k and c are left out on purpose: the air motions at 2 ms do not excite the
% coupling resonance, so they are not identifiable from these data.
cfg.sim.models = struct( ...
    'name',   {'machine_x', 'machine_y', 'machine_z'}, ...
    'inputs', {{'x', 'a', 'c'}, {'y'}, {'z'}}, ...
    'posOut', {[2 3 4], 2, 1}, ...
    'free',   {{'m_x', 'Fc_x', 'bv_x'}, {'f_m_y', 'f_Fc_y', 'f_vb_y'}, {'m_z', 'Fc_z', 'vb_z', 'Fg_z'}});
cfg.sim.bounds = [0.5 2];   % bounds on the scale factors
cfg.sim.wPos   = 0;         % weight of the position error (0 = velocity only; position drifts in open loop)
end

function A = axis_def(name, kind, tauCol, posCol, r, gravity, map, reset)
A.name    = name;
A.kind    = kind;      % 'lin' or 'rot'
A.tau     = tauCol;
A.pos     = posCol;
A.r       = r;
A.gravity = gravity;
A.map     = map;
A.reset   = reset;
if strcmp(kind, 'lin')
    A.vmin      = 5e-5;                        % [m/s]   3 mm/min: below this the sample is "at rest"
    A.vbrk_grid = logspace(-4.5, -1.5, 31);    % [m/s]   search range of the breakaway velocity
else
    A.vmin      = 1e-3;                        % [rad/s] 3.4 deg/min
    A.vbrk_grid = logspace(-3.5, -0.5, 31);    % [rad/s]
end
end
