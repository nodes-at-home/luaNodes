--------------------------------------------------------------------
--
-- nodes@home/luaNodes/credential_template
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 20.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

--------------------------------------------------------------------
-- vars

local CREDENTIALS = {

    prod = { ssid = "ssid", password = "pw"},
    dev = { ssid = "ssid", password = "pw"},
    -- some more configs

};

--------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.init ( mode )

    if ( mode and type ( mode ) == "string" ) then
        return ( { ssid = CREDENTIALS [mode].ssid, password = CREDENTIALS [mode]. password } );
    end

end

--------------------------------------------------------------------

logger.debug ( moduleName, "loaded: " );

return M;

--------------------------------------------------------------------
