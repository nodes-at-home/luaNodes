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

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    local useLedForState = nodeConfig.appCfg.useLedForState; -- on S20 there are two leds and the blue is switched with relay
    if ( useLedForState == nil or useLedForState ) then gpio.write ( nodeConfig.appCfg.ledPin, payload == "ON" and gpio.LOW or gpio.HIGH ); end

    gpio.write ( nodeConfig.appCfg.relayPin, payload == "ON" and gpio.HIGH or gpio.LOW );

    print ( "[APP] publish state=" .. payload .. " to " .. topic );
    client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, function () end ); -- qos, retain

end

local function flashLed ( times )

    gpio.serout ( nodeConfig.appCfg.ledPin, 0, { nodeConfig.appCfg.flashLowPulseLength * 1000, nodeConfig.appCfg.flashHighPulseLength * 1000 }, times, function () end ); -- async
 
end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    print ( "[APP] connected with topic=" .. topic );
    
    flashLed ( 2 );
    
    -- activate button only if pin is defined
    if ( nodeConfig.appCfg.buttonPin ) then

        gpio.trig ( nodeConfig.appCfg.buttonPin, "up",
            function ( level )
                tmr.alarm ( nodeConfig.timer.debounce, nodeConfig.timer.debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                    function ()
                        local state = gpio.read ( nodeConfig.appCfg.relayPin );
                        changeState ( client, topic .. "/" .. nodeDevice, state == 0 and "ON" or "OFF" );
                    end
                );
            end 
        );
        
    end

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );
    
    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];
    
    if ( device == nodeDevice ) then
        if ( payload == "ON" or payload == "OFF" ) then
            changeState ( client, topic, payload ); 
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

gpio.mode ( nodeConfig.appCfg.ledPin, gpio.OUTPUT );

gpio.mode ( nodeConfig.appCfg.relayPin, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.relayPin, gpio.LOW );

-- activate button only if pin is defined
if ( nodeConfig.appCfg.buttonPin ) then 
    gpio.mode ( nodeConfig.appCfg.buttonPin, gpio.INT, gpio.PULLUP );
end    

return M;

-------------------------------------------------------------------------------