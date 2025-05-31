local table_insert            = table.insert;
local table_remove            = table.remove;
local table_find              = table.find;

local signalHandler           = {};
signalHandler.__index 		= signalHandler;

signalHandler.new = function(signal)
      local self = setmetatable({ 

            active      = true;
            signal      = signal;

            connections = {};
      }, signalHandler);


      if (self.signal) then
            self.signalConnection = self.signal:Connect(function(...) self:Fire(...); end);
      end;

      return self;
end;

function signalHandler:Fire(...)
      local connections = self.connections;
      for i = 1, #connections do
            task.spawn(connections[i], ...);
      end;
end;
function signalHandler:Connect(_function)
      local connectionObject = {};

      connectionObject.Connected = true;
      connectionObject.Disconnect = function()
            if (not connectionObject.Connected) then
                  return;
            end;
            connectionObject.Connected = false;
            table_remove( self.connections, table_find(self.connections, _function) );
      end;

      table_insert(self.connections, _function);
      return connectionObject;
end;
function signalHandler:Remove()
      if (not self.active) then
            return;
      end;
      self.active = false;
      self.connections = {};

      if (self.signalConnection) then
            self.signalConnection:Disconnect();
      end;
end;

return signalHandler;
