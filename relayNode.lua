--------------------------------------------------------------------
--
-- nodes@home/luaNodes/sonoffNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 12.11.2016

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

local relayPin1 = espConfig.node.appCfg.relayPin1;
local relayPin2 = espConfig.node.appCfg.relayPin2;
local ledPin = espConfig.node.appCfg.ledPin;
local buttonPin = espConfig.node.appCfg.buttonPin;

local relayPulseLength = espConfig.node.appCfg.relayPulseLength * 1000; -- us
local flashHighPulseLength = espConfig.node.appCfg.flashHighPulseLength * 1000; -- us
local flashLowPulseLength = espConfig.node.appCfg.flashLowPulseLength * 1000; -- us

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    gpio.write ( ledPin, payload == "ON" and gpio.HIGH or gpio.LOW );
    
    local relayPin = payload == "ON" and relayPin2 or relayPin1;
    print ( "[APP] relayPin=" .. relayPin );
    print ( "[APP] publish state=" .. payload .. " to " .. topic );

    client:publish ( topic .. "/value/state", payload, 0, retain, -- qos, retain 
        function () 
            gpio.serout ( relayPin, 1, { relayPulseLength, relayPulseLength }, 1, function ()  end ); -- async 
        end
    );

end

local function flashLed ( times )

    gpio.serout ( ledPin, 1, { flashHighPulseLength, flashLowPulseLength }, times, function () end ); -- async
 
end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    print ( "[APP] connected with topic=" .. topic );
    
    flashLed ( 2 );
--    changeState ( client, topic .. "/" .. nodeDevice, "OFF" ); -- default
    
--    gpio.trig ( buttonPin, "up",
--        function ( level )
--            tmr.alarm ( debounceTimer, debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
--                function ()
--                    local state = gpio.read ( relayPin );
--                    print ( "state=", state );
--                    changeState ( client, topic .. "/lamp", state == 0 and "ON" or "OFF" );
--                end
--            );
--        end 
--    );

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
flashLed ( 3 );

gpio.mode ( relayPin1, gpio.OUTPUT );
gpio.write ( relayPin1, gpio.LOW );
gpio.mode ( relayPin2, gpio.OUTPUT );
gpio.write ( relayPin2, gpio.LOW );

--gpio.mode ( buttonPin, gpio.INT, gpio.PULLUP );

return M;

-------------------------------------------------------------------------------