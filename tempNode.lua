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
require ( "bme280" );

-------------------------------------------------------------------------------
--  Settings

local retain = espConfig.node.retain;
local useOfflineCallback = espConfig.node.appCfg.useOfflineCallback;

local dhtPin = espConfig.node.appCfg.dhtPin;

local bme280SdaPin = espConfig.node.appCfg.bme280SdaPin;
local bme280SclPin = espConfig.node.appCfg.bme280SclPin;

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

local function publishValues ( client, baseTopic, temperature, humidity, pressure )

    -- all Values
    if ( temperature and humidity and pressure ) then
        print ( "[APP] publish temperature t=", temperature );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=", humidity );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( humidity, "%" ), 0, retain, -- qos, retain
                    function ( client )
                        print ( "[APP] publish pressure p=", pressure );
                        client:publish ( baseTopic .. "/value/pressure", util.createJsonValueMessage ( pressure, "hPa" ), 0, retain, -- qos, retain
                            function ( client )
                                goDeepSleep ( client );
                            end
                        );
                    end
                );
            end
        );
    -- only temperature and humidity
    elseif ( temperature and humidity ) then
        print ( "[APP] publish temperature t=", temperature );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=", humidity );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( humidity, "%" ), 0, retain, -- qos, retain
                    function ( client )
                        goDeepSleep ( client );
                    end
                );
            end
        );
    -- only pressure and temperature
    elseif ( pressure and temperature ) then
        print ( "[APP] publish pressure p=", pressure );
        client:publish ( baseTopic .. "/value/pressure", util.createJsonValueMessage ( pressure, "hPa" ), 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish temperature t=", temperature );
                client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, retain, -- qos, retain
                    function ( client )
                        goDeepSleep ( client );
                    end
                );
            end
        );
    else
        print ( "[APP] nothing published" );
        goDeepSleep ( client );
    end

end

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local temperature, humidity = 0;

    if ( dhtPin ) then
        local success;
        success, temperature, humidity = util.getSensorData ( dhtPin );
        if ( not success ) then -- first retry
            success, temperature, humidity = util.getSensorData ( dhtPin );
        end
        print ( "[APP] t=", temperature, "h=", humidity );
    end
    
    if ( bme280SdaPin and bme280SclPin ) then
        local ret = bme280.init ( bme280SdaPin, bme280SclPin, nil, nil, nil, 0 ); -- initialize to sleep mode: temp_oss, press_oss, humi_oss, power_mode, sleep_mode
        print ( "[BMP] ret=", ret );
        if ( not ret ) then
            print ( "[BMP] retry")
            ret = bme280.init ( bme280SdaPin, bme280SclPin, nil, nil, nil, 0 );
            print ( "[BMP] ret=", ret );
        end
        if ( ret ) then
            bme280.startreadout ( 0, -- default delay 113ms
                function ()
                    local pressure = bme280.baro () / 1000;
                    print ( "[BMP] pressure=", pressure );
                    if ( dhtPin ) then
                        print ( "[BMP] t=", temperature, "h=", humidity );
                        publishValues ( client, baseTopic, temperature, humidity, pressure );
                    else
                        temperature = bme280.temp () / 100;
                        print ( "[BMP] temperature=", temperature );
                        publishValues ( client, baseTopic, temperature, nil, pressure );
                    end
                end
            );
        end
    else
        publishValues ( client, baseTopic, temperature, humidity, nil );
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