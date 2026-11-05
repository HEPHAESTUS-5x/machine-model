# machine-model

| File | Purpose |
|---|---|
| `multibody_model.slx`, `machine_x/y/z.slx` | Digital twin (Simscape), exported as FMU |
| `init_params.m` | Nominal parameters; then `identified_params_latest.m` overrides them |
| `export_fmu.m` | Exports `fmu_test/multibody_model_ME30.fmu` with the parameters tunable |
| `ident_*.m`, `ident_lib/` | Parameter identification (below) |
| `machine_viewer.m` | 3-D replay of a recorded test: press Run, pick a CSV |
| `data/` | TRACE recordings as CSV |
| `signal-based/` | Signal-based model |

The model fixes made before the identification (C spring/damper swapped back, X and Z friction enabled,
A and C friction added, Z gravity as `Fg_z`, A gravity gain as `-G_a`) were applied once by
`fix_model_for_ident.m` on 2026-11-05. The cleanup moves it to `_to_delete/`: commit it first if you want it in the history.

# Parameter identification of the axis models

Two stages. Settings in `ident_config.m`, helpers in `ident_lib/`.

| Step | Script | What it does |
|---|---|---|
| 0 (test) | `ident_make_synthetic.m` | Synthetic recordings with known parameters in `data_synthetic/`. Set `useSynthetic = true` in the config, run `ident_rigid`, compare, set it back. |
| 1 | `ident_rigid.m` | Rigid inverse-dynamics fit of every axis that moves: effective mass/inertia, Coulomb, breakaway, viscous, breakaway velocity, offset/gravity. Linear least squares, seconds, no initial guess. |
| 2 | `ident_sim.m` | Refines a few parameters of one axis model (`mdl = ...`) by simulating it with the measured torques and comparing velocities. Replaces `run_identification.m`. |

Both stages write `identified_params_latest.m` (plus a dated copy) from `ident_store.mat`.
`export_fmu.m` already runs `init_params; identified_params_latest;`, so the next FMU export carries the identified values.

## Data
One CSV pair per TRACE recording, in `data/`, listed in `cfg.data`:
- torque: `t, tau_x, tau_y, tau_z, tau_a, tau_c` [s, N·m at the motor]
- feedback: `t, pos_x, pos_y, pos_z, pos_a, pos_c` [s, mm, deg]

Export them **raw**. All the filtering happens in MATLAB, identically on torque and positions.
Mark at least one recording per axis `use = 'val'`.

## Filtering
- Velocity and acceleration: Savitzky–Golay derivatives of the position (order 3, 21 samples = 42 ms at 2 ms, cutoff about 35 Hz). Symmetric FIR, so zero phase.
- Torque and every regressor column: the same zero-phase smoothing ("parallel filtering"), then decimated by 10.
- Samples at rest (|v| below 3 mm/min or 3.4 deg/min) are not used.
- Stage 2: raw torque into the model; the measured and simulated positions go through the same SG derivative.

## Not identified
`k` and `c` of the couplings: the air motions recorded at 2 ms do not excite the coupling resonance. Keep datasheet values, or measure the frequency response with the drive's measuring function.
