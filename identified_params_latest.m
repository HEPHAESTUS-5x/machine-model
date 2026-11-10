% Identified parameters, written 20261110_0948 by ident_rigid / ident_sim.
% Run after init_params. SI units, model side. Generated from ident_store.mat:
% do not edit by hand, change ident_config.m and run the identification again.
F0_x     = 137.9811      ; % +/- 15.5       rigid            20261110_0948  constant offset (not in the model: asymmetric friction or torque offset)
F0_y     = -297.9465     ; % +/- 14.1       rigid            20261110_0948  constant offset (not in the model: asymmetric friction or torque offset)
Fb_x     = 12962.87      ; % +/- 63.5       rigid            20261110_0948  breakaway friction (total)
Fc_x     = 11159.63      ; % +/- 24.8       rigid            20261110_0948  Coulomb friction
Fc_y0    = 11002.74      ; % +/- 22.4       rigid            20261110_0948  Coulomb friction
bv_x     = 89468.52      ; % +/- 462        rigid            20261110_0948  viscous coefficient
dFb_y0   = 584.9661      ; % +/- 50.8       rigid            20261110_0948  breakaway friction minus Coulomb
f_Fc_y   = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_dFb_y  = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_m_y    = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
f_vb_y   = 1             ; %                rigid            20261110_0948  multiplier reset: the nominal now holds the identified value
m_x      = 49639.15      ; % +/- 52.5       rigid            20261110_0948  effective mass/inertia: load + reflected rotor
m_y0     = 37392.25      ; % +/- 43.6       rigid            20261110_0948  effective mass/inertia: load + reflected rotor
vb_y0    = 42250.05      ; % +/- 413        rigid            20261110_0948  viscous coefficient
vbrk_x   = 0.0009497103  ; %                rigid            20261110_0948  breakaway velocity (1-D search)
vbrk_y   = 0.001043501   ; %                rigid            20261110_0948  breakaway velocity (1-D search)
