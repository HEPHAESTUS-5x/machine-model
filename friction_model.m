function out = friction_model(which)
%FRICTION_MODEL  Switches the friction of machine_x, machine_y, machine_z.
%   friction_model('lugre')   LuGre blocks in, static Translational/Rotational Friction out
%   friction_model('static')  back to the static friction blocks
%   friction_model            prints which one is active
%   FB = friction_model('list')  the block list (used by fix_models_v3)
% The blocks are commented in/out (with their references), the models are compiled
% and saved only if they compile. Needs fix_models_v3 to have been run once.
nl = newline;
tr = ['Mechanical' nl 'Translational' nl 'Reference'];
FB = struct( ...
    'mdl',    {'machine_x', 'machine_x', 'machine_x', 'machine_y', 'machine_z'}, ...
    'static', {['Translational' nl 'Friction'], 'Rotational Friction A', 'Rotational Friction C', ...
               ['Translational' nl 'Friction'], ['Translational' nl 'Friction']}, ...
    'sref',   {tr, 'Rotational Friction A ref', 'Rotational Friction C ref', tr, [tr '1']}, ...
    'lugre',  {'LuGre X', 'LuGre A', 'LuGre C', 'LuGre Y', 'LuGre Z'}, ...
    'node',   {'Mass1', 'Inertia', 'Inertia1', 'Mass', 'Mass'}, ...
    'kind',   {'trans', 'rot', 'rot', 'trans', 'trans'}, ...
    'ax',     {'x', 'a', 'c', 'y', 'z'}, ...
    'mass',   {'m_x', 'J_a', 'J_c', 'm_y0*f_m_y', 'm_z'});
if nargin > 0 && strcmp(which, 'list')
    out = FB;
    return
end
here = fileparts(mfilename('fullpath'));
mdls = unique({FB.mdl}, 'stable');
if nargin == 0
    for k = 1:numel(mdls)
        load_system(fullfile(here, mdls{k}));
        for i = find(strcmp({FB.mdl}, mdls{k}))
            b = [mdls{k} '/' FB(i).lugre];
            if getSimulinkBlockHandle(b) == -1
                s = 'static (no LuGre block: run fix_models_v3)';
            elseif strcmp(get_param(b, 'Commented'), 'off')
                s = 'LuGre';
            else
                s = 'static';
            end
            fprintf('%-10s axis %s: %s\n', mdls{k}, upper(FB(i).ax), s);
        end
    end
    return
end
useLuGre = strcmpi(which, 'lugre');
if ~useLuGre && ~strcmpi(which, 'static')
    error('friction_model: use ''lugre'' or ''static''');
end
onoff = {'off', 'on'};
% variables of the dialogs, for the compile check
evalin('base', ['init_params; if exist(''identified_params_latest.m'', ''file''), ' ...
                'identified_params_latest; end']);
for k = 1:numel(mdls)
    mdl = mdls{k};
    load_system(fullfile(here, mdl));
    for i = find(strcmp({FB.mdl}, mdl))
        lb = [mdl '/' FB(i).lugre];
        if getSimulinkBlockHandle(lb) == -1
            close_system(mdl, 0);
            error('friction_model: %s has no "%s": run fix_models_v3 first', mdl, FB(i).lugre);
        end
        set_param([mdl '/' FB(i).static], 'Commented', onoff{1 + useLuGre});
        set_param([mdl '/' FB(i).sref],   'Commented', onoff{1 + useLuGre});
        set_param(lb,                      'Commented', onoff{2 - useLuGre});
        set_param([lb ' ref'],             'Commented', onoff{2 - useLuGre});
    end
    try
        set_param(mdl, 'SimulationCommand', 'update');
    catch err
        close_system(mdl, 0);
        error('friction_model: %s does not compile (NOT saved): %s', mdl, err.message);
    end
    save_system(mdl);
    close_system(mdl, 0);
    fprintf('%s: %s friction, saved\n', mdl, upper(which));
end
end
