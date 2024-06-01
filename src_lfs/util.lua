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

local tmr, wifi, node = tmr, wifi, node;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

-- https://stackoverflow.com/questions/52579137/i-need-the-lua-math-library-in-nodemcu
-- log e
local function ln ( x )

    assert ( x > 0 );

    local a, b, c, d, e, f = x < 1 and x or 1/x, 0, 0, 1, 1;

    repeat
       repeat
          c, d, e, f = c + d, b * d / e, e + 1, c;
       until ( c == f );
       b, c, d, e, f = b + 1 - a * c, 0, 1, 1, b;
    until ( b <= f );

    return a == x and f ~= 0 and -f or f;

 end

 -- log 10
 local function log ( x )

     return ln ( x ) / 2.3025850929940457;

 end

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

function M.deepsleep ( client, delay, duration )

    logger:info ( "deepsleep: initiate alarm for closing connection in " ..  delay/1000 .. " seconds" );

    -- wait with closing connection
    tmr.create ():alarm ( delay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
        function ()
            logger:debug ( "deepsleep: closing mqtt connection" );
            client:close ();
            logger:debug ( "deepsleep: closing wifi connection" );
            wifi.eventmon.register ( wifi.eventmon.STA_DISCONNECTED,
                function ( event )
                    logger:debug ( "deepsleep: Going to deep sleep for ".. duration/1000 .." seconds" );
                    if duration > 0 then duration = (duration - delay) * 1000 end
                    node.dsleep ( duration ); -- us, 1 -> RF_CAL after deep sleep 2-> no RF Call, sleep immediately
                end
            );
            wifi.sta.disconnect ();
        end
    );

end

-- https://github.com/MakeMagazinDE/Taupunktluefter/blob/main/Taupunkt_Lueftung/Taupunkt_Lueftung.ino
function M.tau ( temperature, humidity )

    logger:info ( "tau: t=" .. temperature .. " h=" .. humidity );

    local a = ( temperature < 0 ) and 7.6 or 7.5;
    local b = ( temperature < 0 ) and 240.7 or 237.3;

    -- Sättigungsdampfdruck in hPa
    local sdd = 6.1078 * math.pow ( 10, ( a * temperature ) / ( b + temperature ) );

    -- Dampfdruck in hPa
    local dd = sdd * ( humidity / 100 );

    -- v-Parameter
    local v = log ( dd / 6.1078 );

    -- Taupunkttemperatur (°C)
    local tau = ( b * v ) / ( a - v );

    logger:debug ( "tau: tau=" .. tau );

    return tau;

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------