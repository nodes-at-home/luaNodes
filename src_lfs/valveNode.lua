--------------------------------------------------------------------
--
-- nodes@home/luaNodes/valveNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 23.04.2023

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local util = require ( "util" );

local gpio = gpio;

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "valve";

local relayPins = nodeConfig.appCfg.relayPins;

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local RELAY_ON = activeHigh and gpio.HIGH or gpio.LOW;
local RELAY_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

local function changeState ( client, topic, payload, valveindex )

    logger:info ( "changeState: topic=" .. topic .. " payload=" .. payload .. " valveindex=" .. valveindex );

    local pin = relayPins [valveindex];
    if ( pin ) then
        gpio.write ( pin, payload == "ON" and RELAY_ON or RELAY_OFF );
        logger:debug ( "changeState: state=" .. payload .. " to " .. topic .. " pin=" .. pin );
        client:publish ( topic .. "/state", payload, 0, retain, function () end ); -- qos, retain
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local lastTopicPart = topicParts [#topicParts];
    local device = lastTopicPart:sub ( 1, #lastTopicPart - 1 )
    local valveindex = tonumber ( lastTopicPart:sub ( -1 ) ) or "-";

    logger:debug ( "message: last=" .. lastTopicPart .. " device=" .. device .. " index=" .. valveindex );

    if ( device == nodeDevice and type ( valveindex ) == "number" ) then
        if ( payload == "ON" or payload == "OFF" ) then
            changeState ( client, topic, payload, valveindex );
        end
    end

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

for _, pin in ipairs ( relayPins ) do
    gpio.mode ( pin, gpio.OUTPUT );
    gpio.write ( pin, RELAY_OFF );
end

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------