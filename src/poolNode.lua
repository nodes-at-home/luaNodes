--------------------------------------------------------------------
--
-- nodes@home/luaNodes/poolNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 11.06.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

local dsPin = nodeConfig.appCfg.dsPin or 3;
local restartConnection = true;

--------------------------------------------------------------------
-- public
-- mqtt callbacks

local function goDeepSleep ( client )

    if ( not nodeConfig.appCfg.useOfflineCallback ) then
        restartConnection = false;
        local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
        print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
        -- wait a minute with closing connection
        tmr.alarm ( nodeConfig.timer.deepSleep, deepSleepDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
            function () 
                print ( "[APP] closing connection" );
                client:close ();
                local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;
                print ( "[APP] Going to deep sleep for ".. timeBetweenSensorReadings/1000 .." seconds" );
                node.dsleep ( (timeBetweenSensorReadings - deepSleepDelay) * 1000, 1 ); -- us, RF_CAL after deep sleep
            end
        );
    else
        print ( "[APP] closing connection using offline handler" );
        client:close ();
    end

end

local function publishValues ( client, baseTopic, temperature )

    if ( temperature ) then
        print ( "[APP] publish temperature t=" .. temperature );
        client:publish ( baseTopic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, nodeConfig.retain, -- qos, retain
            function ( client )
                goDeepSleep ( client );
            end
        );
    else
        print ( "[APP] nothing published" );
        local t = temperature and temperature or "--";
        client:publish ( baseTopic .. "/value/error", "nothing published t=" .. t, 0, nodeConfig.retain, -- qos, retain
            function ( client )
                goDeepSleep ( client );
            end
        );
    end

end

function M.start ( client, topic)

    print ( "[APP] start" );
    
    ds18b20.setup ( dsPin );

end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    ds18b20.read (
        function ( index, address, resolution, temperature, tempinteger, parasitic )
            -- only first sensor
            if ( index == 1 ) then
                local addr = string.format ( "%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X", string.match ( address, "(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)" ) );
                print ( "[APP] index=" .. index .. " address=" .. addr .. " resolution=" .. resolution .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                publishValues ( client, topic, temperature );
            end
        end,
        {}
    );
    
end

local function offline ( client )

    print ( "[APP] offline" );

    local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;
    print ( "[APP] Going to deep sleep for ".. timeBetweenSensorReadings/1000 .." seconds" );
    node.dsleep ( timeBetweenSensorReadings * 1000, 1 ); -- us, RF_CAL after deep sleep
    
    return restartConnection; -- restart mqtt connection
    
end

function M.offline ( client )

    print ( "[APP] offline (local)" );

    return restartConnection; 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( nodeConfig.appCfg.useOfflineCallback ) then
    M.offline = offline;
end

return M;

-------------------------------------------------------------------------------