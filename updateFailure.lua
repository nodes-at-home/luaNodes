--
-- nodes@home/luaNodes/updateFailure
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

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.start ( message )

    print ( "[UPDATE] updateFailure: msg=" .. message .. " heap=" .. node.heap () );
    
    file.remove ( update.UPDATE_URL_FILENAME );
    file.remove ( update.UPDATE_JSON_FILENAME );
    
    -- TODO remove all ota_ files
    
    -- setUpdateState ( "failed: " .. message );
    node.task.post ( function () update.next ( moduleName, "updateMqttState", "failed: " .. message ) end );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------