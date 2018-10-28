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

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------