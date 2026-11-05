function [names, vals, ses, notes] = ident_map_axis(A, R)
%IDENT_MAP_AXIS  Converts the rigid estimates of one axis into the workspace
%   variables of the Simscape model (A.map), in model units (R.thM = R.th / A.r).
names = {};
vals  = [];
ses   = [];
notes = {};
M = A.map;
add('mass', R.thM(1), R.seM(1), 'effective mass/inertia: load + reflected rotor');
add('Fc',   R.thM(3), R.seM(3), 'Coulomb friction');
add('Fbrk', R.thM(3) + R.thM(2), hypot(R.seM(2), R.seM(3)), 'breakaway friction (total)');
add('dFb',  R.thM(2), R.seM(2), 'breakaway friction minus Coulomb');
add('visc', R.thM(4), R.seM(4), 'viscous coefficient');
add('vbrk', R.vbrk, NaN, 'breakaway velocity (1-D search)');
switch A.gravity
    case 'const'
        add('offset', R.thM(5), R.seM(5), 'constant force at the motor side = gravity (replaces m*g)');
    otherwise
        add('offset', R.thM(5), R.seM(5), 'constant offset (not in the model: asymmetric friction or torque offset)');
end
if strcmp(A.gravity, 'sincos')
    add('gsin', R.thM(6), R.seM(6), 'gravity: motor torque += G*sin(q); model gain = -G');
    add('gcos', R.thM(7), R.seM(7), 'gravity: motor torque += Gc*cos(q); not in the model yet');
end
for k = 1:numel(A.reset)
    names{end+1} = A.reset{k}; %#ok<AGROW>
    vals(end+1)  = 1;          %#ok<AGROW>
    ses(end+1)   = NaN;        %#ok<AGROW>
    notes{end+1} = 'multiplier reset: the nominal now holds the identified value'; %#ok<AGROW>
end

    function add(key, val, se, note)
        if ~isfield(M, key), return; end
        names{end+1} = M.(key);
        vals(end+1)  = val;
        ses(end+1)   = se;
        notes{end+1} = note;
    end
end
