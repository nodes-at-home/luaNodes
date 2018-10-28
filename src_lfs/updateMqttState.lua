--
-- nodes@home/luaNodes/updateMqttState
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 29.08.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local mqttClient = nil;     -- mqtt client

----------------------------------------------------------------------------------------
-- private

local function restart ()

    if ( trace ) then 
        trace.off ( node.restart ); 
    else
        node.restart ();
    end

end

--------------------------------------------------------------------
-- public

function M.start ( message )

    -- Setup MQTT client and events
    if ( mqttClient == nil ) then
        local mqttClientName = wifi.sta.gethostname () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password
    end

    print ( "[MQTT] connecting to " .. nodeConfig.mqtt.broker );
    
    local result = mqttClient:connect( nodeConfig.mqtt.broker , 1883, 0, 0, -- broker, port, secure, autoreconnect
        function ( client )
            print ( "[MQTT] connected to MQTT Broker" );
            print ( "[MQTT] node=" .. nodeConfig.topic );
            -- 1) set node tag on update state topic
            local topic = "nodes@home/update/" .. node.chipid ();
            local msg = nodeConfig.app .. "@" .. nodeConfig.location;
            print ( "[MQTT] publish topic=" .. topic .. " msg=" .. msg );
            client:publish ( topic, msg, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                -- 2) set update state
                function (client )
                    local topic = "nodes@home/update/" .. node.chipid () .. "/state";
                    print ( "[MQTT] publish topic=" .. topic .. " msg=" .. message );
                    client:publish ( topic, message, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                        -- 3) reset update service topic
                        function ( client )
                            local topic = nodeConfig.topic .. "/service/update";
                            print ( "[MQTT] publish reset topic=" .. topic );
                            client:publish ( topic, "", 0, 1, -- ..., qos, retain
                                -- 4( restart
                                restart -- last step is restart node
                            );
                        end
                    );
                end
            );
        end,
        function ( client, reason ) 
            print ( "[MQTT] not connected reason=" .. reason );
        end
    );

    print ( "[MQTT] connect result=" .. tostring ( result ) );
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------