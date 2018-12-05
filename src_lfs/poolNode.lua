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

local dsPin = nodeConfig.appCfg.dsPin or 3;
local restartConnection = true;

local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;

local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic)

    print ( "[APP] start" );
    
    ds18b20.setup ( dsPin );

end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    ds18b20.read (
        function ( index, address, resolution, temperature, tempinteger, parasitic )
            if ( index == 1 ) then -- only first sensor
                local addr = string.format ( "%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X", string.match ( address, "(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)" ) );
                print ( "[APP] index=" .. index .. " address=" .. addr .. " resolution=" .. resolution .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                print ( "[APP] publish temperature t=" .. temperature );
                client:publish ( topic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
                    function ( client )
                        require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                    end
                );
            end
        end,
        {}
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