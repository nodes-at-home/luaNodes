--------------------------------------------------------------------
--
-- nodes@home/luaNodes/tempNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require  ( "util" );

-------------------------------------------------------------------------------
--  Settings

local retain = espConfig.node.retain;
local useOfflineCallback = espConfig.node.appCfg.useOfflineCallback;

local dhtPin = espConfig.node.appCfg.dhtPin;

local deepSleepTimer = espConfig.node.timer.deepSleep;
local deepSleepDelay = espConfig.node.timer.deepSleepDelay;

local timeBetweenSensorReadings = espConfig.node.appCfg.timeBetweenSensorReadings;

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

local function goDeepSleep ( client )

    if ( not useOfflineCallback ) then
        print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
        -- wait a minute with closing connection
        tmr.alarm ( deepSleepTimer, deepSleepDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
            function () 
                print ( "[APP] closing connection" );
                client:close ();
                print ( "[APP] Going to deep sleep for ".. timeBetweenSensorReadings/1000 .." seconds" );
                node.dsleep ( (timeBetweenSensorReadings - deepSleepDelay) * 1000 ); -- us
                -- node.dsleep ( (90 - 60) * 1000 * 1000 );
            end
        );
    else
        print ( "[APP] closing connection using offline handler" );
        client:close ();
    end

end

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    -- TODO detect errror in getSensorData and retry reading if reasonable
    
    local success, t, h = util.getSensorData ( dhtPin );
    
    if ( not success ) then -- first retry
        success, t, h = util.getSensorData ( dhtPin );
    end
    
    if ( success ) then
        print ( "[APP] publish temperature t=", t );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( t, "C" ), 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=", h );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( h, "%" ), 0, retain, -- qos, retain
                    function ( client )
                        goDeepSleep ( client );
                    end
                );
            end
        );
    else
        goDeepSleep ( client );
    end

end

local function offline ( client )

    print ( "[APP] offline" );

    print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
    node.dsleep ( timeBetweenSensorReadings * 1000 ); -- us
    
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