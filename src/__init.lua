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

local node, file, tmr = node, file, tmr;

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

if ( lfsts ) then
    if ( file.open ( LFS_TS_FILE ) ) then
        expectedLfsts = tonumber ( file.read () );
    else
        file.open ( LFS_TS_FILE, "w" );
        file.write ( lfsts );
        expectedLfsts = lfsts;
    end
    file.close ();
end

print ( "[INIT] lfsts=" .. tostring ( lfsts ) .. "< expected=" .. tostring ( expectedLfsts ) .. "<" );

if ( not ( lfsts and expectedLfsts and lfsts == expectedLfsts ) ) then
    if ( file.exists ( LFS_FILENAME ) ) then
        print ( "[INIT] reloading flash from " .. LFS_FILENAME );
        if ( file.open ( LFS_RELOAD_FILE, "w" ) ) then
            file.close ();
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
local id = node.chipid ();
if ( id == 15892791 or id == 16061971 or id == 6130344 ) then
    DELAY = 2;
end
print ( "[INIT] start from lfs with " .. DELAY/1000 .. " seconds delay" );
local init_from_lfs = node.LFS.get ( "_init" );
tmr.create ():alarm ( DELAY, tmr.ALARM_SINGLE, init_from_lfs );

