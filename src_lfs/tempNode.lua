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

local logger = require ( "syslog" ).logger ( moduleName );

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

    logger.info ( "getSensorData: pin=" .. pin );

    local status, temperature, humidity, temp_decimial, humi_decimial = dht.read ( pin );

    if( status == dht.OK ) then

        logger.debug ( "getSensorData: Temperature: " .. temperature .. " C" );
        logger.debug ( "getSensorData: Humidity: " .. humidity .. "%" );

    elseif( status == dht.ERROR_CHECKSUM ) then

        logger.debug ( "getSensorData: Checksum error" );
        temperature = nil;
        humidity = nil;

    elseif( status == dht.ERROR_TIMEOUT ) then

        logger.notice ( "getSensorData: Time out" );
        temperature = nil;
        humidity = nil;

    end

    return status, temperature, humidity;

end

local function publishValues ( client, topic, temperature, humidity, pressure, dhtstatus )

    logger.info ( "publishValues: topic=" .. topic .. " temperature=" .. temperature .. " humidity=" .. humidity .. " pressure=" .. pressure .. " dhtstatus=" .. dhtstatus );

    -- all Values
    if ( temperature and humidity and pressure ) then
        logger.debug ( "publishValues: temperature=" .. temperature );
        client:publish ( topic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
            function ( client )
                logger.debug ( "publishValues: humidity=" .. humidity );
                client:publish ( topic .. "/value/humidity", [[{"value":]] .. humidity .. [[,"unit":"%"}]], 0, retain, -- qos, retain
                    function ( client )
                        logger.debug ( "publishValues: pressure=" .. pressure );
                        client:publish ( topic .. "/value/pressure", [[{"value":]] .. pressure .. [[, "unit":"hPa"}]], 0, retain, -- qos, retain
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
        logger.debug ( "publishValues: temperature=" .. temperature );
        client:publish ( topic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
            function ( client )
                logger.debug ( "publishValues: humidity=" .. humidity );
                client:publish ( topic .. "/value/humidity", [[{"value":]] .. humidity .. [[,"unit":"%"}]], 0, retain, -- qos, retain
                    function ( client )
                        require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                    end
                );
            end
        );
    -- only pressure and temperature
    elseif ( pressure and temperature ) then
        logger.debug ( "publishValues: pressure=" .. pressure );
        client:publish ( topic .. "/value/pressure", [[{"value":]] .. pressure .. [[, "unit":"hPa"}]], 0, retain, -- qos, retain
            function ( client )
                logger.debug ( "publishValues: temperature=" .. temperature );
                client:publish ( topic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, retain, -- qos, retain
                    function ( client )
                        require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                    end
                );
            end
        );
    else
        logger.debug ( "publishValues: nothing published" );
        local t = temperature and temperature or "--";
        local h = humidity and humidity or "--";
        local p = pressure and pressure or "--"
        local s = dhtstatus and dhtstatus or "--"
        client:publish ( topic .. "/value/error", "nothing published dht=" .. s .. " t=" .. t .." h=" .. h .." p=" .. p, 0, retain, -- qos, retain
            function ( client )
                require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
            end
        );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

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
        logger.debug ( "status=" .. dhtstatus .. " t=" .. tostring ( temperature ) .. " ,h=" .. tostring ( humidity ) );
    end

    if ( bme280SdaPin and bme280SclPin ) then
        local speed = i2c.setup ( 0, bme280SdaPin, bme280SclPin, i2c.SLOW );
        logger.debug ( "i2c speed=" .. speed );
        local ret = bme280.setup ();
        logger.debug ( "connect: ret=" .. tostring ( ret ) );
        if ( ret ) then
            bme280.startreadout ( 0, -- default delay 113ms
                function ()
                    local pressure = bme280.baro () / 1000;
                    logger.debug ( "connect: pressure=" .. pressure );
                    if ( dhtPin and temperature and humidity ) then
                        logger.debug ( "connect: t=" .. temperature .. " ,h=" .. humidity );
                        publishValues ( client, topic, temperature, humidity, pressure, dhtstatus );
                    else
                        temperature = bme280.temp () / 100;
                        logger.debug ( "connect: temperature=" .. temperature );
                        publishValues ( client, topic, temperature, nil, pressure, dhtstatus );
                    end
                end
            );
        end
    else
        publishValues ( client, topic, temperature, humidity, nil, dhtstatus );
    end

end

function M.periodic ( client, topic )

    logger.info ( "periodic: topic=" .. topic );

    logger.warning ( "priodic: closing connections and restart" );
    restartConnection = false;
    client:close ();
    wifi.sta.disconnect ();
    node.restart ();

end

function M.offline ( client )

    logger.info ( "offline:" );

    return restartConnection;

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

end

-------------------------------------------------------------------------------
-- main

if ( dhtPowerPin ) then
    gpio.mode ( dhtPowerPin, gpio.OUTPUT );
    gpio.write ( dhtPowerPin, gpio.HIGH );
end

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------