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

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

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

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------