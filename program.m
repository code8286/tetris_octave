1;   % marks this as a script file, not a function file.

global board piece nextp px py score nlines level over paused W H cmap lastkey magic_variables = 1;

W = 10;  H = 20;
cmap = [0.07 0.07 0.10;    % 0 empty
        0.00 0.80 0.90;    % 1 I
        0.95 0.85 0.10;    % 2 O
        0.65 0.20 0.80;    % 3 T
        0.20 0.80 0.30;    % 4 S
        0.90 0.20 0.20;    % 5 Z
        0.20 0.35 0.90;    % 6 J
        0.95 0.55 0.10;    % 7 L
        0.30 0.30 0.36];   % 8 ghost

    function p = shape(k)
      S = {[1 1 1 1], [1 1; 1 1], [0 1 0; 1 1 1], [0 1 1; 1 1 0], ... 
       [1 1 0; 0 1 1], [1 0 0; 1 1 1], [0 0 1; 1 1 1]};
  p = S{k} * k;
end

function hit = collides(p, r, c)
  global board W H
  hit = false;
  [ri, ci] = find(p);
  for n = 1:numel(ri)
    rr = r + ri(n) - 1;
    cc = c + ci(n) - 1;
    if cc < 1 || cc > W || rr > H || (rr >= 1 && board(rr, cc) ~= 0)
      hit = true;
      return
    end
  end
end

function spawn()
  global piece nextp px py over W
  piece = nextp;
  nextp = shape(randi(7));
  py = 1;
  px = floor((W - columns(piece)) / 2) + 1;
  if collides(piece, py, px)
    over = true;
  end
end

function new_game()
  global board nextp score nlines level over paused W H
  board  = zeros(H, W);
  score  = 0;  nlines = 0;  level = 1;
  over   = false;  paused = false;
  nextp  = shape(randi(7));
  spawn();
end

function lock_piece()
  global board piece px py score nlines level W
  [ri, ci] = find(piece);
  for n = 1:numel(ri)
    rr = py + ri(n) - 1;
    cc = px + ci(n) - 1;
    if rr >= 1
      board(rr, cc) = piece(ri(n), ci(n));
    end
  end
  full = all(board ~= 0, 2);
  k = sum(full);
  if k > 0
    board(full, :) = [];
    board = [zeros(k, W); board];
    pts = [100 300 500 800];
    score  = score + pts(k) * level;
    nlines = nlines + k;
    level  = 1 + floor(nlines / 10);
  end
  spawn();
end

function step_down()
  global piece px py
  if collides(piece, py + 1, px)
    lock_piece();
  else
    py = py + 1;
  end
end

function try_rotate()
  global piece px py
  q = rot90(piece, -1);
  for dx = [0 -1 1 -2 2]               % simple wall kicks
    if ~collides(q, py, px + dx)
      piece = q;  px = px + dx;
      return
    end
  end
end

function hard_drop()
  global piece px py score
  while ~collides(piece, py + 1, px)
    py = py + 1;
    score = score + 2;
  end
  lock_piece();
end

function on_key(src, evt)
  global piece px py over paused lastkey
  key = '';  ch = '';
  if isfield(evt, 'Key'),        key = lower(evt.Key);  end
  if isfield(evt, 'Character'),  ch  = evt.Character;   end
  if isempty(key),  key = lower(ch);  end
  if strcmp(ch, ' '),  key = 'space';  end
  lastkey = sprintf('"%s" (%s)', key, mat2str(double(ch)));


  switch key
    case {'q'}
      close(src);  return
    case {'r'}
      new_game();  return
    case {'p'}
      if ~over,  paused = ~paused;  end
      return
  end
  if over || paused,  return;  end
  switch key
    case {'leftarrow', 'left', 'a'}
      if ~collides(piece, py, px - 1),  px = px - 1;  end
    case {'rightarrow', 'right', 'd'}
      if ~collides(piece, py, px + 1),  px = px + 1;  end
    case {'downarrow', 'down', 's'}
      step_down();
    case {'uparrow', 'up', 'w'}
      try_rotate();
    case {'space'}
      hard_drop();
  end
end

function d = paint(d, p, r, c, val)
  [ri, ci] = find(p);
  for n = 1:numel(ri)
    rr = r + ri(n) - 1;
    cc = c + ci(n) - 1;
    if rr >= 1 && rr <= rows(d) && cc >= 1 && cc <= columns(d)
      if val == 0,  d(rr, cc) = p(ri(n), ci(n));  else  d(rr, cc) = val;  end
    end
  end
end

function redraw(himg, hnext, hax)
  global board piece nextp px py score nlines level over paused lastkey
  d = board;
  if ~over
    gr = py;                                  % ghost piece 
    while ~collides(piece, gr + 1, px),  gr = gr + 1;  end
    d = paint(d, piece, gr, px, 8);
  end
  d = paint(d, piece, py, px, 0);
  set(himg, 'CData', d + 1);

  nx = zeros(4, 4);
  nx = paint(nx, nextp, 1 + (rows(nextp) == 1) , 1, 0);
  set(hnext, 'CData', nx + 1);

  if over
    msg = '  GAME OVER - press R';
  elseif paused
    msg = '  PAUSED';
  else
    msg = '';
  end
  title(hax, sprintf('Score %d   Lines %d   Level %d%s', score, nlines, level, msg), ...
        'Color', [0.9 0.9 0.9]);
  xlabel(hax, sprintf('Arrows/WASD: move+rotate   Space: drop   P: pause   R: restart   Q: quit\nlast key: %s', lastkey), ...
         'Color', [0.8 0.8 0.8]);
  drawnow;
end

% ---------------- Figure setup ----------------
fig = figure('Color', [0.12 0.12 0.15], 'Name', 'Tetris', 'NumberTitle', 'off', ...
             'KeyPressFcn', @on_key);

ax = axes('Parent', fig, 'Position', [0.06 0.08 0.55 0.82]);
himg = image(ones(H, W));
colormap(ax, cmap);
set(himg, 'CDataMapping', 'direct');
axis(ax, 'equal');  axis(ax, 'tight');
set(ax, 'XTick', [], 'YTick', [], 'XColor', [0.5 0.5 0.5], 'YColor', [0.5 0.5 0.5]);
hold(ax, 'on');
for k = 0:W,  plot(ax, [k k] + 0.5, [0 H] + 0.5, 'Color', [0.18 0.18 0.22]);  end
for k = 0:H,  plot(ax, [0 W] + 0.5, [k k] + 0.5, 'Color', [0.18 0.18 0.22]);  end
xlabel(ax, 'Arrows: move/rotate   Space: drop   P: pause   R: restart   Q: quit', ...
       'Color', [0.8 0.8 0.8]);

ax2 = axes('Parent', fig, 'Position', [0.68 0.62 0.26 0.26]);
hnext = image(ones(4, 4));
colormap(ax2, cmap);
set(hnext, 'CDataMapping', 'direct');
axis(ax2, 'equal');  axis(ax2, 'tight');
set(ax2, 'XTick', [], 'YTick', [], 'XColor', [0.5 0.5 0.5], 'YColor', [0.5 0.5 0.5]);
title(ax2, 'NEXT', 'Color', [0.8 0.8 0.8]);

% ---------------- Game loop ----------------
new_game();
last = tic;
while ishandle(fig)
  interval = max(0.07, 0.8 * 0.85^(level - 1));
  if ~over && ~paused && toc(last) >= interval
    step_down();
    last = tic;
  end
  redraw(himg, hnext, ax);
  pause(0.02);
end
