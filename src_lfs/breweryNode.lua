--------------------------------------------------------------------
--
-- nodes@home/luaNodes/breweryNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.09.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

require ( "util" );

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local SOCKET_ON = activeHigh and gpio.HIGH or gpio.LOW;
local SOCKET_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private

local function printSensors ()

    if ( ds18b20.sens ) then
        logger.debug ( "printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            logger.debug ( string.format ( "printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function readAndPublishTemperature ( client, topic )

    if ( dsPin ) then

        ds18b20:read_temp (
            function ( sensorValues )
                --printSensors ();
                local i = 0;
                for address, brewTemperature in pairs ( sensorValues ) do
                    i = i + 1;
                    if ( i == 1 ) then -- only first sensor
                        --local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                        --logger.debug ( ("readAndPublishTemperature: Sensor %s -> %s°C %s"):format ( addr, temperature, address:byte ( 9 ) == 1 and "(parasite)" or "-" ) );
                        logger.debug ( ("readAndPublishTemperature: temp=%f"):format ( brewTemperature ) );
                        local payload = ('{"value":%f,"unit":"°C"}'):format ( brewTemperature );
                        client:publish ( topic .. "/value/temperature", payload, qos, NO_RETAIN,
                            function ( client )
                            end
                        );
                    end
                end

            end,
            dsPin,
            ds18b20.C,          -- °C
            nil,                -- no search
            "save"
        );

    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger.info ( "start: topic=" .. topic );

end

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    readAndPublishTemperature ( client, topic );

end

function M.offline ( client )

    logger.info ( "offline:" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    local pin = nil;
    if ( type ( nodeConfig.appCfg.sockets ) == "table" ) then
        for _, ssr in ipairs ( nodeConfig.appCfg.sockets ) do
            if ( device == ssr.device ) then
                pin = ssr.pin;
            end
        end
    else
        logger.debug ( "message: nodeConfig.appCfg.sockets is not a table" );
    end

    logger.debug ( "message: device=" .. device .. " pin=" .. tostring ( pin ) );

    if ( pin ) then
        if ( payload == "ON" or payload == "OFF" ) then
            local pinLevel = payload == "ON" and SOCKET_ON or SOCKET_OFF;
            logger.debug ( "message: set pin=" .. pin .. " to level=" .. tostring ( pinLevel ) );
            gpio.write ( pin, pinLevel );
            logger.debug ( "message: publish state=" .. payload .. " to " .. topic .. "/state" );
            client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, function () end ); -- qos, retain
        end
    end

end

function M.periodic ( client, topic )

    logger.info ( "periodic: topic=" .. topic );

    readAndPublishTemperature ( client, topic );

end

-------------------------------------------------------------------------------
-- main

if ( type ( nodeConfig.appCfg.sockets ) == "table" ) then
    for _, ssr in ipairs ( nodeConfig.appCfg.sockets ) do
        gpio.mode ( ssr.pin, gpio.OPENDRAIN );
        gpio.write ( ssr.pin, SOCKET_OFF );
    end
end

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------