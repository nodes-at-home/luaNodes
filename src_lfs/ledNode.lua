--------------------------------------------------------------------
--
-- nodes@home/luaNodes/sonoffNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
-- idea from https://github.com/KmanOz/SonoffLED-HomeAssistant
--
--------------------------------------------------------------------
-- junand 15.04.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local util = require ( "util" );

local pwm, gpio = pwm, gpio;

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "led";

local ledOn = false;
local brightness = nodeConfig.appCfg.initialBrightness and nodeConfig.appCfg.initialBrightness or 128;
local color = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor or 300;
local pwmScale = nodeConfig.appCfg.pwmScale and nodeConfig.appCfg.pwmScale or 1;
local pwmFrequency = nodeConfig.appCfg.pwmScale and nodeConfig.appCfg.pwmFrequency or 100;

local warmLightPin = nodeConfig.appCfg.warmLightPin;
local coldLightPin = nodeConfig.appCfg.coldLightPin;

----------------------------------------------------------------------------------------
-- private

-- brighness: 0 .. 1023 by using brightness_scale for mqtt light definition in home assistant
-- color: 154 .. 500

local function setLedPwm ( pin, brightness )

    logger:info ( "setLedPwm: pin=" .. pin .. " brightness=" .. brightness );

    if ( brightness > 0 ) then
        -- in ha the slider is from 0 to 255
        pwm.setduty ( pin, brightness * pwmScale );
        pwm.start ( pin );
    else
        pwm.stop ( pin );
    end

end

local function initLedPin ( pin )

    logger:info ( "initLedPin: pin=" .. pin );

    gpio.mode ( pin, gpio.OUTPUT );
    gpio.write ( pin, gpio.LOW );
    pwm.setup ( pin, pwmFrequency, 0 ); -- pwm frequency, duty cycle
    pwm.stop ( pin );

end

local function changeState ( client, topic, payload )

    logger:info ( "changeState: topic=" .. topic .. " payload=" .. payload );

    local brightnessWarm, brightnessCold = 0, 0;

    if ( ledOn ) then

        if ( color > 384 ) then
            -- only warm light
            brightnessWarm = brightness;
            brightnessCold = 0;
        elseif ( color > 269 ) then
            -- cold and warm light
            brightnessWarm = brightness;
            brightnessCold = brightness;
        else
            -- only cold light
            brightnessWarm = 0;
            brightnessCold = brightness;
        end

    end

    setLedPwm ( warmLightPin, brightnessWarm );
    setLedPwm ( coldLightPin, brightnessCold );

    client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, function () end ); -- qos, retain

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

-- only for dynchrin actions on init
function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

end

-- last action in callback chain of mqtt connect
function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    if ( device == nodeDevice ) then
        if ( payload == "ON" or payload == "OFF" ) then
            ledOn = payload == "ON";
            changeState ( client, topic, payload );
        end
    elseif ( device == "brightness" ) then
        brightness = 0 + payload
        changeState ( client, topic, payload );
    elseif ( device == "color" ) then
        color = 0 + payload;
        changeState ( client, topic, payload );
    end

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

initLedPin ( warmLightPin );
initLedPin ( coldLightPin );

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------