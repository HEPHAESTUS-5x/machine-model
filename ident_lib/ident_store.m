function out = ident_store(action, varargin)
%IDENT_STORE  Keeps every identified value in ident_store.mat and writes
%   identified_params_latest.m (run it after init_params) plus a dated copy.
%
%   s = ident_store('load')
%   s = ident_store('set', s, names, values, ses, stage, stamp, notes)
%   ident_store('write', s, stamp)
%
%   The old ident_db.mat of run_identification.m is not read.
file = 'ident_store.mat';
switch action
    case 'load'
        s = struct();
        if exist(file, 'file')
            tmp = load(file, 's');
            s = tmp.s;
        end
        out = s;

    case 'set'
        [s, names, vals, ses, stage, stamp, notes] = varargin{:};
        for k = 1:numel(names)
            s.(names{k}) = struct('value', vals(k), 'se', ses(k), 'stage', stage, ...
                                  'date', stamp, 'note', notes{k});
        end
        out = s;

    case 'write'
        [s, stamp] = varargin{:};
        save(file, 's');
        fn  = sort(fieldnames(s));
        fid = fopen('identified_params_latest.m', 'w');
        fprintf(fid, '%% Identified parameters, written %s by ident_rigid / ident_sim.\n', stamp);
        fprintf(fid, '%% Run after init_params. SI units, model side. Generated from ident_store.mat:\n');
        fprintf(fid, '%% do not edit by hand, change ident_config.m and run the identification again.\n');
        for k = 1:numel(fn)
            d = s.(fn{k});
            if isnan(d.se)
                txt = '';
            else
                txt = sprintf('+/- %.3g', d.se);
            end
            fprintf(fid, '%-8s = %-14.7g; %% %-14s %-16s %s  %s\n', fn{k}, d.value, txt, d.stage, d.date, d.note);
        end
        fclose(fid);
        copyfile('identified_params_latest.m', ['identified_params_' stamp '.m']);
        fprintf('\nWritten identified_params_latest.m, identified_params_%s.m and %s\n', stamp, file);
        out = [];

    otherwise
        error('ident:store', 'unknown action %s', action);
end
end
