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

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

local index = -1;
local msg = "msg lost";

----------------------------------------------------------------------------------------
-- private

local function renameUrlAndJsonFiles ()

    logger:info ( "renameUrlAndJsonFiles: heap=" .. node.heap () );

    logger:debug ( "renameUrlAndJsonFiles: renaming " .. update.UPDATE_URL_FILENAME );
    file.remove ( update.OLD_PREFIX .. update.UPDATE_URL_FILENAME );
    if ( not file.rename ( update.UPDATE_URL_FILENAME, update.OLD_PREFIX .. update.UPDATE_URL_FILENAME  ) ) then
        logger:debug ( "ERROR renaming" .. update.UPDATE_URL_FILENAME );
    end

    logger:debug ( "renameUrlAndJsonFiles: renaming " .. update.UPDATE_JSON_FILENAME );
    file.remove ( update.OLD_PREFIX .. update.UPDATE_JSON_FILENAME );
    if ( not file.rename ( update.UPDATE_JSON_FILENAME, update.OLD_PREFIX .. update.UPDATE_JSON_FILENAME  ) ) then
        logger:warning ( "renameUrlAndJsonFiles: ERROR renaming" .. update.UPDATE_JSON_FILENAME );
    end

    node.task.post ( function () update.next ( moduleName, "updateMqttState", "ok: " .. msg ) end );

end

local function renameUpdateFile ()

    logger:info ( "renameUpdateFile: index=" .. index .. " heap=" .. node.heap () );

    local fileName = update.filesList [index].name;
    logger:debug ( "renameUpdateFile: rename " .. fileName );

    local pos = fileName:find ( "%." );
    local suffix = pos and fileName:sub ( pos + 1 ) or nil;
    --logger:debug ( "renameUpdateFile: pos=" .. pos .. " suffix=" .. suffix );

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
        logger:warning ( "renameUpdateFile: ERROR renaming" .. otaUpdateFileName );
    end
    if ( otaLcFileName and file.exists ( otaLcFileName ) and not file.rename ( otaLcFileName, lcFileName  ) ) then
        logger:warning ( "renameUpdateFile: ERROR renaming" .. otaLcFileName );
    end

    if ( index < #update.filesList ) then -- next
        index = index + 1;
        node.task.post ( renameUpdateFile );
    else
        node.task.post ( renameUrlAndJsonFiles );
    end

end

--------------------------------------------------------------------
-- public

function M.start ( message )

    logger:info ( "start: message=" .. message .. " heap=" .. node.heap () );

    msg = message;

    if ( update.filesList and #update.filesList > 0 ) then -- update
        index = 1;
        node.task.post ( renameUpdateFile );
    else
        node.taks.post ( renameUrlAndJsonFiles );
    end

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------