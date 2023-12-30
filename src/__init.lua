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

local node, file, tmr, io = node, file, tmr, io;

-------------------------------------------------------------------------------
--  Settings

local DELAY = 2000;
local LFS_FILENAME = "lfs.img";
local LFS_TS_FILE = "lfs.img.ts";
local LFS_RELOAD_FILE = "lfs_reload";

----------------------------------------------------------------------------------------
-- private

local lfsts = node.LFS.time;
local expectedLfsts;

--------------------------------------------------------------------
-- public

local f;

-- restart after lfs reload
f = io.open ( LFS_RELOAD_FILE );
if ( f ) then
    file.remove ( LFS_RELOAD_FILE );
    file.remove ( "_" .. LFS_TS_FILE );
    print ( "[INIT] restart after lfs reload" );
    node.restart ();
    return;
end

-- determine lfs timestamps
if ( lfsts ) then
    f = io.open ( LFS_TS_FILE );
    if ( f ) then
        expectedLfsts = tonumber ( f:read () );
    else
        f = io.open ( LFS_TS_FILE, "w" );
        f:write ( lfsts );
        expectedLfsts = lfsts;
    end
    f:close ();
end

print ( "[INIT] lfsts=" .. tostring ( lfsts ) .. "< expected=" .. tostring ( expectedLfsts ) .. "<" );

-- check for lfs reload
if ( not ( lfsts and expectedLfsts and lfsts == expectedLfsts ) ) then
    f = io.open ( LFS_FILENAME, "r" );
    if ( f ) then
        f:close ();
        print ( "[INIT] reloading flash from " .. LFS_FILENAME );
        f = io.open ( LFS_RELOAD_FILE, "w" );
        if ( f ) then
            f:close ();
        end
        --file.remove ( LFS_TS_FILE );
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
--local id = node.chipid ();
--if ( id == 15892791 or id == 16061971 or id == 6130344 ) then
--    DELAY = 2;
--end
print ( "[INIT] start from lfs with " .. DELAY/1000 .. " seconds delay" );
local init_from_lfs = node.LFS.get ( "_init" );
tmr.create ():alarm ( DELAY, tmr.ALARM_SINGLE, init_from_lfs );

