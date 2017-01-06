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

local retain = espConfig.node.retain;

local deepSleepTimer = espConfig.node.timer.deepSleep;
local deepSleepDelay = espConfig.node.timer.deepSleepDelay;

local timeBetweenSensorReadings = espConfig.node.appCfg.timeBetweenSensorReadings;

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

local function goDeepSleep ( client, baseTopic )

    if ( not useOfflineCallback ) then
        print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
        -- wait a minute with closing connection
        tmr.alarm ( deepSleepTimer, deepSleepDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
            function () 
                -- publishing OFF is not harmful
                print ( "[APP] publish button press OFF" );
                client:publish ( baseTopic .. "/value/state", "OFF", 0, 0, -- qos, NO retain!!!
                    function ( client )
                        print ( "[APP] closing connection" );
                        client:close ();
                        print ( "[APP] Going to deep sleep for ".. deepSleepDelay/1000 .." seconds" );
                        node.dsleep ( deepSleepDelay * 1000 ); -- us
                        -- node.dsleep ( (90 - 60) * 1000 * 1000 );
                    end
                );
            end
        );
    else
        print ( "[APP] closing connection using offline handler" );
        -- TODO falls das wieder benutzt wird, dann hier noch publish etc. einbauen
        client:close ();
    end

end

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local rawcode, bootreason = node.bootreason ();
    if ( bootreason == 5 ) then -- 5 = wake from deep sleep
        print ( "[APP] publish button press ON" );
        client:publish ( baseTopic .. "/value/state", "ON", 0, 0, -- qos, NO retain!!!
            function ( client )
                goDeepSleep ( client, baseTopic );
            end
        );
    else
        goDeepSleep( client, baseTopic );
    end

end

local function offline ( client )

    print ( "[APP] offline" );

    print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
    node.dsleep ( deepSleepDelay * 1000 ); -- us, we are go sleeping "foreever"
    
    return false; -- dont restart mqtt connection
    
end

local function message ( client, topic, payload )

    print ( "[APP] message: topic=", topic, " payload=", payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded", moduleName )

if ( espConfig.node.appCfg.useOfflineCallback ) then
    M.offline = offline;
end
-- M.message = message;

return M;

-------------------------------------------------------------------------------