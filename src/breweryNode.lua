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

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local SOCKET_ON = activeHigh and gpio.HIGH or gpio.LOW;
local SOCKET_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local retain = nodeConfig.mqtt.retain;
local NO_RATIN = 0;

----------------------------------------------------------------------------------------
-- private

local function readAndPublishTemperature ( client, topic )

    if ( dsPin ) then

        ds18b20.read (
            function ( index, address, resolution, brewTemperature, tempinteger, parasitic )
                local addr = string.format ( "%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X", string.match ( address, "(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)" ) );
                print ( "[APP] readAndPublishTemperature: index=" .. index .. " address=" .. addr .. " resolution=" .. resolution .. " temperature=" .. brewTemperature .. " parasitic=" .. parasitic );
                -- only first sensor
                if ( index == 1 ) then
                    print ( string.format ( "[APP] readAndPublishTemperature: temp=%f", brewTemperature ) );
                    local payload = string.format ( '{"value":%f,"unit":"°C"}', brewTemperature );
                    client:publish ( topic .. "/value/temperature", payload, 0, NO_RATIN, -- qos, retain
                        function ( client )
                        end
                    );
                end
            end,
            {}
        );

    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
    ds18b20.setup ( dsPin );

end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    readAndPublishTemperature ( client, topic );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );
    
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
        print ( "[APP] message: nodeConfig.appCfg.sockets is not a table" );
    end
    
    print ( "[APP] message: device=" .. device .. " pin=" .. tostring ( pin ) );
    
    if ( pin ) then
        if ( payload == "ON" or payload == "OFF" ) then
            local pinLevel = payload == "ON" and SOCKET_ON or SOCKET_OFF;
            print ( "[APP] message: set pin=" .. pin .. " to level=" .. tostring ( pinLevel ) );
            gpio.write ( pin, pinLevel );
            print ( "[APP] message: publish state=" .. payload .. " to " .. topic .. "/state" );
            client:publish ( topic .. "/state", payload, 0, nodeConfig.mqtt.retain, function () end ); -- qos, retain
        end
    end

end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
    readAndPublishTemperature ( client, topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( type ( nodeConfig.appCfg.sockets ) == "table" ) then
    for _, ssr in ipairs ( nodeConfig.appCfg.sockets ) do
        gpio.mode ( ssr.pin, gpio.OPENDRAIN );
        gpio.write ( ssr.pin, SOCKET_OFF );
    end
end
    
return M;

-------------------------------------------------------------------------------