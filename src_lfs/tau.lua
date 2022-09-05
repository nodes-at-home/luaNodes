--------------------------------------------------------------------
--
-- nodes@home/luaNodes/math2
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 05.09.2022

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

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

-- https://github.com/MakeMagazinDE/Taupunktluefter/blob/main/Taupunkt_Lueftung/Taupunkt_Lueftung.ino
function M.calculate ( temperature, humidity )

    logger:info ( "calculate: t=" .. temperature .. " h=" .. humidity );

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

    logger:debug ( "calculate: tau=" .. tau );

    return tau;

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------