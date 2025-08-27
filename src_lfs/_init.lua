--------------------------------------------------------------------
--
-- nodes@home/luaNodes/_init
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.09.2016

local node, _file = node, file;

-- set file compatiblity table in global context
file = {};
file.open = io and io.open or _file.open;
file.read = io and io.read or _file.read;
file.write = io and io.write or _file.write;
file.close = io and io.close or _file.close;
file.exists = _file.exists;
file.rename = _file.rename;
file.remove = _file.remove;
local file = file;
print ( "_init: file=" .. tostring ( file ) .. " file.open=" .. tostring ( file.open ) );


-------------------------------------------------------------------------------
--  Settings

local NO_BOOT_FILE = "no_boot";
local LFS_RELOAD_FILE = "lfs_reload";
local LFS_TS_FILE = "lfs.img.ts";

local START_TELNET_ON_ERROR = false;

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

local startTelnet = false;

--------------------------------------------------------------------
-- public

--------------------------------------------------------------------
-- application global

function unrequire ( module )

    local m = package.loaded [module];
    if ( m and m.subunrequire ) then m.subunrequire (); end

    package.loaded [module] = nil
    _G [module] = nil

end

function tohex ( byte, len )

    return "0x" .. string.format( "%0" .. (len or 2) .. "X", byte );

end

package.loaders [3] = function ( module ) -- loader_flash
    local fn, ba = node.flashindex ( module );
    return ba and "Module not in LFS" or fn;
end

is_ESP32 = node.chipmodel ~= nil;

--------------------------------------------------------------------

print ( "[INIT] boot: rawcode=" .. rawcode .. " reason=" .. bootreason .. " cause=" .. tostring ( cause ) );


if ( START_TELNET_ON_ERROR and ( bootreason == 1 or bootreason == 2 or bootreason == 3 ) ) then
    if ( file.exists ( NO_BOOT_FILE ) ) then
        print ( "[INIT] booting after error; NO STARTUP" );
        startTelnet = true;
    else
        local f = file.open ( NO_BOOT_FILE, "w" );
        f:close ();
    end
else
    if ( file.exists ( NO_BOOT_FILE ) ) then
        file.remove ( NO_BOOT_FILE );
    end
end

require ( "startup" ).start ( startTelnet );

