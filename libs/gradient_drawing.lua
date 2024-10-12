--[[
      TODO:
      > support negative sizes
      > support more than 2 colours
      > support horizontal gradients (doubt)
]]

local table_insert      = table.insert;
local table_remove      = table.remove;

local math_ceil         = math.ceil;
local math_round        = math.round;
local math_max          = math.max;
local math_min          = math.min;

local string_format     = string.format;

local vector2_new       = Vector2.new;
local colour3_new       = Color3.new;
local drawing_new       = Drawing.new;

local lerp              = colour3_new().Lerp;
local error             = error;

local cached_squares = _G.cached_squares or {};
_G.cached_squares = cached_squares;

local square_mt = getrawmetatable and getrawmetatable(Drawing.new('Square')) or getmetatable(Drawing.new('Square'));
local __newindex = square_mt.__newindex;

local create_gradient = function()
      local drawingobject     = newproxy(true);
      local metatable         = getmetatable(drawingobject);

      local properties = {
            Visible = false;
            Transparency = 1;
            ZIndex = 0;
            ColorStart = colour3_new();
            ColorEnd = colour3_new();
            Size = vector2_new();
            Position = vector2_new();
      };
      local hidden = {
            size = 1;
            amount = 0;
            squares = {};
      };

      local should_show = function()
            local size = properties.Size;
            return properties.Visible and size.X > 0 and size.Y > 0 and properties.Transparency > 0;
      end;
      local update_position = function()
            local position = properties.Position;
            local squares = hidden.squares;

            if (not squares[1]) then
                  return;
            end;

            local offset = squares[1].Position - position;
            for i = 1, #squares do
                  squares[i].Position -= offset;
            end;
      end;
      local update_size = function()
            local position    = properties.Position;
            local size        = properties.Size;
            local colourstart = properties.ColorStart;
            local colourend   = properties.ColorEnd;

            local pixelsize   = hidden.size;
            local pixelremain = size.Y;

            local squares     = hidden.squares;
            local amount      = hidden.amount;

            for i = 1, amount do
                  local square = squares[i];
                  
                  __newindex(square, 'Position', position + vector2_new(0, (i-1) * pixelsize));
                  __newindex(square, 'Size', vector2_new(size.X, math_min(pixelsize, pixelremain)));
                  __newindex(square, 'Color', lerp(colourstart, colourend, i / amount));

                  pixelremain -= pixelsize;
            end;
      end;
      local refresh_squares = function()
            local squares     = hidden.squares;
            local current_amt = #squares;

            local required    = hidden.amount - current_amt;
            if (required == 0) then
                  return;
            elseif (required < 0) then
                  -- removing squares
                  required = -required;
                  for i = current_amt, current_amt - required + 1, -1 do
                        local square = squares[i];
                        __newindex(square, 'Visible', false);
                        table_insert(cached_squares, square);
                        table_remove(squares, i);
                  end;
                  return;
            end;
            -- adding more squares
            for i = 1, required do
                  local square = cached_squares[i];
                  if (square) then
                        table_remove(cached_squares, i);
                  else
                        square = drawing_new('Square');
                        __newindex(square, 'Filled', true);
                        __newindex(square, 'Thickness', 1);
                  end;
                  __newindex(square, 'Visible', true);
                  __newindex(square, 'Transparency', properties.Transparency);
                  __newindex(square, 'ZIndex', properties.ZIndex);
                  table_insert(squares, square);
            end;
      end;
      local remove_squares = function()
            local squares = hidden.squares;
            for i = 1, hidden.amount do
                  local square = squares[i];
                  __newindex(square, 'Visible', false);
                  table_insert(cached_squares, square);
            end;
            hidden.squares = {};
      end;

      local __index = function(self, index)
            if (index == 'Remove' or index == 'Destroy') then
                  return function()
                        remove_squares();

                        local onindex           = function()
                              error('DrawingObject no longer exists');
                        end;
                        metatable.__newindex    = onindex;
                        metatable.__index       = onindex;
                  end;
            end;
            return properties[index];
      end;
      local __newindex = function(self, index, newindex)
            local old_value = properties[index];
            if (old_value == nil) then
                  return error( string_format('%* is not a valid member of DrawingObject', index) );
            elseif (typeof(old_value) ~= typeof(newindex)) then
                  return error( string_format('invalid property type for %* (%* expected, got %*)', index, typeof(old_value), typeof(newindex)) );
            elseif (newindex == old_value) then
                  return;
            end;

            local squares = hidden.squares;
            local is_showing = #squares > 0;

            properties[index] = newindex;

            if (index == 'Size') then
                  local size = properties.Size;
                  local pixelsize = math_round(math_max(size.Y / 11.5, 3));
                  
                  hidden.size = pixelsize;
                  hidden.amount = (math_ceil(size.Y) + pixelsize / 2) // pixelsize;
                  
                  if (size.Y <= 0 or size.X <= 0) then
                        remove_squares();
                  elseif (properties.Visible and properties.Transparency > 0) then
                        refresh_squares();
                        update_size();
                  end;
            elseif (index == 'Visible') then
                  if ( should_show() ) then
                        refresh_squares();
                        update_size();
                  else
                        remove_squares();
                  end;
            elseif (index == 'Position' and is_showing) then
                  update_position();
            elseif ((index == 'Transparency' or index == 'ZIndex') and is_showing) then
                  if (properties.Transparency <= 0) then
                        remove_squares();
                  else
                        for i = 1, #squares do
                              __newindex(squares[i], index, newindex);
                        end;
                  end;
            elseif ( (index == 'ColorStart' or index == 'ColorEnd') and is_showing) then
                  local amount = hidden.amount;
                  for i = 1, amount do
                        __newindex(squares[i], 'Color', lerp(properties.ColorStart, properties.ColorEnd, i / amount));
                  end;
            end;
      end;

      metatable.__metatable   = 'The metatable is locked';
      metatable.__index       = __index;
      metatable.__newindex    = __newindex;

      return drawingobject;
end;

-- Drawing.new implemenation
local integrate_gradient = function() -- call me to integrate Gradient's into real drawing
      local setreadonly = setreadonly;
      
      local old_drawingnew = Drawing.new;
      local isreadonly = table.isfrozen(Drawing);
      if (not isreadonly) then
            setreadonly = function() end;
      end;
      
      setreadonly(Drawing, false);

      Drawing.new = function(t)
            if (t == 'Gradient') then
                  return create_gradient();
            end;
            return old_drawingnew(t);
      end;
      
      setreadonly(Drawing, isreadonly);
end;


if (...) then
      integrate_gradient();
end;

return create_gradient, integrate_gradient;
