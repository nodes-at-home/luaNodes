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

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

local mqttClient = nil;     -- mqtt client

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

local function restart ()

    syslog.restart ();
    logger.alert ( "RESTARTING" ); -- to resolve the restart flag in syslog

end

function M.start ( message )

    -- Setup MQTT client and events
    if ( mqttClient == nil ) then
        local mqttClientName = wifi.sta.gethostname () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password
    end

    logger.debug ( "start: connecting to " .. nodeConfig.mqtt.broker );

    logger.alert ( "start: " .. nodeConfig.app .. "@" .. nodeConfig.location .. " -> " .. message );

    local result = mqttClient:connect( nodeConfig.mqtt.broker , 1883, false, -- broker, port, secure
        function ( client )
            logger.debug ( "start: connected to MQTT Broker" );
            logger.debug ( "start: node=" .. nodeConfig.topic );
            -- 1) set node tag on update state topic
            local topic = "nodes@home/update/" .. node.chipid ();
            local msg = nodeConfig.app .. "@" .. nodeConfig.location;
            logger.debug ( "start: publish topic=" .. topic .. " msg=" .. msg );
            client:publish ( topic, msg, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                -- 2) set update state
                function (client )
                    local topic = "nodes@home/update/" .. node.chipid () .. "/state";
                    logger.debug ( "start: publish topic=" .. topic .. " msg=" .. message );
                    client:publish ( topic, message, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                        -- 3) reset update service topic
                        function ( client )
                            local topic = nodeConfig.topic .. "/service/update";
                            logger.debug ( "start: publish reset topic=" .. topic );
                            client:publish ( topic, "", 0, 1, -- ..., qos, retain
                                -- 4) restart
                                restart -- last step is restart node
                            );
                        end
                    );
                end
            );
        end,
        function ( client, reason )
            logger.warning ( "start: not connected reason=" .. reason );
        end
    );

    logger.debug ( "connect result=" .. tostring ( result ) );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------