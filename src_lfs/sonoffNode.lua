--------------------------------------------------------------------
--
-- nodes@home/luaNodes/sonoffNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 30.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "lamp";

local relayPin = nodeConfig.appCfg.relayPin;
local buttonPin = nodeConfig.appCfg.buttonPin;
local ledPin = nodeConfig.appCfg.ledPin;

local flashLowPulseLength = nodeConfig.appCfg.flashLowPulseLength;
local flashHighPulseLength = nodeConfig.appCfg.flashHighPulseLength;
local useLedForState = nodeConfig.appCfg.useLedForState; -- on S20 there are two leds and the blue is switched with relay

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local RELAY_ON = activeHigh and gpio.HIGH or gpio.LOW;
local RELAY_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local debounceTmr = tmr.create ();

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    if ( ledPin and ( useLedForState == nil or useLedForState ) ) then
        gpio.write ( ledPin, payload == "ON" and gpio.LOW or gpio.HIGH );
    end

    gpio.write ( relayPin, payload == "ON" and RELAY_ON or RELAY_OFF );

    print ( "[APP] publish state=" .. payload .. " to " .. topic );
    client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, function () end ); -- qos, retain

end

local function flashLed ( times )

    gpio.serout ( ledPin, 0, { flashLowPulseLength * 1000, flashHighPulseLength * 1000 }, times, function () end ); -- async

end

local function initTrigger ( client, topic )

    gpio.trig ( buttonPin, "up",
        function ( level )
            debounceTmr:alarm ( nodeConfig.timer.debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                function ()
                    local level = gpio.read ( relayPin );
                    print ( "[APP] button trigger: level=" .. level );
                    changeState ( client, topic, level == 0 and "ON" or "OFF" );
                end
            );
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    print ( "[APP] connected with topic=" .. topic );

    if ( ledPin ) then
        flashLed ( 2 );
    end

    -- activate button only if pin is defined
    if ( buttonPin ) then
        initTrigger ( client, topic .. "/" .. nodeDevice );
    end

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    if ( device == nodeDevice ) then
        if ( payload == "ON" or payload == "OFF" ) then
            if ( buttonPin ) then
                gpio.trig ( buttonPin, "none" );
            end
            changeState ( client, topic, payload );
            if ( buttonPin ) then
                initTrigger ( client, topic );
            end
        end
    end

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( ledPin ) then
    gpio.mode ( ledPin, gpio.OUTPUT );
end

gpio.mode ( relayPin, gpio.OUTPUT );
gpio.write ( relayPin, RELAY_OFF );

-- activate button only if pin is defined
if ( buttonPin ) then
    gpio.mode ( buttonPin, gpio.INT, gpio.PULLUP );
end

return M;

-------------------------------------------------------------------------------