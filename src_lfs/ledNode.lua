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

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "led";

local ledOn = false;
local brightness = nodeConfig.appCfg.initialBrightness and nodeConfig.appCfg.initialBrightness or 128;
local color = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor or 300;
local pwmScale = nodeConfig.appCfg.pwmScale and nodeConfig.appCfg.pwmScale or 4;
local pwmFrequency = nodeConfig.appCfg.pwmScale and nodeConfig.appCfg.pwmFrequency or 100;

----------------------------------------------------------------------------------------
-- private

-- brighness: 0 .. 255
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

    setLedPwm( nodeConfig.appCfg.warmLightPin, brightnessWarm );
    setLedPwm( nodeConfig.appCfg.coldLightPin, brightnessCold );

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

gpio.mode ( nodeConfig.appCfg.warmLightPin, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.warmLightPin, gpio.LOW );
pwm.setup ( nodeConfig.appCfg.warmLightPin, pwmFrequency, 0 ); -- pwm frequency, duty cycle
pwm.stop ( nodeConfig.appCfg.warmLightPin );

gpio.mode ( nodeConfig.appCfg.coldLightPin, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.coldLightPin, gpio.LOW );
pwm.setup ( nodeConfig.appCfg.coldLightPin, pwmFrequency, 0 ); -- pwm frequency, duty cycle
pwm.stop ( nodeConfig.appCfg.coldLightPin );

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------