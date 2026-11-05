%% machine_viewer.m
% Schematic 3-D replay of a recorded test on the Huron U-Mill 5.
% Press Run: pick a CSV, the machine moves in real time.
%
% Kinematics (U-Mill 5): the table moves along X and carries the cradle
% (A, tilt about X) with the rotary table (C) on it; the spindle head moves
% along Y and Z. The path of the tool tip is drawn on the rotary table, so
% you see what the tool would trace on the part.
%
% CSV: column t [s] and pos_x pos_y pos_z [mm], pos_a pos_c [deg] (the
% feedback.csv format). Missing columns are taken as 0. A third plot shows
% the drive signals, if the file has them (first kind found):
%   tau_*  torque [N m]    cur_*  current iq [A]    pow_*  active power [W]
% with * = x y z sp a c. Torques can also come from a matching *torque*.csv
% next to a *feedback*.csv. Test files are in data/.
%
% Keys:  space  pause / play          up / down     speed x2 / /2
%        left / right  -/+ 2 s        r  restart     t  path on/off
%        q or Esc  quit (the figure stays open)
clear; close all;

%% ---------------- settings ----------------
csvFile   = '';           % '' -> file dialog
speed     = 1;            % playback speed (1 = real time)
fps       = 30;           % refresh rate of the animation
relative  = true;         % true: X Y Z start from 0 (first sample); false: absolute + 'home'
home      = [0 0 0];      % [mm] machine X Y Z drawn at the centre, when relative = false
sgn       = struct('x', 1, 'y', 1, 'z', 1, 'a', 1, 'c', 1);   % flip an axis if it moves the wrong way
zTip0     = 150;          % [mm] tool tip above the A axis at the start
showPath  = true;
saveVideo = false;        % true: render to an MP4 (not real time) instead of playing
videoFile = 'machine_viewer.mp4';

%% ---------------- data ----------------
here = fileparts(mfilename('fullpath'));
if isempty(csvFile)
    start = here;
    if exist(fullfile(here, 'data'), 'dir'), start = fullfile(here, 'data'); end
    [f, p] = uigetfile({'*.csv', 'CSV files (*.csv)'}, 'Recording to replay', start);
    if isequal(f, 0), return; end
    csvFile = fullfile(p, f);
end
T  = readtable(csvFile, 'VariableNamingRule', 'preserve');
vn = T.Properties.VariableNames;
t  = double(T.t);
[t, iu] = unique(t);
T  = T(iu, :);
N  = numel(t);
axn = {'x', 'y', 'z', 'a', 'c'};
P = zeros(N, 5);                                  % mm, mm, mm, deg, deg
for j = 1:5
    c = ['pos_' axn{j}];
    if ismember(c, vn)
        P(:, j) = double(T.(c)) * sgn.(axn{j});
    else
        fprintf('column %s missing, taken as 0\n', c);
    end
end
if relative
    P(:, 1:3) = P(:, 1:3) - P(1, 1:3);
else
    P(:, 1:3) = P(:, 1:3) - home;
end

% drive signals: torque, current or power, in the same file or in the matching torque file
kinds = {'tau_', 'N m'; 'cur_', 'A'; 'pow_', 'W'};
sigAx = {'x', 'y', 'z', 'sp', 'a', 'c'};
Tq = [];
tq = t;
kind = 0;
for k = 1:size(kinds, 1)
    if any(startsWith(vn, kinds{k, 1})), Tq = T; kind = k; break; end
end
if kind == 0
    [p, f, e] = fileparts(csvFile);
    ft = fullfile(p, [strrep(f, 'feedback', 'torque') e]);
    if contains(f, 'feedback') && exist(ft, 'file')
        Tq = readtable(ft, 'VariableNamingRule', 'preserve');
        [tq, iq] = unique(double(Tq.t));
        Tq = Tq(iq, :);
        kind = 1;
    end
end
tau = [];
tauNames = {};
if kind > 0
    for j = 1:numel(sigAx)
        c = [kinds{kind, 1} sigAx{j}];
        if ismember(c, Tq.Properties.VariableNames)
            tau(:, end + 1) = double(Tq.(c)); %#ok<SAGROW>
            tauNames{end + 1} = upper(sigAx{j}); %#ok<SAGROW>
        end
    end
end

% tool-tip path in the frame of the rotary table (moves with it)
A = deg2rad(P(:, 4));
C = deg2rad(P(:, 5));
w = [P(:, 1), P(:, 2), zTip0 + P(:, 3)];   % tool tip minus table translation (table moves -X)
% undo A (rotation about X), then C (rotation about Z)
v1 = [w(:, 1), cos(A) .* w(:, 2) + sin(A) .* w(:, 3), -sin(A) .* w(:, 2) + cos(A) .* w(:, 3)];
path = [cos(C) .* v1(:, 1) + sin(C) .* v1(:, 2), -sin(C) .* v1(:, 1) + cos(C) .* v1(:, 2), v1(:, 3)];

%% ---------------- scene ----------------
fig = figure('Name', ['Machine viewer - ' csvFile], 'Color', 'w', 'NumberTitle', 'off', ...
             'Units', 'normalized', 'Position', [0.05 0.08 0.9 0.82]);
ax3 = axes(fig, 'Position', [0.01 0.04 0.62 0.9]);
hold(ax3, 'on');
axis(ax3, 'equal');
axis(ax3, 'off');
xlim(ax3, [-1100 1100]); ylim(ax3, [-950 950]); zlim(ax3, [-650 1050]);
view(ax3, -55, 22);

grey  = [0.55 0.57 0.60];
dark  = [0.30 0.32 0.35];
blue  = [0.27 0.45 0.68];
orng  = [0.90 0.55 0.20];
green = [0.35 0.60 0.45];
part  = [0.55 0.75 0.95];

% static: bed, portal
box(ax3, [-950 -520 -620], [950 520 -470], grey);
box(ax3, [ 180 -880 -620], [380 -700  950], grey);           % pillars
box(ax3, [ 180  700 -620], [380  880  950], grey);
box(ax3, [ 180 -880  950], [380  880 1050], grey);           % cross-beam along Y
quiver3(ax3, -900, -480, -460, 160, 0, 0, 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.6);
quiver3(ax3, -900, -480, -460, 0, 160, 0, 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.6);
quiver3(ax3, -900, -480, -460, 0, 0, 160, 0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.6);
text(ax3, -720, -480, -460, 'X', 'Color', 'r', 'FontWeight', 'bold');
text(ax3, -900, -300, -460, 'Y', 'Color', 'g', 'FontWeight', 'bold');
text(ax3, -900, -480, -280, 'Z', 'Color', 'b', 'FontWeight', 'bold');

% X: table slide with the trunnion supports
gX = hgtransform('Parent', ax3);
box(gX, [-480 -360 -470], [480 360 -410], blue);
box(gX, [-470 -130 -410], [-380 130 60], blue);
box(gX, [ 380 -130 -410], [ 470 130 60], blue);
cylX(gX, 70, -500, -375, 0, dark);                            % A axis bearings
cylX(gX, 70,  375,  500, 0, dark);

% A: cradle
gA = hgtransform('Parent', gX);
box(gA, [-300 -290 -160], [300 290 -100], orng);
box(gA, [-375 -110 -160], [-300 110 50], orng);
box(gA, [ 300 -110 -160], [ 375 110 50], orng);

% C: rotary table, slots, index mark, workpiece, tool path
gC = hgtransform('Parent', gA);
cylZ(gC, 250, -100, -30, dark);
for s = -150:100:150
    line('Parent', gC, 'XData', [-1 1] * sqrt(250^2 - s^2), 'YData', [s s], 'ZData', [-29 -29], ...
         'Color', [0.15 0.15 0.15], 'LineWidth', 2);
end
box(gC, [225 -12 -31], [250 12 -28], [0.85 0.1 0.1]);        % index mark at C = 0
box(gC, [-60 -40 -30], [60 40 30], part);                      % workpiece
hPath = line('Parent', gC, 'XData', nan, 'YData', nan, 'ZData', nan, 'Color', [0.85 0.1 0.1], 'LineWidth', 1.2);

% Y: saddle on the cross-beam;  Z: ram, spindle, tool
gY = hgtransform('Parent', ax3);
box(gY, [100 -170 520], [180 170 1000], green);
gZ = hgtransform('Parent', gY);
box(gZ, [-95 -95 zTip0 + 260], [100 95 zTip0 + 900], green);
cylZ(gZ, 70, zTip0 + 110, zTip0 + 260, dark);                 % spindle nose
cylZ(gZ, 8, zTip0, zTip0 + 110, [0.8 0.8 0.85]);              % tool
line('Parent', gZ, 'XData', 0, 'YData', 0, 'ZData', zTip0, 'Marker', '.', 'MarkerSize', 14, 'Color', 'k');  % tool tip

camlight(ax3, 'headlight');
lighting(ax3, 'gouraud');
hTitle = title(ax3, '', 'FontName', 'FixedWidth', 'FontSize', 11);

% side plots with a time cursor
nPl = 2 + ~isempty(tau);
h   = 0.88 / nPl;
axL = axes(fig, 'Position', [0.69 0.06 + (nPl - 1) * h 0.29 h - 0.05]);
plot(axL, t, P(:, 1:3)); grid(axL, 'on');
ylabel(axL, 'mm'); legend(axL, 'X', 'Y', 'Z', 'Location', 'best');
axR = axes(fig, 'Position', [0.69 0.06 + (nPl - 2) * h 0.29 h - 0.05]);
plot(axR, t, P(:, 4:5)); grid(axR, 'on');
ylabel(axR, 'deg'); legend(axR, 'A', 'C', 'Location', 'best');
cur = [xline(axL, t(1), 'k'), xline(axR, t(1), 'k')];
if ~isempty(tau)
    axT = axes(fig, 'Position', [0.69 0.06 0.29 h - 0.05]);
    plot(axT, tq, tau); grid(axT, 'on');
    ylabel(axT, kinds{kind, 2}); legend(axT, tauNames, 'Location', 'best');
    cur(end + 1) = xline(axT, t(1), 'k');
    xlabel(axT, 't [s]');
else
    xlabel(axR, 't [s]');
end

H = struct('gX', gX, 'gA', gA, 'gC', gC, 'gY', gY, 'gZ', gZ, 'path', hPath, 'cur', cur, ...
           'title', hTitle, 't', t, 'P', P, 'pathPts', path);

%% ---------------- play ----------------
if saveVideo
    vw = VideoWriter(videoFile, 'MPEG-4');
    vw.FrameRate = fps;
    open(vw);
    for tp = t(1):speed / fps:t(end)
        k = max(1, sum(t <= tp));
        draw_frame(H, k, speed, false, showPath);
        drawnow;
        writeVideo(vw, getframe(fig));
    end
    close(vw);
    fprintf('Video written to %s\n', videoFile);
    return
end

st = struct('tp', t(1), 'speed', speed, 'paused', false, 'quit', false, 'path', showPath);
setappdata(fig, 'st', st);
set(fig, 'KeyPressFcn', @(src, ev) on_key(src, ev, t));
clk = tic;
while isgraphics(fig)
    st  = getappdata(fig, 'st');
    if st.quit, break; end
    dtw = toc(clk);
    clk = tic;
    if ~st.paused
        st.tp = st.tp + dtw * st.speed;
    end
    if st.tp >= t(end)
        st.tp = t(end);
        st.paused = true;
    end
    setappdata(fig, 'st', st);
    k = max(1, sum(t <= st.tp));
    draw_frame(H, k, st.speed, st.paused, st.path);
    pause(1 / fps);      % also runs the key callbacks
end

% =====================================================================
function draw_frame(H, k, speed, paused, showPath)
p = H.P(k, :);
H.gX.Matrix = makehgtform('translate', [-p(1) 0 0]);
H.gA.Matrix = makehgtform('xrotate', deg2rad(p(4)));
H.gC.Matrix = makehgtform('zrotate', deg2rad(p(5)));
H.gY.Matrix = makehgtform('translate', [0 p(2) 0]);
H.gZ.Matrix = makehgtform('translate', [0 0 p(3)]);
if showPath
    set(H.path, 'XData', H.pathPts(1:k, 1), 'YData', H.pathPts(1:k, 2), 'ZData', H.pathPts(1:k, 3));
else
    set(H.path, 'XData', nan, 'YData', nan, 'ZData', nan);
end
for c = H.cur
    c.Value = H.t(k);
end
if paused, s = 'PAUSED'; else, s = sprintf('x%g', speed); end
H.title.String = sprintf('t %7.2f s  %-6s  X %8.2f  Y %8.2f  Z %8.2f mm   A %7.2f  C %7.2f deg', ...
    H.t(k), s, p(1), p(2), p(3), p(4), p(5));
end

function on_key(fig, ev, t)
st = getappdata(fig, 'st');
switch ev.Key
    case 'space'
        if st.tp >= t(end), st.tp = t(1); end
        st.paused = ~st.paused;
    case 'uparrow',    st.speed = min(st.speed * 2, 64);
    case 'downarrow',  st.speed = max(st.speed / 2, 1/16);
    case 'rightarrow', st.tp = min(st.tp + 2, t(end));
    case 'leftarrow',  st.tp = max(st.tp - 2, t(1));
    case 'r',          st.tp = t(1); st.paused = false;
    case 't',          st.path = ~st.path;
    case {'q', 'escape'}, st.quit = true;
end
setappdata(fig, 'st', st);
end

function hp = box(parent, lo, hi, col)
V = [lo(1) lo(2) lo(3); hi(1) lo(2) lo(3); hi(1) hi(2) lo(3); lo(1) hi(2) lo(3); ...
     lo(1) lo(2) hi(3); hi(1) lo(2) hi(3); hi(1) hi(2) hi(3); lo(1) hi(2) hi(3)];
F = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
hp = patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', col, ...
           'EdgeColor', col * 0.6, 'FaceLighting', 'flat');
end

function cylZ(parent, r, z0, z1, col)
% cylinder along Z through the origin, from z0 to z1, with caps
[xc, yc, zc] = cylinder(r, 48);
surf(xc, yc, z0 + (z1 - z0) * zc, 'Parent', parent, 'FaceColor', col, 'EdgeColor', 'none');
patch('Parent', parent, 'XData', xc(1, :), 'YData', yc(1, :), 'ZData', z0 * ones(1, size(xc, 2)), ...
      'FaceColor', col, 'EdgeColor', 'none');
patch('Parent', parent, 'XData', xc(1, :), 'YData', yc(1, :), 'ZData', z1 * ones(1, size(xc, 2)), ...
      'FaceColor', col, 'EdgeColor', 'none');
end

function cylX(parent, r, x0, x1, z, col)
% cylinder along X at height z, from x0 to x1
g = hgtransform('Parent', parent, 'Matrix', makehgtform('translate', [0 0 z], 'yrotate', pi/2));
cylZ(g, r, x0, x1, col);       % yrotate(pi/2) maps local z to +x
end
