--------------------------------------------------------------------
--
-- nodes@home/luaNodes/brewNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.09.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local numSensors = nodeConfig.appCfg.numSensors;

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

local function publishValues ( client, topic, temperatures )

    logger.info ( "publishValues: topic=" .. topic .. " count=" .. #temperatures );

    local payload = '{';

    for i = 1, #temperatures do
        payload = ('%s"temperature%d":%.1f,'):format ( payload, i, temperatures [i] );
    end

    payload = payload .. '"unit":"°C"}';

    logger.debug ( "publishValues: payload=" .. payload );

    client:publish ( topic .. "/value/temperature", payload, NO_RETAIN, retain,
        function ( client )
        end
    );

end

local function readAndPublish ( client, topic )

    logger.info ( "readAndPublish: topic=" .. topic );

    if ( dsPin ) then

        local temps = {};

        ds18b20:read_temp (
            function ( sensorValues )
                --printSensors ();
                local i = 0;
                for address, temperature in pairs ( sensorValues ) do
                    i = i + 1;
                    local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    local parasitic = address:byte ( 9 ) == 1 and "(parasite)" or "-";
                    logger.debug ( "index=" .. i .. " address=" .. addr .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                    temps [#temps + 1] = temperature;
                    if ( i == numSensors ) then
                        publishValues ( client, topic, temps );
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

    readAndPublish ( client, topic );

end

function M.offline ( client )

    logger.info ( "offline:" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=", payload );

end

function M.periodic ( client, topic )

    logger.info ( "periodic: topic=" .. topic );

    readAndPublish ( client, topic );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------