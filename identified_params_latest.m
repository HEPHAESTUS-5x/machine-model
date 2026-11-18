% Identified parameters, written 20261118_1119 by ident_rigid / ident_sim.
% Run after init_params. SI units, model side. Generated from ident_store.mat:
% do not edit by hand, change ident_config.m and run the identification again.
F0_x     = -0.5299908    ; % +/- 1.04       rigid            20261112_2101  constant offset (not in the model: asymmetric friction or torque offset)
F0_y     = -16.37186     ; % +/- 0.853      rigid            20261112_2101  constant offset (not in the model: asymmetric friction or torque offset)
Fb_x     = 983.7815      ; % +/- 3.66       rigid            20261112_2101  breakaway friction (total)
Fb_z     = 707.8511      ; % +/- 2.72       rigid            20261112_2101  breakaway friction (total)
Fc_x     = 883.482       ; % +/- 1.77       simcl machine_x  20261112_2139  static-friction run 20261112_2139, restored (LuGre: only xps, zb fitted)
Fc_y0    = 805.3044      ; % +/- 1.49       rigid            20261112_2101  Coulomb friction
Fc_z     = 687.0097      ; % +/- 1.4        simcl machine_z  20261113_1027  refined by closed-loop simulation of machine_z
Fg_z     = 3969.903      ; % +/- 1.05       simcl machine_z  20261113_1027  refined by closed-loop simulation of machine_z
bv_x     = 6371.646      ; % +/- 40.9       simcl machine_x  20261112_2139  static-friction run 20261112_2139, restored (LuGre: only xps, zb fitted)
dFb_y0   = 77.94333      ; % +/- 2.73       rigid            20261112_2101  breakaway friction minus Coulomb
f_Fc_y   = 1.002884      ; % +/- 0.000679   simcl machine_y  20261113_1038  refined by closed-loop simulation of machine_y
f_dFb_y  = 1             ; %                rigid            20261112_2101  multiplier reset: the nominal now holds the identified value
f_m_y    = 1.000625      ; % +/- 0.000704   simcl machine_y  20261113_1038  refined by closed-loop simulation of machine_y
f_vb_y   = 1.002929      ; % +/- 0.000756   simcl machine_y  20261113_1038  refined by closed-loop simulation of machine_y
m_x      = 3671.382      ; % +/- 4.42       simcl machine_x  20261112_2139  static-friction run 20261112_2139, restored (LuGre: only xps, zb fitted)
m_y0     = 2787.337      ; % +/- 2.97       rigid            20261112_2101  effective mass/inertia: load + reflected rotor
m_z      = 1692.904      ; % +/- 3.46       simcl machine_z  20261113_1027  refined by closed-loop simulation of machine_z
vb_y0    = 3079.814      ; % +/- 27.6       rigid            20261112_2101  viscous coefficient
vb_z     = 2038.62       ; % +/- 12         simcl machine_z  20261113_1027  refined by closed-loop simulation of machine_z
vbrk_x   = 0.0008131608  ; %                rigid            20261112_2101  breakaway velocity (1-D search)
vbrk_y   = 0.001141641   ; %                rigid            20261112_2101  breakaway velocity (1-D search)
vbrk_z   = 0.0007891687  ; %                rigid            20261112_2101  breakaway velocity (1-D search)
xps_x    = 2.525419e-05  ; % +/- 2.88e-07   simcl machine_x  20261118_1027  refined by closed-loop simulation of machine_x
xps_y    = 2.518058e-05  ; % +/- 1.74e-08   simcl machine_y  20261118_1105  refined by closed-loop simulation of machine_y
xps_z    = 4.935071e-05  ; % +/- 4.36e-07   simcl machine_z  20261118_1119  refined by closed-loop simulation of machine_z
zb_x     = 0.2833787     ; % +/- 0.0171     simcl machine_x  20261118_1027  refined by closed-loop simulation of machine_x
zb_y     = 0.3010483     ; % +/- 0.000215   simcl machine_y  20261118_1105  refined by closed-loop simulation of machine_y
zb_z     = 0.6221298     ; % +/- 0.0222     simcl machine_z  20261118_1119  refined by closed-loop simulation of machine_z
