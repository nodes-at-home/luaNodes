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

-------------------------------------------------------------------------------
--  Settings

local restartConnection = true;

local dhtPin = nodeConfig.appCfg.dhtPin;
local dhtPowerPin = nodeConfig.appCfg.powerPin;

local bme280SdaPin = nodeConfig.appCfg.bme280SdaPin;
local bme280SclPin = nodeConfig.appCfg.bme280SclPin;

local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;

local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

local function getSensorData ( pin )

    print ( "[DHT] pin=" .. pin );

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
    
    return status, temperature, humidity;
    
end

local function publishValues ( client, baseTopic, temperature, humidity, pressure, dhtstatus )

    -- all Values
    if ( temperature and humidity and pressure ) then
        print ( "[APP] publish temperature t=" .. temperature );
        client:publish ( baseTopic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=" .. humidity );
                client:publish ( baseTopic .. "/value/humidity", [[{"value":]] .. humidity .. [[,"unit":"%"}]], 0, retain, -- qos, retain
                    function ( client )
                        print ( "[APP] publish pressure p=" .. pressure );
                        client:publish ( baseTopic .. "/value/pressure", [[{"value":]] .. pressure .. [[, "unit":"hPa"}]], 0, retain, -- qos, retain
                            function ( client )
                                require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                            end
                        );
                    end
                );
            end
        );
    -- only temperature and humidity
    elseif ( temperature and humidity ) then
        print ( "[APP] publish temperature t=" .. temperature );
        client:publish ( baseTopic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=" .. humidity );
                client:publish ( baseTopic .. "/value/humidity", [[{"value":]] .. humidity .. [[,"unit":"%"}]], 0, retain, -- qos, retain
                    function ( client )
                        require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                    end
                );
            end
        );
    -- only pressure and temperature
    elseif ( pressure and temperature ) then
        print ( "[APP] publish pressure p=" .. pressure );
        client:publish ( baseTopic .. "/value/pressure", [[{"value":]] .. pressure .. [[, "unit":"hPa"}]], 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish temperature t=" .. temperature );
                client:publish ( baseTopic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
                    function ( client )
                        require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                    end
                );
            end
        );
    else
        print ( "[APP] nothing published" );
        local t = temperature and temperature or "--";
        local h = humidity and humidity or "--";
        local p = pressure and pressure or "--"
        local s = dhtstatus and dhtstatus or "--"
        client:publish ( baseTopic .. "/value/error", "nothing published dht=" .. s .. " t=" .. t .." h=" .. h .." p=" .. p, 0, retain, -- qos, retain
            function ( client )
                require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
            end
        );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local temperature, humidity = 0;

    local dhtstatus;
    if ( dhtPin ) then
        dhtstatus, temperature, humidity = getSensorData ( dhtPin );
        if ( dhtstatus ~= dht.OK ) then -- first retry
            dhtstatus, temperature, humidity = getSensorData ( dhtPin );
        end
        if ( dhtstatus == dht.OK and ( temperature < -100 or temperature > 100 ) ) then
            temperature = nil;
        end
        print ( "[APP] status=" .. dhtstatus .. " t=" .. tostring ( temperature ) .. " ,h=" .. tostring ( humidity ) );
    end
    
    if ( bme280SdaPin and bme280SclPin ) then
        local speed = i2c.setup ( 0, bme280SdaPin, bme280SclPin, i2c.SLOW );
        print ( "[BMP] i2c speed=" .. speed );
        local ret = bme280.setup ();
        print ( "[BMP] ret=" .. tostring ( ret ) );
        if ( ret ) then
            bme280.startreadout ( 0, -- default delay 113ms
                function ()
                    local pressure = bme280.baro () / 1000;
                    print ( "[BMP] pressure=" .. pressure );
                    if ( dhtPin and temperature and humidity ) then
                        print ( "[BMP] t=" .. temperature .. " ,h=" .. humidity );
                        publishValues ( client, baseTopic, temperature, humidity, pressure, dhtstatus );
                    else
                        temperature = bme280.temp () / 100;
                        print ( "[BMP] temperature=" .. temperature );
                        publishValues ( client, baseTopic, temperature, nil, pressure, dhtstatus );
                    end
                end
            );
        end
    else
        publishValues ( client, baseTopic, temperature, humidity, nil, dhtstatus );
    end
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
    print ( "[APP] closing connections and restart" );
    restartConnection = false;
    client:close ();
    wifi.sta.disconnect ();
    node.restart ();
    
end

function M.offline ( client )

    print ( "[APP] offline" );

    return restartConnection; 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( dhtPowerPin ) then
    gpio.mode ( dhtPowerPin, gpio.OUTPUT );
    gpio.write ( dhtPowerPin, gpio.HIGH );
end

return M;

-------------------------------------------------------------------------------