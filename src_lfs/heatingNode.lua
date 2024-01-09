--------------------------------------------------------------------
--
-- nodes@home/luaNodes/heatingNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 30.12.2023

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local sensoraddr = nodeConfig.appCfg.addr;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private
--

local GRAD = string.char ( 176 );

local function printSensors ()

    if ( ds18b20.sens ) then
        logger:debug ( "printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            logger:debug ( string.format ( "printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function publishValues ( client, topic, sensorValues )

    local payload = "";

    logger:info ( "publishValues: topic= " .. topic .. " number of sensors=" .. #sensorValues );

    local i = 0;
    for address, temperature  in pairs ( sensorValues ) do
        i = i + 1;
        local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
        logger:debug ( string.format ( "publishValues: sensor #%d -> address=%s temp=%.1f",  i, addr, temperature ) );
        --payload = ('%s"temperature%d":%.1f,'):format ( payload, i, temperatures [i] );
        if ( sensoraddr [addr] ) then
            if ( #payload > 0 ) then
                payload = payload .. ",";
            end
            local s = string.format ( '"%s":{"temp":%.1f,"addr":"%s","label":"%s"}', sensoraddr [addr].heatcircle, temperature, addr, sensoraddr [addr].label );
            payload = payload .. s;
        end
    end

    payload = '{"values":{' .. payload .. '},"unit":"°C"}';

    logger:notice ( "publishValues: payload=" .. payload );

    client:publish ( topic .. "/value/temperature", payload, NO_RETAIN, retain,
        function ( client )
        end
    );

end

local function readAndPublish ( client, topic )

    logger:info ( "readAndPublish: topic=" .. topic );

    if ( dsPin ) then
        ds18b20:read_temp (
            function ( sensorValues )
                printSensors ();
                publishValues ( client, topic, sensorValues );
            end,
            dsPin,
            ds18b20.C,          -- °C
            "search",                -- no search
            "save"
        );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start^: topic=" .. topic );

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    readAndPublish ( client, topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

    readAndPublish ( client, topic );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true;

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------