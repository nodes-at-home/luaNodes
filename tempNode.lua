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

local function publishValues ( client, baseTopic, temperature, humidity, pressure )

    -- all Values
    if ( temperature and humidity and pressure ) then
        print ( "[APP] publish temperature t=" .. temperature );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, nodeConfig.retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=" .. humidity );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( humidity, "%" ), 0, nodeConfig.retain, -- qos, retain
                    function ( client )
                        print ( "[APP] publish pressure p=" .. pressure );
                        client:publish ( baseTopic .. "/value/pressure", util.createJsonValueMessage ( pressure, "hPa" ), 0, nodeConfig.retain, -- qos, retain
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
        print ( "[APP] publish temperature t=" .. temperature );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, nodeConfig.retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=" .. humidity );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( humidity, "%" ), 0, nodeConfig.retain, -- qos, retain
                    function ( client )
                        goDeepSleep ( client );
                    end
                );
            end
        );
    -- only pressure and temperature
    elseif ( pressure and temperature ) then
        print ( "[APP] publish pressure p=" .. pressure );
        client:publish ( baseTopic .. "/value/pressure", util.createJsonValueMessage ( pressure, "hPa" ), 0, nodeConfig.retain, -- qos, retain
            function ( client )
                print ( "[APP] publish temperature t=" .. temperature );
                client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( temperature, "C" ), 0, nodeConfig.retain, -- qos, retain
                    function ( client )
                        goDeepSleep ( client );
                    end
                );
            end
        );
    else
        print ( "[APP] nothing published" );
        local t = temperature and temperature or "--";
        local h = humidity and humidity or "--";
        local p = pressure and pressure or "--"
        client:publish ( baseTopic .. "/value/error", "nothing published t=" .. t .." h=" .. h .." p=" .. p, 0, nodeConfig.retain, -- qos, retain
            function ( client )
                goDeepSleep ( client );
            end
        );
    end

end

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local dhtPin = nodeConfig.appCfg.dhtPin;
    local bme280SdaPin = nodeConfig.appCfg.bme280SdaPin;
    local bme280SclPin = nodeConfig.appCfg.bme280SclPin;

    local temperature, humidity = 0;

    if ( dhtPin ) then
        local success;
        success, temperature, humidity = util.getSensorData ( dhtPin );
        if ( not success ) then -- first retry
            success, temperature, humidity = util.getSensorData ( dhtPin );
        end
        if ( success ) then
            print ( "[APP] t=" .. temperature .. " ,h=" .. humidity );
        else
            print ( "[APP] no values" );
        end
    end
    
    if ( bme280SdaPin and bme280SclPin ) then
        local ret = bme280.init ( bme280SdaPin, bme280SclPin, nil, nil, nil, 0 ); -- initialize to sleep mode: temp_oss, press_oss, humi_oss, power_mode, sleep_mode
        print ( "[BMP] ret=" .. ret );
        if ( not ret ) then
            print ( "[BMP] retry")
            ret = bme280.init ( bme280SdaPin, bme280SclPin, nil, nil, nil, 0 );
            print ( "[BMP] ret=" .. ret );
        end
        if ( ret ) then
            bme280.startreadout ( 0, -- default delay 113ms
                function ()
                    local pressure = bme280.baro () / 1000;
                    print ( "[BMP] pressure=" .. pressure );
                    if ( dhtPin ) then
                        print ( "[BMP] t=" .. temperature .. " ,h=" .. humidity );
                        publishValues ( client, baseTopic, temperature, humidity, pressure );
                    else
                        temperature = bme280.temp () / 100;
                        print ( "[BMP] temperature=" .. temperature );
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