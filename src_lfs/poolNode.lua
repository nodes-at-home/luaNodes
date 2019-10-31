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

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin or 3;
local restartConnection = true;

local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;

local retain = nodeConfig.mqtt.retain;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private

local function printSensors ()

    if ( ds18b20.sens ) then
        print  ( "[APP] number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            print ( string.format ( "[APP] sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic)

    print ( "[APP] start" );

end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    ds18b20:read_temp (
        function ( sensorValues )
            --printSensors ();
            local i = 0;
            for address, temperature in pairs ( sensorValues ) do
                i = i + 1;
                if ( i == 1 ) then -- only first sensor
                    --local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    --print ( ("[APP] Sensor %s -> %s°C %s"):format ( addr, temperature, address:byte ( 9 ) == 1 and "(parasite)" or "-" ) );
                    print ( "[APP] publish temperature t=" .. temperature );
                    local payload = ('{"value":%f,"unit":"°C"}'):format ( temperature );
                    client:publish ( topic .. "/value/temperature", payload, qos, retain,
                        function ( client )
                            require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                        end
                    );
                end
            end
  
        end,
        dsPin,
        ds18b20.C,          -- °C
        nil,                -- no search
        "save"
    );
    
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

return M;

-------------------------------------------------------------------------------