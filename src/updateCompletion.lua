--
-- nodes@home/luaNodes/updateCompletion
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

    print ( "[UPDATE] updateCompletion: heap=" .. node.heap () );
    
    for i, updateFile in ipairs ( update.filesList ) do
    
        local fileName = updateFile.name;
        print ( "[UPDATE] rename " .. fileName );
        
        local pos = fileName:find ( "%." );
        local suffix = pos and fileName:sub ( pos + 1 ) or nil;
        
        print ( "[UPDATE] pos=" .. pos .. " suffix=" .. suffix );
        
        local updateFileName = fileName;
        local lcFileName = nil;

        if ( not suffix ) then
            updateFileName = updateFileName .. update.LUA_POSTFIX;
            lcFileName = fileName .. update.LC_POSTFIX;
        elseif ( suffix == "lua" ) then
            lcFileName = fileName .. update.LC_POSTFIX;
        end
        
        local oldUpdateFileName = update.OLD_PREFIX .. updateFileName;
        local otaUpdateFileName = update.OTA_PREFIX .. updateFileName;

        local oldLcFileName;
        local otaLcFileName;
        if ( lcFileName ) then
            oldLcFileName = update.OLD_PREFIX .. lcFileName;
            otaLcFileName = update.OTA_PREFIX .. lcFileName;
        end

        file.remove ( updateFileName );
        file.remove ( oldUpdateFileName );

        if ( lcFileName ) then file.remove ( lcFileName ); end
        if ( oldLcFileName ) then file.remove ( oldLcFileName ); end
        
        if ( not file.rename ( otaUpdateFileName, updateFileName  ) ) then
            print ( "[UPDATE] ERROR renaming" .. otaUpdateFileName );
        end
        if ( otaLcFileName and file.exists ( otaLcFileName ) and not file.rename ( otaLcFileName, lcFileName  ) ) then
            print ( "[UPDATE] ERROR renaming" .. otaLcFileName );
        end
        
    end
    
    print ( "[UPDATE] renaming " .. update.UPDATE_URL_FILENAME );
    file.remove ( update.OLD_PREFIX .. update.UPDATE_URL_FILENAME );
    if ( not file.rename ( update.UPDATE_URL_FILENAME, update.OLD_PREFIX .. update.UPDATE_URL_FILENAME  ) ) then
        print ( "[UPDATE] ERROR renaming" .. update.UPDATE_URL_FILENAME );
    end

    print ( "[UPDATE] renaming " .. update.UPDATE_JSON_FILENAME );
    file.remove ( update.OLD_PREFIX .. update.UPDATE_JSON_FILENAME );
    if ( not file.rename ( update.UPDATE_JSON_FILENAME, update.OLD_PREFIX .. update.UPDATE_JSON_FILENAME  ) ) then
        print ( "[UPDATE] ERROR renaming" .. update.UPDATE_JSON_FILENAME );
    end
    
    -- node.task.post ( function () setUpdateState ( "ok: " .. message ) end );
    node.task.post ( function () update.next ( moduleName, "updateMqttState", "ok: " .. message ) end );
        
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------