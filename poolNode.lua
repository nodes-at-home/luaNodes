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

require  ( "util" );

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

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
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, nodeConfig.retain, -- qos, retain
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

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local dsPin = nodeConfig.appCfg.dsPin;

    local t = require ( "ds18b20" );
    
--    t:readTemp ( readout, dsPin );
    t:readTemp ( 
        function ( sensors )
            for addr, temperature in pairs ( sensors ) do
                print ( string.format ( "[APP] Sensor %s: %s °C", encoder.toHex ( addr ), temperature ) ); -- readable address with base64 encoding is preferred when encoder module is available
                publishValues ( client, baseTopic, temperature );
                break; -- only first value is published
            end
        end,
        dsPin 
    );
    if t.sens then
      print ( "[APP] Total number of DS18B20 sensors: " .. table.getn ( t.sens ) );
      for i, s in ipairs ( t.sens ) do
        -- print(string.format("  sensor #%d address: %s%s", i, s.addr, s.parasite == 1 and " (parasite)" or ""))
        print ( string.format ( "[APP] sensor #%d address: %s%s", i, encoder.toHex ( s.addr ), s.parasite == 1 and " (parasite)" or "" ) ); -- readable address with base64 encoding is preferred when encoder module is available
      end
    end

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