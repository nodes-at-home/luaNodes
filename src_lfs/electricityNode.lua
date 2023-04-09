--------------------------------------------------------------------
--
-- nodes@home/luaNodes/electricNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 25.03.2023

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local softuart, uart, file = softuart, uart, file;

-------------------------------------------------------------------------------
--  Settings

local rxPin = nodeConfig.appCfg.rxPin or 7;
local baudrate = nodeConfig.appCfg.baudrate or 9600;
local receiveBufferLength = nodeConfig.appCfg.rcvbuflen or 16;
local usesoftuart = nodeConfig.appCfg.softuart or false;

local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

end

local function printData ( headline, data )

    local n = string.len ( data );
    local s = "";
    for i = 1, n do
        s = s .. tohex ( data:byte ( i ) ) .. " ";
    end
    local msg = headline .. "length=" .. n .. " data=" .. s;
    print ( msg );

    return msg;

end

local function processData ( data )

    file.write ( data );
    file.flush ();
    local msg = printData ( "received data after " .. receiveBufferLength .. " Bytes: ", data );
--            logger:notice ( "connect: " .. msg );

end

function M.connect ( client, topic )

    logger:debug ( "connect: topic=" .. topic );

    file.open ( "logarex.dat", "w" );

    if ( usesoftuart ) then
        local serial = softuart.setup ( baudrate, 8, rxPin );
        serial:on ( "data", receiveBufferLength, processData );
    else
        uart.setup ( 0, baudrate, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0 );    -- no echo
        uart.alt ( 1 ); -- use alternate pins: D7 = Rx, D8 = Tx
        uart.on ( "data", receiveBufferLength, processData, 0 );                -- dont use interpreter!!!
    end
    --logger:notice ( "connect: baudrate=" .. baudrate );

--    local payload = string.format ( '{"dt":%f,"threshold":%d,"latency":%d}', dt, voltageThreshold, latencyThreshold );
--    logger:info ( "connect: payload=" .. payload );
--    client:publish ( topic .. "/value/tick", payload, 0, retain, -- qos, retain
--        function ( client )
--        end
--    );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------