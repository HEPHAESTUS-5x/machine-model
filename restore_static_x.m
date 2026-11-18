%% restore_static_x.m
% Puts back the X values of the static-friction identification (identified_params_20261112_2139.m)
% for m_x, Fc_x, bv_x in ident_store.mat and identified_params_latest.m. The LuGre values
% (xps_x, zb_x) and every other axis are left as they are. Run once:  >> restore_static_x
s = ident_store('load');
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
names = {'m_x', 'Fc_x', 'bv_x'};
vals  = [3671.382, 883.482, 6371.646];
ses   = [4.42, 1.77, 40.9];
notes = repmat({'static-friction run 20261112_2139, restored (LuGre: only xps, zb fitted)'}, 1, 3);
s = ident_store('set', s, names, vals, ses, 'simcl machine_x', '20261112_2139', notes);
ident_store('write', s, stamp);
