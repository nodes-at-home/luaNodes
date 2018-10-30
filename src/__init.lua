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

-- TODO testen ob lfs geladen ist (z.B. auf "_lfs", wenn nicht laden und dann erst starten
--      nicht immer laden

local delay = 2000;
local lfs_filename = "lfs.img";

local init_from_lfs = node.flashindex ( "_init" );
if ( not init_from_lfs ) then
    if ( file.exists ( lfs_filename ) ) then
        print ( "[INIT] reloading flash from " .. lfs_filename );
        node.flashreload ( lfs_filename );
        -- after reload a reboot occurs
        print ( "[INIT] image not reloaded, exiting" );
        return;
    else
        print ( "[INIT] no image found, exiting" );
        return;
    end
end

-- Start
print ( "[INIT] start from lfs with " .. delay/1000 .. " seconds delay" );
tmr.create ():alarm ( 2000, tmr.ALARM_SINGLE, function () pcall ( init_from_lfs ) end ); 

