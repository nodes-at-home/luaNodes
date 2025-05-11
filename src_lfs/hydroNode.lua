--------------------------------------------------------------------
--
-- nodes@home/luaNodes/hydroNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 07.05.2024

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local util = require ( "util" );
local ds18b20 = require ( "ds18b20" );

local gpio = gpio;

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "pump";

local relayPin = nodeConfig.appCfg.relayPin or 1;
print ( "relayPin=" .. relayPin );
local dsPin = nodeConfig.appCfg.dsPin or 4;

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local RELAY_ON = activeHigh and gpio.HIGH or gpio.LOW;
local RELAY_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local openDrain = nodeConfig.appCfg.openDrain;
if ( openDrain == nil ) then openDrain = false end;

local retain = nodeConfig.mqtt.retain;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private

local function printSensors ()

    if ( ds18b20.sens ) then
        loger.debug  ( "printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            logger:debug ( string.format ( "printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function readAndPublish ( client, topic, callback )

    logger:info ( "readAndPublish: topic=" .. topic );

    ds18b20:read_temp (
        function ( sensorValues )
            --printSensors ();
            local i = 0;
            for address, temperature in pairs ( sensorValues ) do
                i = i + 1;
                if ( i == 1 ) then -- only first sensor
                    local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    local parasitic = address:byte ( 9 ) == 1 and "(parasite)" or "-";
                    logger:debug ( "readAndPublish: address=" .. addr .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                    local payload = ('{"value":%f,"unit":"°C"}'):format ( temperature );
                    client:publish ( topic .. "/value/temperature", payload, qos, retain,
                        function ( client )
                            if ( callback ) then
                                callback ( client );
                            end
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

local function changeState ( client, topic, payload )

    logger:info ( "changeState: topic=" .. topic .. " payload=" .. payload );

    gpio.write ( relayPin, payload == "ON" and RELAY_ON or RELAY_OFF );
    logger:debug ( "changeState: state=" .. payload .. " to " .. topic .. " pin=" .. relayPin );
    client:publish ( topic .. "/state", payload, 0, retain, function () end ); -- qos, retain

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic)

    logger:info ( "start: topic=" .. topic );

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    local callback = function ( client )
        changeState ( client, topic, "OFF" );
    end;

    readAndPublish ( client, topic, callback );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

    readAndPublish ( client, topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    logger:debug ( "message: device=" .. device );

    if ( device == nodeDevice ) then
        if ( payload == "ON" or payload == "OFF" ) then
            changeState ( client, topic, payload );
        end
    end

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

if ( openDrain ) then
    gpio.mode ( relayPin, gpio.OPENDRAIN, gpio.PULLUP );
else
    gpio.mode ( relayPin, gpio.OUTPUT );
end
gpio.write ( relayPin, RELAY_OFF );

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------