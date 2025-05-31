local signal_handle		= {};
signal_handle.__index 		= signal_handle;

signal_handle.new = function(signal)
      local self = setmetatable({ 

            active      = true;
            signal      = signal;

            connections = {};
      }, signal_handle);


      if (self.signal) then
            self.signal_connection = self.signal:Connect(function(...) self:Fire(...); end);
      end;

      return self;
end;

function signal_handle:Fire(...)
      local connections = self.connections;
      for i = 1, #connections do
            task.spawn(connections[i], ...);
      end;
end;
function signal_handle:Connect(_function)
      local connectionObject = {};

      connectionObject.Connected = true;
      connectionObject.Disconnect = function()
            if (not connectionObject.Connected) then
                  return;
            end;
            connectionObject.Connected = false;
            table_remove( self.connection, table_find(self.connection, _function) );
      end;

      table_insert(self.connections, _function);
      return connectionObject;
end;
function signal_handle:Remove()
      if (not self.active) then
            return;
      end;
      self.active = false;
      self.connections = {};

      if (self.signal_connection) then
            self.signal_connection:Disconnect();
      end;
end;

return signal_handle;
