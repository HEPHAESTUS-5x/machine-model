function h = ident_make_harness(mdl, M, K)
%IDENT_MAKE_HARNESS  Closed-loop test bench around one axis model (for ident_sim_cl).
%   h = ident_make_harness('machine_x', M, K)
%   Builds harness_<mdl>.slx next to the model. The model itself is NOT changed:
%   its contents are copied into the subsystem 'plant'.
%
%   For every input axis j of the model (M.inputs, M.posOut from ident_config):
%     tau_<ax>  (inport j)     measured motor torque            [N*m]
%     pref_<ax> (inport n+j)   measured position, from 0        [mm or deg]
%     plant input j = tau_<ax> + PID(pref - model position)     "virtual controller"
%     tcorr_<ax> (outport j)   PID output = torque the model needs ON TOP of the
%                              measured one to follow the measured motion
%     pos_<ax>  (outport n+j)  model position                   [mm or deg]
%   With the right parameters tcorr is about zero: the fit minimises it.
%   K(j).P, .I, .D, .N : PID gains of axis j (parallel form).
h = ['harness_' mdl];
if bdIsLoaded(h), close_system(h, 0); end
f = fullfile(pwd, [h '.slx']);
if exist(f, 'file'), delete(f); end
if bdIsLoaded(mdl), close_system(mdl, 0); end     % take the model from disk
load_system(mdl);
new_system(h);
n = numel(M.inputs);
add_block('built-in/Subsystem', [h '/plant'], 'Position', [500 40 700 80 + 60 * n]);
Simulink.BlockDiagram.copyContentsToSubsystem(mdl, [h '/plant']);
close_system(mdl, 0);

% ports in creation order = port numbers
for j = 1:n
    a = M.inputs{j};
    add_block('simulink/Sources/In1', [h '/tau_' a], 'Position', [20 100*j 50 100*j+14]);
end
for j = 1:n
    a = M.inputs{j};
    add_block('simulink/Sources/In1', [h '/pref_' a], 'Position', [20 100*j+40 50 100*j+54]);
end
for j = 1:n
    a = M.inputs{j};
    add_block('simulink/Sinks/Out1', [h '/tcorr_' a], 'Position', [420 100*j+70 450 100*j+84]);
end
for j = 1:n
    a = M.inputs{j};
    add_block('simulink/Sinks/Out1', [h '/pos_' a], 'Position', [800 100*j 830 100*j+14]);
end

for j = 1:n
    a = M.inputs{j};
    y = 100 * j;
    add_block('simulink/Math Operations/Sum', [h '/err_' a], 'Inputs', '+-', ...
        'Position', [110 y+35 130 y+55]);
    add_block('simulink/Continuous/PID Controller', [h '/pid_' a], ...
        'P', num2str(K(j).P, 10), 'I', num2str(K(j).I, 10), 'D', num2str(K(j).D, 10), ...
        'N', num2str(K(j).N, 10), 'Position', [180 y+30 260 y+60]);
    add_block('simulink/Math Operations/Sum', [h '/tsum_' a], 'Inputs', '++', ...
        'Position', [330 y 350 y+20]);
    add_line(h, ['tau_' a '/1'],  ['tsum_' a '/1'], 'autorouting', 'on');
    add_line(h, ['pref_' a '/1'], ['err_' a '/1'],  'autorouting', 'on');
    add_line(h, ['err_' a '/1'],  ['pid_' a '/1'],  'autorouting', 'on');
    add_line(h, ['pid_' a '/1'],  ['tsum_' a '/2'], 'autorouting', 'on');
    add_line(h, ['pid_' a '/1'],  ['tcorr_' a '/1'], 'autorouting', 'on');
    add_line(h, ['tsum_' a '/1'], ['plant/' num2str(j)], 'autorouting', 'on');
    % 0.5 ms low-pass on the fed-back position: no direct feedthrough, so no
    % algebraic loop through the PID (far faster than the loop, no effect on it)
    add_block('simulink/Continuous/Transfer Fcn', [h '/pf_' a], 'Numerator', '1', ...
        'Denominator', '[0.5e-3 1]', 'Position', [720 y+60 770 y+90]);
    add_line(h, ['plant/' num2str(M.posOut(j))], ['pf_' a '/1'], 'autorouting', 'on');
    add_line(h, ['pf_' a '/1'], ['err_' a '/2'], 'autorouting', 'on');
    add_line(h, ['plant/' num2str(M.posOut(j))], ['pos_' a '/1'], 'autorouting', 'on');
end
save_system(h, f);
end
