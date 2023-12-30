--------------------------------------------------------------------
--
-- nodes@home/luaNodes/_init
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.09.2016

-------------------------------------------------------------------------------
--  Settings

local node, file = node, file;

local NO_BOOT_FILE = "no_boot";

----------------------------------------------------------------------------------------
-- private

-- boot reason https://nodemcu.readthedocs.io/en/master/en/modules/node/#nodebootreason
-- 0, power-on
-- 1, hardware watchdog reset
-- 2, exception reset
-- 3, software watchdog reset
-- 4, software restart
-- 5, wake from deep sleep
-- 6, external reset
local rawcode, bootreason, cause = node.bootreason ();

--------------------------------------------------------------------
-- public

package.loaders [3] = function ( module ) -- loader_flash
    local fn, ba = node.flashindex ( module );
    return ba and "Module not in LFS" or fn;
end

--------------------------------------------------------------------

print ( "[INIT] boot: rawcode=" .. rawcode .. " reason=" .. bootreason .. " cause=" .. tostring ( cause ) );

local nobootfile = io.open ( NO_BOOT_FILE );
if ( bootreason == 1 or bootreason == 2 or bootreason == 3 ) then
    if ( nobootfile ) then
        print ( "[INIT] booting after error; NO STARTUP" );
        require ( "telnet" ):open ( wifiCredential.ssid, wifiCredential.password );
        return
    else
        file.open ( NO_BOOT_FILE, "w" );
        file.close ();
    end
else
    if ( nobootfile ) then
        file.remove ( NO_BOOT_FILE );
    end
end

require ( "startup" ).init ();

