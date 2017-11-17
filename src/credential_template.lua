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
        M.ssid = CREDENTIALS [mode].ssid;
        M. password = CREDENTIALS [mode]. password;
    end
    
end

--------------------------------------------------------------------

print ( "[MODULE] loaded: " .. moduleName )

-- M.init ( "prod" );

return M;

--------------------------------------------------------------------
