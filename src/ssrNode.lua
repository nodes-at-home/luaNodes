--------------------------------------------------------------------
--
-- nodes@home/luaNodes/sonoffNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 01.03.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local SOCKET_ON = activeHigh and gpio.HIGH or gpio.LOW;
local SOCKET_OFF = activeHigh and gpio.LOW or gpio.HIGH;

print ( "[APP] settings: activeHigh=" .. tostring ( activeHigh ) .. " SOCKET_ON=" .. SOCKET_ON .. " SOCKET_OFF=" .. SOCKET_OFF );

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start: topic=" .. topic );
    
end

function M.connect ( client, topic )

    print ( "[APP] connected with topic=" .. topic );
    
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

function M.offline ( client )

    print ( "[APP] offline" );
    
    return true; -- restart mqtt connection
    
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