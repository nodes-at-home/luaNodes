--------------------------------------------------------------------
--
-- nodes@home/luaNodes/_init
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.09.2016

-- dofile ( "startup.lua" );

-------------------------------------------------------------------------------
--  Settings

local NO_BOOT_FILE = "no_boot";
local LFS_RELOAD_FILE = "lfs_reload";
local LFS_TS_FILE = "lfs.img.ts";

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

local startTelnet;

--------------------------------------------------------------------
-- public

package.loaders [3] = function ( module ) -- loader_flash
    local fn, ba = node.flashindex ( module );
    return ba and "Module not in LFS" or fn;
end

print ( "[INIT] boot: rawcode=" .. rawcode .. " reason=" .. bootreason .. " cause=" .. tostring ( cause ) );


if ( file.exists ( LFS_RELOAD_FILE ) ) then
    file.remove ( LFS_RELOAD_FILE );
    file.remove ( "_" .. LFS_TS_FILE );
    node.restart ();
    print ( "[INIT] restart after lfs reload" );
    return;
else
    if ( bootreason == 1 or bootreason == 2 or bootreason == 3 ) then
        if ( file.exists ( NO_BOOT_FILE ) ) then
            print ( "[INIT] booting after error; NO STARTUP" );
            startTelnet = true;
        else
            file.open ( NO_BOOT_FILE, "w" );
            file.close ();
        end
    else
        if ( file.exists ( NO_BOOT_FILE ) ) then
            file.remove ( NO_BOOT_FILE );
        end
    end

end

--require ( "_lfs" );

require ( "startup" ).start ( startTelnet );

