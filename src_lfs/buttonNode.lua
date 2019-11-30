--------------------------------------------------------------------
--
-- nodes@home/luaNodes/buttonNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 27.12.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local offDelay = nodeConfig.timer.offDelay or 3000;
local deepSleepDelay = nodeConfig.timer.deepSleepDelay;

local retain = 0; -- NO retain!!!

----------------------------------------------------------------------------------------
-- private

local restartConnection = true;

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local rawcode, bootreason = node.bootreason ();
    if ( bootreason == 5 ) then -- 5 = wake from deep sleep
        print ( "[APP] publish button press ON" );
        client:publish ( baseTopic .. "/value/state", "ON", 0, retain, -- qos, NO retain!!!
            function ( client )
                tmr.create ():alarm ( offDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                    function () 
                        -- publishing OFF is not harmful
                        print ( "[APP] publish button press OFF" );
                        client:publish ( baseTopic .. "/value/state", "OFF", 0, retain, -- qos, NO retain!!!
                            function ( client )
                                require ( "deepsleep").go ( client, deepSleepDelay, 0 ); -- sleep forever
                            end
                        );
                    end
                );
            end
        );
    else
        require ( "deepsleep").go ( client, deepSleepDelay, 0 ); -- sleep forever
    end

end

function M.offline ( client )

    print ( "[APP] offline (local)" );

    return restartConnection; 

end

local function message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------