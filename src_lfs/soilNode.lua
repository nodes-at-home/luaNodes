--------------------------------------------------------------------
--
-- nodes@home/luaNodes/soilNodeNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.03.2021
--
-- https://makersportal.com/blog/2020/5/26/capacitive-soil-moisture-calibration-with-arduino

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local ds18b20 = require ( "ds18b20" );

local ads1115, i2c, tmr = ads1115, i2c, tmr;

-------------------------------------------------------------------------------
--  Settings

local sclPin = nodeConfig.appCfg.i2c.sclPin or 1;
local sdaPin = nodeConfig.appCfg.i2c.sdaPin or 2;
local alertPin = nodeConfig.appCfg.ads1115.alertPin or 7;
local numChannels = nodeConfig.appCfg.ads1115.numChannels or 4;

local dsPin = nodeConfig.appCfg.ds18b20.dsPin;
local numSensors = nodeConfig.appCfg.ds18b20.numSensors;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

local GRAD = string.char ( 176 );

----------------------------------------------------------------------------------------
-- private
--

local display;

local channel = 0;
--local adc;
local voltage = {};


local function printSensors ()

    if ( ds18b20.sens ) then
        print ( "[APP] printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            print ( string.format ( "[APP] printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function publishTemperatures ( client, topic, temperatures, callback )

    --print ( "[APP] publishTemperatures: count=" .. #temperatures );

    local payload = '{';

    for i = 1, #temperatures do
        payload = ('%s"temperature%d":%.1f,'):format ( payload, i, temperatures [i] );
    end

    payload = payload .. '"unit":"°C"}';

    print ( "[APP] publishTemperatures: payload=" .. payload );

    client:publish ( topic .. "/value/temperature", payload, qos, retain,
        function ( client )
            if ( callback ) then
                callback ( client, topic );
            end
        end
    );

end

local function publishVoltages ( client, topic, voltages, callback )

    --print ( "[APP] publishVoltages: count=" .. #voltages );

    local payload = '{';

    for i = 1, #voltages do
        payload = ('%s"voltage%d":%.1f,'):format ( payload, i, voltages [i] );
    end
    payload = payload .. '"unit":"mV"}';

    print ( "[APP] publishVoltages: payload=" .. payload );

    client:publish ( topic .. "/value/soil", payload, qos, retain,
        function ( client )
            if ( callback ) then
                callback ( client, topic );
            end
        end
    );

end

local function displayValues ( value, unit )

    --print ( "[APP] displayValues:" );

    display:clearBuffer ();

    --display:setFont ( u8g2.font_fur20_tf );
    display:setFont ( u8g2.font_6x10_tf );
    display:setFontPosTop ();
    value = value or {};
    for i = 1, #value do
        display:drawStr ( 1, i * 12, ('%7.1f %s'):format ( value [i] or 0.0, unit or "" ) );
    end

    display:sendBuffer ();

end

local function readAndPublish ( client, topic, callback )

    --print ( "[APP] readAndPublish:" );

    if ( dsPin ) then

        local temps = {};

        ds18b20:read_temp (
            function ( sensorValues )
                --print ( "[APP] readAndPublish: #sensorValues=" .. #sensorValues );
                --printSensors ();
                local i = 0;
                if ( #ds18b20.sens > 0 ) then
                    for address, temperature in pairs ( sensorValues ) do
                        i = i + 1;
                        local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                        local parasitic = address:byte ( 9 ) == 1 and "(parasite)" or "-";
                        --print ( "[APP] readAndPublish: index=" .. i .. " address=" .. addr .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                        temps [#temps + 1] = temperature;
                        if ( i == #ds18b20.sens ) then
                            displayValues ( temps, GRAD );
                            publishTemperatures ( client, topic, temps, callback );
                        end
                    end
                else
                    if ( callback ) then
                        callback ( client, topic );
                    end
                end
            end,
            dsPin,
            ds18b20.C,          -- °C
            nil,                -- nil means no search
            "save"
        );

    end

end

local function initAdc ( channel )

    --print ( "[APP] initAdc: channel=" .. channel );

    ads1115.reset ();
    local adc = ads1115.ads1115 ( 0, ads1115.ADDR_GND );
    adc:setting ( ads1115.GAIN_4_096V, ads1115.DR_8SPS, ads1115 ["SINGLE_" .. channel], ads1115.SINGLE_SHOT, ads1115.CONV_RDY_4 );

    return adc;

end

local function readAdc ( client, topic )

    --print ( "[APP] readAdc: channel=" .. channel );

    local adc = initAdc ( channel );

    gpio.trig ( alertPin, "down",
        function ()
            if ( adc == nil ) then
                print ( "XYZ" );
                return;
            end

            local u, _, raw = adc:read ();
            --print ( "[APP] readadc: channel=" .. channel .. " u=" .. u .." raw=" .. tohex ( raw ) );
            voltage [channel + 1] = u;
            channel = channel + 1;

            if ( channel < numChannels ) then
                adc = initAdc ( channel );
            else
                ads1115.reset ();
                local s = "";
                for i = 1, #voltage do
                    s = s .. "|" .. voltage [i];
                end
                --print ( "[APP] readAdc: voltage=" .. s .. "|" );
                displayValues ( voltage, "mV" );
                publishVoltages ( client, topic, voltage );
                channel = 0;
                voltage = {};
            end

        end
    );


end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, baseTopic )

    print ( "[APP] start:" );

    gpio.mode ( alertPin, gpio.INT );
    --gpio.trig ( alertPin, "down", readadc );

    i2c.setup ( 0, sdaPin, sclPin, i2c.SLOW );
    display = u8g2 ["ssd1306_i2c_64x48_er"] ( 0, 0x3c ); -- slave address

    displayValues ();

end

function M.connect ( client, topic )

    print ( "[APP] connect:" );

    readAndPublish ( client, topic, readAdc );

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );

end

function M.periodic ( client, topic )

    print ( "[APP] periodic: topic=" .. topic );

    readAndPublish ( client, topic, readAdc );

end

function M.offline ( client )

    print ( "[APP] offline:" );

    return true;

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------