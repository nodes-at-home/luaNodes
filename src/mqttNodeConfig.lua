--------------------------------------------------------------------
--
-- nodes@home/luaNodes/mqttNodeConfig
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 07.08.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.subscribe ( client )

    print ( "[CONFIG] mqttNodeconfig.subscribe called" )
    
    local topic = "nodes@home/config/" .. node.chipid () .. "/json";
    print ( "[CONFIG] subscribe to topic=" .. topic );
    client:subscribe ( topic, 0, -- ..., qos
        function ( client )
            -- reset topic
            local topic = nodeConfig.topic .. "/service/config"
            print ( "[CONFIG] unsubscribe to topic=" .. topic );
            client:publish ( topic, "", 0, 1, -- ..., qos, retain
                function ( client )
                end
            );
        end
    );

    package.loaded [ moduleName ] = nil;

end

function M.receive ( client, payload )

    print ( "[CONFIG] mqttNodeconfig.receive called" )
    
    local json = cjson.decode ( payload );
    if ( json.chipid == node.chipid () ) then
        print ( "[CONFIG] found same chipid " .. node.chipid () );
        if ( file.open ( "espConfig_mqtt.json", "w" ) ) then
            file.write ( payload );
            file.close ();
            print ( "[CONFIG] restarting after config save")
            if ( trace ) then 
                trace.off ( node.restart ); 
            else
                node.restart ();
            end
        end
    end
    
    package.loaded [ moduleName ] = nil;

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------