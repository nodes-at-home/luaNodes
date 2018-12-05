--------------------------------------------------------------------
--
-- nodes@home/luaNodes/touchNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 14.09.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local retain = 0; -- NO retain!!!

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
    if ( type ( nodeConfig.appCfg.sensors ) == "table" ) then
        for _, touch in ipairs ( nodeConfig.appCfg.sensors ) do
            gpio.mode ( touch.pin, gpio.INT );
            gpio.trig ( touch.pin, "both",
                function ( level, when, count )
                    print ( "[APP] device=" .. touch.device .. " level=" .. level .. " when=" .. when .. " count=" .. count );
                    local t = topic .. "/" .. touch.device .. "/value/state";
                    local v = "ON";
                    if ( level == 0 ) then v = "OFF" end
                    print ( "[APP] publish button press " .. v .. " topic=" .. t );
                    client:publish ( t, v, 0, retain, -- qos, NO retain!!!
                        function ( client )
                        end
                    );
                end
            );
        end
    end
    
end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

--        print ( "[APP] publish button press ON" );
--        client:publish ( baseTopic .. "/value/state", "ON", 0, retain, -- qos, NO retain!!!
--            function ( client )
--                tmr.create ():alarm ( offDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
--                    function () 
--                        -- publishing OFF is not harmful
--                        print ( "[APP] publish button press OFF" );
--                        client:publish ( baseTopic .. "/value/state", "OFF", 0, retain, -- qos, NO retain!!!
--                            function ( client )
--                                require ( "deepsleep").go ( client, deepSleepDelay, 0 ); -- sleep forever
--                            end
--                        );
--                    end
--                );
--            end
--        );

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------