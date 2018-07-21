--------------------------------------------------------------------
--
-- nodes@home/luaNodes/mqttNodeConnect
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 10.08.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.connect ( client )

    print ( "[MQTT] connected to MQTT Broker" )
    print ( "[MQTT] node=" .. nodeConfig.topic );
    
    local version = nodeConfig.version;
    print ( "[MQTT] send <" .. version .. "> to topic=" .. nodeConfig.topic );
    client:publish ( nodeConfig.topic, version, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
        function ( client )
            local voltage = -1;
            if ( nodeConfig.appCfg.useAdc ) then
                    local scale = nodeConfig.appCfg.adcScale or 4200;
                    print ( "[MQTT] adcScale=" .. scale );           
                    voltage = adc.read ( 0 ) / 1023 * scale; -- mV
            else
                voltage = adc.readvdd33 ();
            end
            print ( "[MQTT] send voltage=" .. voltage );
            client:publish ( nodeConfig.topic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, nodeConfig.mqtt.retain, -- qos, retain                                    
                function ( client )
                    local topic = "nodes@home/config/" .. node.chipid ();
                    print ( "[MQTT] send config app " ..  nodeConfig.app .. " to " .. topic );
                    client:publish ( topic, nodeConfig.app .. "@" .. nodeConfig.location, 0, 1, -- ..., qos, retain
                        function ( client )
                            local str = cjson.encode ( nodeConfig );
                            local topic = "nodes@home/config/" .. node.chipid () .. "/state";
                            print ( "[MQTT] send config to " .. topic .. str );
                            client:publish ( topic, str, 0, 1, -- ..., qos, retain
                                function ( client )
                                    if ( appNode.start ) then 
                                        appNode.start ( client, nodeConfig.topic ); 
                                    end
                                    -- subscribe to service topics
                                    local topic = nodeConfig.topic .. "/service/+";
                                    print ( "[MQTT] subscribe to topic=" .. topic );
                                    client:subscribe ( topic, 0, -- ..., qos
                                        function ( client )
                                            -- subscribe to all topics based on base topic of the node
                                            local topic = nodeConfig.topic .. "/+";
                                            print ( "[MQTT] subscribe to topic=" .. topic );
                                            client:subscribe ( topic, 0, -- ..., qos
                                                function ( client )
                                                    if ( appNode.connect ) then
                                                        appNode.connect ( client, nodeConfig.topic );
                                                    end
                                                end
                                            );
                                        end
                                    );
                                end
                            );
                        end
                    );
                end
            );
        end
    );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------