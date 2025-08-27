--------------------------------------------------------------------
--
-- nodes@home/luaNodes/init
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 27.10.2018
--
-- start from lfs

local node, _file, tmr = node, file, tmr;

local file = {};
file.open = io and io.open or _file.open;
file.read = io and io.read or _file.read;
file.write = io and io.write or _file.write;
file.close = io and io.close or _file.close;
file.exists = _file.exists;
file.rename = _file.rename;
file.remove = _file.remove;

-------------------------------------------------------------------------------
--  Settings

local is_ESP32 = node.chipmodel ~= nil;

local DELAY = 2000;
local LFS_FILENAME = is_ESP32 and "lfs_esp32.img" or "lfs_esp8266.img";
local LFS_TS_FILE = "lfs.img.ts";
local LFS_RELOAD_FILE = "lfs_reload";

print ( "[INIT] is_ESP32=" .. tostring ( is_ESP32 ) .. ", LFS_FILENAME=" .. LFS_FILENAME );

----------------------------------------------------------------------------------------
-- private

local lfsts = node.LFS.time;
local expectedLfsts;

print ( "[INIT] lfsts=" .. tostring ( lfsts ) );

--------------------------------------------------------------------
-- public

local f;

-- restart after lfs reload
if ( file.exists ( LFS_RELOAD_FILE ) ) then
    file.remove ( LFS_RELOAD_FILE );
    file.remove ( "_" .. LFS_TS_FILE );
    print ( "[INIT] restart after lfs reload" );
    node.restart ();
    return;
end

if ( lfsts ) then
    f = file.open ( LFS_TS_FILE, "r" );
    if ( f ) then
        expectedLfsts = tonumber ( f:read () );
    else
        f = file.open ( LFS_TS_FILE, "w" );
        f:write ( lfsts );
        expectedLfsts = lfsts;
    end
    f:close ();
end

print ( "[INIT] lfsts=" .. tostring ( lfsts ) .. "< expected=" .. tostring ( expectedLfsts ) .. "<" );

if ( not ( lfsts and expectedLfsts and lfsts == expectedLfsts ) ) then
    if ( file.exists ( LFS_FILENAME ) ) then
        print ( "[INIT] reloading flash from " .. LFS_FILENAME );
        f = file.open ( LFS_RELOAD_FILE, "w" );
        if ( f ) then
            f:close ();
        end
        file.rename ( LFS_TS_FILE, "_" .. LFS_TS_FILE );
        local msg = node.LFS.reload ( LFS_FILENAME );
        -- after reload a reboot occurs
        print ( "[INIT] image not reloaded: " .. msg .." --> exiting" );
        -- in case of error
        file.rename ( "_" .. LFS_TS_FILE, LFS_TS_FILE );
        file.remove ( LFS_RELOAD_FILE );
        return;
    else
        print ( "[INIT] no image found, exiting" );
        return;
    end
end

-- Start
print ( "[INIT] start from lfs with " .. DELAY/1000 .. " seconds delay" );
local init_from_lfs = node.LFS.get ( "_init" );
tmr.create ():alarm ( DELAY, tmr.ALARM_SINGLE, init_from_lfs );
