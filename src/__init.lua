--------------------------------------------------------------------
--
-- nodes@home/luaNodes/init
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.09.2016

-- dofile ( "startup.lua" );

-- boot reason https://nodemcu.readthedocs.io/en/master/en/modules/node/#nodebootreason
-- 0, power-on
-- 1, hardware watchdog reset
-- 2, exception reset
-- 3, software watchdog reset
-- 4, software restart
-- 5, wake from deep sleep
-- 6, external reset
local rawcode, bootreason = node.bootreason ();
print ( "[INIT] boot: rawcode=" .. rawcode .. " ,reason=" .. bootreason );

local NO_BOOT_FILE = "no_boot";

if ( bootreason == 1 or bootreason == 2 or bootreason == 3 ) then
    if ( file.exists ( NO_BOOT_FILE ) ) then
        print ( "[INIT] booting after error; NO STARTUP" );
        return;
    else
        file.open ( NO_BOOT_FILE, "w" );
        file.close ();
    end
else
    if ( file.exists ( NO_BOOT_FILE ) ) then 
        file.remove ( NO_BOOT_FILE ); 
    end
end

require ( "startup" ).init ();
unrequire ( "startup" );
collectgarbage ();

