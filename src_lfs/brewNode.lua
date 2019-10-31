--------------------------------------------------------------------
--
-- nodes@home/luaNodes/brewNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.09.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local numSensors = nodeConfig.appCfg.numSensors;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
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

local function publishValues ( client, topic, temperatures )

    print ( "[APP] publish: count=" .. #temperatures );
    
    local payload = '{';
    
    for i = 1, #temperatures do
        payload = ('%s"temperature%d":%.1f,'):format ( payload, i, temperatures [i] ); 
    end
    
    payload = payload .. '"unit":"°C"}';
    
    print ( "[APP] payload=" .. payload );
    
    client:publish ( topic .. "/value/temperature", payload, NO_RETAIN, retain,
        function ( client )
        end
    );

end

local function readAndPublish ( client, topic )

    if ( dsPin ) then
    
        local temps = {};

        ds18b20:read_temp (
            function ( sensorValues )
                --printSensors ();
                local i = 0;
                for address, temperature in pairs ( sensorValues ) do
                    i = i + 1;
                    local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    local parasitic = address:byte ( 9 ) == 1 and "(parasite)" or "-";
                    print ( "[APP] index=" .. i .. " address=" .. addr .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                    temps [#temps + 1] = temperature;
                    if ( i == numSensors ) then
                        publishValues ( client, topic, temps );
                    end
                end
      
            end,
            dsPin,
            ds18b20.C,          -- °C
            nil,                -- no search
            "save"
        );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    readAndPublish ( client, topic );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
    readAndPublish ( client, topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------