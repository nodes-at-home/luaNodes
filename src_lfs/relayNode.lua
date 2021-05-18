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

local logger = require ( "syslog" ).logger ( moduleName );

local util = require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "lamp";

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    logger.info ( "changeState: topic=" .. topic .. " payload=" .. payload)

    gpio.write ( nodeConfig.appCfg.ledPin, payload == "ON" and gpio.HIGH or gpio.LOW );

    local relayPin = payload == "ON" and nodeConfig.appCfg.relayPin2 or nodeConfig.appCfg.relayPin1;
    logger.debug ( "changeState: relayPin=" .. relayPin );
    logger.debug ( "changeState: publish state=" .. payload .. " to " .. topic );

    client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, -- qos, retain
        function ()
            local relayPulseLength = nodeConfig.appCfg.relayPulseLength * 1000; -- us
            gpio.serout ( relayPin, 1, { relayPulseLength, relayPulseLength }, 1, function ()  end ); -- async
        end
    );

end

local function flashLed ( times )

    gpio.serout ( nodeConfig.appCfg.ledPin, 1, { nodeConfig.appCfg.flashHighPulseLength * 1000, nodeConfig.appCfg.flashLowPulseLength * 1000 }, times, function () end ); -- async

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    flashLed ( 2 );
--    changeState ( client, topic .. "/" .. nodeDevice, "OFF" ); -- default

--    gpio.trig ( nodeConfig.appCfg.buttonPin, "up",
--        function ( level )
--            tmr.alarm ( nodeConfig.timer.debounce, nodeConfig.timer.debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
--                function ()
--                    local state = gpio.read ( relayPin );
--                    logger.debug ( "connect: state=", state );
--                    changeState ( client, topic .. "/lamp", state == 0 and "ON" or "OFF" );
--                end
--            );
--        end
--    );

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    if ( device == nodeDevice ) then
        if ( payload == "ON" or payload == "OFF" ) then
            changeState ( client, topic, payload );
        end
    end

end

function M.offline ( client )

    logger.info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

gpio.mode ( nodeConfig.appCfg.ledPin, gpio.OUTPUT );
flashLed ( 3 );

gpio.mode ( nodeConfig.appCfg.relayPin1, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.relayPin1, gpio.LOW );
gpio.mode ( nodeConfig.appCfg.relayPin2, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.relayPin2, gpio.LOW );

--gpio.mode ( nodeConfig.appCfg.buttonPin, gpio.INT, gpio.PULLUP );

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------