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

if ( bootreason == 1 or bootreason == 2 or bootreason == 3 ) then
    print ( "[INIT] booting after error; NO STARTUP" );
    return;
end

require ( "startup" );
