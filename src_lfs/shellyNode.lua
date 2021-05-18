--------------------------------------------------------------------
--
-- nodes@home/luaNodes/sonoffNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 16.10.2020

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local HIGH = gpio.HIGH;
local LOW = gpio.LOW;
local OUTPUT = gpio.OUTPUT;

local retain = nodeConfig.mqtt.retain;
local nodeDevice = nodeConfig.appCfg.device or "lamp";
local relayPin = nodeConfig.appCfg.relayPin;
local buttonPin = nodeConfig.appCfg.buttonPin;

local debounceTmr = tmr.create ();

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload )

    logger.info ( "changeState: topic=" .. topic .. " payload=" .. payload );

    gpio.write ( relayPin, payload == "ON" and HIGH or LOW );

    logger.debug ( "changeState: state=" .. payload .. " to " .. topic .. "/state" );
    client:publish ( topic .. "/state", payload, 0, retain, function () end ); -- qos, retain

end

local function initTrigger ( client, topic )

    gpio.trig ( buttonPin, "both",
        function ( level )
            debounceTmr:alarm ( nodeConfig.timer.debounceDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                function ()
                    local level = gpio.read ( buttonPin );
                    logger.debug ( "initTrigger: level=" .. level );
                    changeState ( client, topic, level == 1 and "ON" or "OFF" );
                end
            );
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    -- activate button only if pin is defined
    if ( buttonPin ) then
        initTrigger ( client, topic .. "/" .. nodeDevice );
    end

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

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

    logger.info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

gpio.mode ( relayPin, OUTPUT );
gpio.write ( relayPin, LOW );

-- activate button only if pin is defined
if ( buttonPin ) then
    gpio.mode ( buttonPin, gpio.INT );
end

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------