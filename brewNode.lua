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

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local dhtDataPin = nodeConfig.appCfg.dhtDataPin;
local dhtPowerPin = nodeConfig.appCfg.dhtPowerPin;

local ds18b20 = require ( "ds18b20" );

local retain = 0;
-- local retain = nodeConfig.retain;
    
----------------------------------------------------------------------------------------
-- private

local function getSensorData ( pin )

    print ( "[DHT] pin=" .. pin );

--    local dht = require ( "dht" );
    
    local status, temperature, humidity, temp_decimial, humi_decimial = dht.read ( pin );
    
    if( status == dht.OK ) then

        print ( "[DHT] Temperature: " .. temperature .. " C" );
        print ( "[DHT] Humidity: " .. humidity .. "%" );
        
    elseif( status == dht.ERROR_CHECKSUM ) then
    
        print ( "[DHT] Checksum error" );
        temperature = nil;
        humidity = nil;
        
    elseif( status == dht.ERROR_TIMEOUT ) then
    
        print ( "[DHT] Time out" );
        temperature = nil;
        humidity = nil;
        
    end
    
    local result = status == dht.OK; 
    
    return result, temperature, humidity;
    
end

local function publishValues ( client, topic, brewTemperature, outerTemperature )

    print ( string.format ( "[APP] publish temperatures brew= %f outer=%f", brewTemperature, outerTemperature ) );
    
    local payload = string.format ( '{"brew":%f,"outer":%f,"unit":"°C"}', brewTemperature, outerTemperature );
    client:publish ( topic .. "/value/temperature", payload, 0, retain, -- qos, retain
        function ( client )
        end
    );

end

local function readAndPublish ( client, topic )

    if ( dsPin and dhtDataPin ) then

        ds18b20:readTemp ( 
            function ( sensors )
                for addr, brewTemperature in pairs ( sensors ) do
                    print ( string.format ( "[DS18B20] Sensor %s: %s °C", encoder.toHex ( addr ), brewTemperature ) ); -- readable address with base64 encoding is preferred when encoder module is available
                    local success, outerTemperature = getSensorData ( dhtDataPin );
                    if ( success ) then
                        print ( "[DHT] t=" .. outerTemperature );
                        publishValues ( client, topic, brewTemperature, outerTemperature );
                    else
                        print ( "[DHT] no values" );
                        publishValues ( client, topic, brewTemperature, 0 );
                    end
                    break; -- only first value of ds18b20 is published
                end
            end,
            dsPin 
        );
    
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
    gpio.mode ( dhtPowerPin, gpio.OUTPUT );
    gpio.write ( dhtPowerPin, gpio.HIGH );
    
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