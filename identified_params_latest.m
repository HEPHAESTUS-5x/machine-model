% Identified parameters, written 20261110_1228 by ident_rigid / ident_sim.
% Run after init_params. SI units, model side. Generated from ident_store.mat:
% do not edit by hand, change ident_config.m and run the identification again.
F0_x     = -7.161848     ; % +/- 14.1       rigid            20261110_1228  constant offset (not in the model: asymmetric friction or torque offset)
F0_y     = -297.9465     ; % +/- 14.1       rigid            20261110_0948  constant offset (not in the model: asymmetric friction or torque offset)
Fb_x     = 13293.99      ; % +/- 49.5       rigid            20261110_1228  breakaway friction (total)
Fc_x     = 11811.77      ; % +/- 23.4       rigid            20261110_1228  Coulomb friction
Fc_y0    = 11002.74      ; % +/- 22.4       rigid            20261110_0948  Coulomb friction
bv_x     = 81990.11      ; % +/- 453        rigid            20261110_1228  viscous coefficient
dFb_y0   = 584.9661      ; % +/- 50.8       rigid            20261110_0948  breakaway friction minus Coulomb
f_Fc_y   = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_dFb_y  = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_m_y    = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_vb_y   = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
m_x      = 49817.58      ; % +/- 52.1       rigid            20261110_1228  effective mass/inertia: load + reflected rotor
m_y0     = 37392.25      ; % +/- 43.6       rigid            20261110_0948  effective mass/inertia: load + reflected rotor
vb_y0    = 42250.05      ; % +/- 413        rigid            20261110_0948  viscous coefficient
vbrk_x   = 0.0008131608  ; %                rigid            20261110_1228  breakaway velocity (1-D search)
vbrk_y   = 0.001043501   ; %                rigid            20261110_0948  breakaway velocity (1-D search)
