--------------------------------------------------------------------
--
-- nodes@home/luaNodes/util
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.createJsonValueMessage ( value, unit )

    return [[{"value":]] .. value .. [[, "unit":"]] .. unit .. [["}]];
    
end

-- from: http://lua-users.org/wiki/SplitJoin
function M.split ( str, pattern )

    local t = {};  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pattern;
    local last_end = 1;
    local s, e, cap = str:find ( fpat, last_end );
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert ( t, cap );
        end
        last_end = e + 1
        s, e, cap = str:find ( fpat, last_end );
    end
    if last_end <= #str then
        cap = str:sub ( last_end );
        table.insert ( t, cap );
    end
    
    return t;
   
end

function M.splitTopic ( str )

   return M.split ( str, '[\\/]+' );
   
end

function M.getSensorData ( pin )

    print ( "[DHT] pin=" .. pin );

    local dht = require ( "dht" );
    
    local status, temperature, humidity, temp_decimial, humi_decimial = dht.read ( pin );
    
    if( status == dht.OK ) then

        print ( "[DHT] Temperature: " .. temperature .. " C" );
        print ( "[DHT] Humidity: " .. humidity .. "%" );
        
    elseif( status == dht.ERROR_CHECKSUM ) then
    
        print ( "[DHT] Checksum error" );
        temperature = nil;
        humidity = nil;
        
    elseif( status == dht.ERROR_TIMEOUT ) then
    
        print ( "[DHT] Time out" );
        temperature = nil;
        humidity = nil;
        
    end
    
    local result = status == dht.OK; 
    
    -- Release module
    dht = nil;
    package.loaded [ "dht" ] = nil;
    
--    local success = status == dht.OK;
    return result, temperature, humidity;
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------