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

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local numSensors = nodeConfig.appCfg.numSensors;

local retain = 0;
-- local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

local function publishValues ( client, topic, temperatures )

    print ( "[APP] publish: count=" .. #temperatures );
    
    local payload = '{';
    
    for i = 1, #temperatures do
        payload = string.format ( '%s"temperature%d":%.1f,', payload, i, temperatures [i] ); 
    end
    
    payload = payload .. '"unit":"°C"}';
    
    print ( "[APP] payload=" .. payload );
    
    client:publish ( topic .. "/value/temperature", payload, 0, retain, -- qos, retain
        function ( client )
        end
    );

end

local function readAndPublish ( client, topic )

    if ( dsPin ) then
    
        local temps = {};

        ds18b20.read (
            function ( index, address, resolution, temperature, tempinteger, parasitic )
                local addr = string.format ( "%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X", string.match ( address, "(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)" ) );
                print ( "[APP] index=" .. index .. " address=" .. addr .. " resolution=" .. resolution .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                temps [#temps + 1] = temperature;
                if ( index == numSensors ) then
                    publishValues ( client, topic, temps );
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
    
    readAndPublish ( client, topic );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
    readAndPublish ( client, topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------