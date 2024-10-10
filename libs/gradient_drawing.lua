local table_insert = table.insert;
local table_remove = table.remove;

local math_ceil   = math.ceil;

local cached_squares = _G.cached_squares or {};
_G.cached_squares = cached_squares;

local square_mt = getrawmetatable(Drawing.new('Square'));
local __index = square_mt.__index;
local __newindex = square_mt.__newindex;

local create_gradient = function()
      local properties = {
            Visible = false;
            Transparency = 1;
            ZIndex = 0;

            ColorStart = Color3.new();
            ColorEnd = Color3.new();
            PixelSize = 2;
            Size = Vector2.new();
            Position = Vector2.new();
      };
      local hidden_properties = {
            required_squares = (math_ceil(properties.Size.Y) + properties.PixelSize / 2) // properties.PixelSize;
            cached_squares = {};
      };

      local update_position = function()
            local position = properties.Position;
            local squares = hidden_properties.cached_squares;

            if (not squares[1]) then
                  return;
            end;

            local offset = squares[1].Position - position;
            for i = 1, #squares do
                  squares[i].Position -= offset;
            end;
      end;
      local update_size = function()
            local position = properties.Position;
            local size = properties.Size;
            local pixels_left = size.Y;
            local pixel_size = properties.PixelSize;
            local squares = hidden_properties.cached_squares;

            for i = 1, #squares do
                  local square = squares[i];
                  
                  __newindex(square, 'Position', position + Vector2.new(0, (i-1)*pixel_size));
                  __newindex(square, 'Size', Vector2.new(size.X, math.min(pixel_size, pixels_left)));
                  __newindex(square, 'Color', properties.ColorStart:Lerp(properties.ColorEnd, i / #squares));

                  pixels_left -= pixel_size;
            end;
      end;
      local recache_squares = function()
            local squares = hidden_properties.cached_squares;
            local current = #squares;
            local amount = hidden_properties.required_squares - current;

            if (amount == 0) then
                  return;
            elseif (amount < 0) then
                  amount = -amount;
                  for i = current, current-amount+1, -1 do
                        local square = squares[i];
                        __newindex(square, 'Visible', false);
                        table_insert(cached_squares, square);
                        table_remove(squares, i);
                  end;
                  return;
            end;
            for i = 1, amount do
                  local square = cached_squares[i];
                  if (square) then
                        table_remove(cached_squares, i);
                  else
                        square = Drawing.new('Square');
                        __newindex(square, 'Filled', true);
                        __newindex(square, 'Thickness', 1);
                  end;
                  __newindex(square, 'Visible', true);
                  __newindex(square, 'Transparency', properties.Transparency);
                  __newindex(square, 'ZIndex', properties.ZIndex);

                  table_insert(squares, square);
            end;
      end;
      local free_squares = function()
            local squares = hidden_properties.cached_squares;
            for i = 1, #squares do
                  local square = squares[i];
                  __newindex(square, 'Visible', false);
                  table_insert(cached_squares, square);
            end;
            hidden_properties.cached_squares = {};
      end;

      local drawingObject = newproxy(true);
      local metatable = getmetatable(drawingObject);

      metatable.__metatable = 'The metatable is locked';
      metatable.__index = function(self, index)
            if (index == 'Remove' or index == 'Destroy') then
                  return function(self)
                        free_squares();
                        metatable.__newindex = function()
                              error('DrawingObject no longer exists');
                        end;
                        metatable.__index = function() 
                              error('DrawingObject no longer exists');
                        end;
                  end;
            end;
            return properties[index];
      end;
      metatable.__newindex = function(self, index, newindex)
            if (properties[index] == nil) then
                  return error(string.format('%* is not a valid member of %*', index, self));
            elseif (typeof(properties[index]) ~= typeof(newindex)) then
                  return error(string.format('invalid property type on %* (%* expected, got %*)', index, typeof(properties[index]), typeof(newindex)));
            elseif (newindex == properties[index]) then
                  return;
            end;

            properties[index] = newindex;

            if (index == 'Size' or index == 'PixelSize') then
                  local size = properties.Size;

                  local pixelsize = properties.PixelSize;

                  hidden_properties.required_squares = (math_ceil(size.Y) + pixelsize / 2) // pixelsize;
                  if (properties.Visible and size.Y > 0 and size.X > 0) then
                        recache_squares();
                        update_size();
                  elseif (size.Y <= 0 or size.X <= 0) then
                        free_squares();
                  end;
            elseif (index == 'Position') then
                  if (properties.Visible) then
                        update_position();
                  end;
            elseif (index == 'Visible') then
                  if (newindex) then
                        recache_squares();
                        update_size();
                  else
                        free_squares();
                  end;
            elseif ((index == 'Transparency' or index == 'ZIndex') and properties.Visible) then
                  if (properties.Transparency <= 0) then
                        free_squares();
                  else
                        local squares = hidden_properties.cached_squares;
                        for i = 1, #squares do
                              __newindex(squares[i], index, newindex);
                        end;
                  end;
            elseif ( (index == 'ColorStart' or index == 'ColorEnd') and properties.Visible) then
                  local squares = hidden_properties.cached_squares;
                  for i = 1, #squares do
                        __newindex(squares[i], 'Color', properties.ColorStart:Lerp(properties.ColorEnd, i/#squares));
                  end;
            end;
      end;
      return drawingObject;
end;

return create_gradient;
