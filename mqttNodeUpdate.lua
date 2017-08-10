--------------------------------------------------------------------
--
-- nodes@home/luaNodes/mqttNodeUpdate
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

function M.checkAndStart ( payload )

    -- and there was no update with this url before
    local forceUpdate = true;
    if ( file.exists ( "old_update.url" ) ) then
        if ( file.open ( "old_update.url" ) ) then
            local url = file.readline ();
            file.close ();
            if ( url and url == payload ) then
                print ( "[UPDATE] already updated with " .. payload );
                forceUpdate = false;
             end
        end
    end
    
    -- start update procedure
    if ( forceUpdate ) then
        print ( "[UPDATE] start heap: " .. node.heap () )
        if ( file.open ( "update.url", "w" ) ) then
            local success = file.write ( payload );
            print ( "[UPDATE] update url write success=" .. tostring ( success ) );
            file.close ();
            if ( success ) then
                print ( "[UPDATE] restart for second step" );
                if ( trace ) then 
                    print ( "[UPDATE] ... wait ..." );
                    trace.off ( node.restart ); 
                else
                    node.restart ();
                end
            end
        end
    end

end

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
        if ( file.open ( "espConfig_local.json", "w" ) ) then
            file.write ( payload );
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