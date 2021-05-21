--
-- nodes@home/luaNodes/update
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 29.08.2017

----
-- (1) write marker file that we are in update proress, the content is the url
-- (2) restart
---
-- (3) read marker file
-- (4) get list of files (json)
-- (5) get each new file with prefixed name "ota_"
-- (8) rename all old files (*.lua and *.lc) with prefix "old_"
-- (9) rename all new files by remmoving prefix "ota_"
-- (10) rename marker file as old
-- (11) restart
---

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

M.UPDATE_URL_FILENAME = "update.url";
M.UPDATE_JSON_FILENAME = "update_files.json"

M.host = nil;
M.port = nil;
M.path = nil;

M.fileList = nil;

M.OLD_PREFIX = "old_";
M.OTA_PREFIX = "ota_";
M.LUA_POSTFIX = ".lua";
M.LC_POSTFIX = ".lc";
M.JSON_POSTFIX = ".json";

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.unrequire ( module )

    package.loaded [module] = nil
    _G [module] = nil

end

function M.next ( fromModule, nextModule, optMessage )

    logger:info ( "next: from=" .. tostring ( fromModule ) .. " to=" .. tostring ( nextModule ) .. " msg=" .. tostring ( optMessage ) );
    logger:debug ( "next: heap=" .. node.heap () );

    if ( fromModule ) then
        M.unrequire ( fromModule );
        collectgarbage ();
        if ( nextModule ) then
            local m = require ( nextModule );
            if ( optMessage ) then
                node.task.post ( function () m.start ( optMessage ) end );
            else
                node.task.post ( m.start );
            end
        end
    end

end

function M.update ()

    logger:info ( "update: second stage of update" );

    require ( "updateWifi" ).start ();

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------