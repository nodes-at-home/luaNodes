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

-------------------------------------------------------------------------------
--  Settings

local DELAY = 2000;
local LFS_FILENAME = "lfs.img";
local LFS_TS_FILENAME = "lfs.img.ts";
local LFS_RELOAD_FILE = "lfs_reload";
local BOOTREASON_DEEPSLEEP_1 = "boot1_after_ds";
local BOOTREASON_DEEPSLEEP_2 = "boot2_after_ds";

----------------------------------------------------------------------------------------
-- private

local lfsts = node.flashindex ();
local expectedLfsts;

--------------------------------------------------------------------
-- public

-- we coming fron deepsleep - problems with dns
local rawcode, bootreason = node.bootreason ();
if ( bootreason == 5 ) then -- 5 = wake from deep sleep
    if ( file.open ( BOOTREASON_DEEPSLEEP_1, "w" ) ) then
        file.close ();
    end
    print ( "[INIT] REBOOT after deepsleep" );
    node.restart ();
    return;
end
if ( file.exists ( BOOTREASON_DEEPSLEEP_2 ) ) then
    file.remove ( BOOTREASON_DEEPSLEEP_2 );
end
if ( file.exists ( BOOTREASON_DEEPSLEEP_1 ) ) then
    file.remove ( BOOTREASON_DEEPSLEEP_1 );
    if ( file.open ( BOOTREASON_DEEPSLEEP_2, "w" ) ) then
        file.close ();
    end
end

if ( lfsts ) then
    if ( file.open ( LFS_TS_FILENAME ) ) then
        expectedLfsts = tonumber ( file.read () );
    else
        file.open ( LFS_TS_FILENAME, "w" );
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
        file.remove ( LFS_TS_FILENAME );
        node.flashreload ( LFS_FILENAME );
        -- after reload a reboot occurs
        print ( "[INIT] image not reloaded, exiting" );
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
local init_from_lfs = node.flashindex ( "_init" );
tmr.create ():alarm ( DELAY, tmr.ALARM_SINGLE, init_from_lfs ); 

