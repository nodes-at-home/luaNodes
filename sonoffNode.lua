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

local retain = espConfig.node.retain;

local debounceTimer = espConfig.node.timer.debounce;
local debounceDelay = espConfig.node.timer.debounceDelay;

local nodeDevice = espConfig.node.appCfg.device or "lamp";

local relayPin = espConfig.node.appCfg.relayPin;
local ledPin = espConfig.node.appCfg.ledPin;
local buttonPin = espConfig.node.appCfg.buttonPin;

local flashHighPulseLength = espConfig.node.appCfg.flashHighPulseLength * 1000; -- us
local flashLowPulseLength = espConfig.node.appCfg.flashLowPulseLength * 1000; -- us

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    gpio.write ( ledPin, payload == "ON" and gpio.LOW or gpio.HIGH );
    gpio.write ( relayPin, payload == "ON" and gpio.HIGH or gpio.LOW );
    print ( "[APP] publish state=" .. payload .. " to" .. topic );
    client:publish ( topic .. "/value/state", payload, 0, retain, function () end ); -- qos, retain

end

local function flashLed ( times )

    gpio.serout ( ledPin, 0, { flashLowPulseLength, flashHighPulseLength }, times, function () end ); -- async
 
end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    print ( "[APP] connected with topic=" .. topic );
    
--    flashLed ( 2 );
    
    -- activate button only if pin is defined
    if ( buttonPin ) then

        gpio.trig ( buttonPin, "up",
            function ( level )
                tmr.alarm ( debounceTimer, debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                    function ()
                        local state = gpio.read ( relayPin );
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

gpio.mode ( ledPin, gpio.OUTPUT );
--flashLed ( 3 );

gpio.mode ( relayPin, gpio.OUTPUT );
gpio.write ( relayPin, gpio.LOW );

-- activate button only if pin is defined
if ( buttonPin ) then 
    gpio.mode ( buttonPin, gpio.INT, gpio.PULLUP );
end    

return M;

-------------------------------------------------------------------------------