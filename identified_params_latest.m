% Identified parameters, written 20261112_1526 by ident_rigid / ident_sim.
% Run after init_params. SI units, model side. Generated from ident_store.mat:
% do not edit by hand, change ident_config.m and run the identification again.
F0_x     = -0.5299908    ; % +/- 1.04       rigid            20261112_1526  constant offset (not in the model: asymmetric friction or torque offset)
F0_y     = -16.37186     ; % +/- 0.853      rigid            20261112_1526  constant offset (not in the model: asymmetric friction or torque offset)
Fb_x     = 983.7815      ; % +/- 3.66       rigid            20261112_1526  breakaway friction (total)
Fb_z     = 707.8511      ; % +/- 2.72       rigid            20261112_1526  breakaway friction (total)
Fc_x     = 874.0939      ; % +/- 1.73       rigid            20261112_1526  Coulomb friction
Fc_y0    = 805.3044      ; % +/- 1.49       rigid            20261112_1526  Coulomb friction
Fc_z     = 686.698       ; % +/- 1.29       rigid            20261112_1526  Coulomb friction
Fg_z     = 3958.547      ; % +/- 0.788      rigid            20261112_1526  constant force at the motor side = gravity (replaces m*g)
bv_x     = 6067.429      ; % +/- 33.6       rigid            20261112_1526  viscous coefficient
dFb_y0   = 77.94333      ; % +/- 2.73       rigid            20261112_1526  breakaway friction minus Coulomb
f_Fc_y   = 1             ; %                rigid            20261112_1526  multiplier reset: the nominal now holds the identified value
f_dFb_y  = 1             ; %                rigid            20261112_1526  multiplier reset: the nominal now holds the identified value
f_m_y    = 1             ; %                rigid            20261112_1526  multiplier reset: the nominal now holds the identified value
f_vb_y   = 1             ; %                rigid            20261112_1526  multiplier reset: the nominal now holds the identified value
m_x      = 3686.598      ; % +/- 3.85       rigid            20261112_1526  effective mass/inertia: load + reflected rotor
m_y0     = 2787.337      ; % +/- 2.97       rigid            20261112_1526  effective mass/inertia: load + reflected rotor
m_z      = 1725.96       ; % +/- 2.55       rigid            20261112_1526  effective mass/inertia: load + reflected rotor
vb_y0    = 3079.814      ; % +/- 27.6       rigid            20261112_1526  viscous coefficient
vb_z     = 1956.835      ; % +/- 27.3       rigid            20261112_1526  viscous coefficient
vbrk_x   = 0.0008131608  ; %                rigid            20261112_1526  breakaway velocity (1-D search)
vbrk_y   = 0.001141641   ; %                rigid            20261112_1526  breakaway velocity (1-D search)
vbrk_z   = 0.0007891687  ; %                rigid            20261112_1526  breakaway velocity (1-D search)
