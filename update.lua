--------------------------------------------------------------------
--
-- nodes@home/luaNodes/update2
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 12.08.2017

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

-------------------------------------------------------------------------------
--  Settings

local updateUrlFilename = "update.url";
local updateJsonFilename = "update_files.json"
local updateFilesList;
local updateFilesListIndex = 1;
local updateTag = "unknown";

local url;
local host;
local port;
local path;

local wifiLoopTimer;

local TIMER_WIFI_LOOP = 1;
local TIMER_WIFI_PERIOD = 1; -- sec

local OLD_PREFIX = "old_";
local OTA_PREFIX = "ota_";
local LUA_POSTFIX = ".lua";
local LC_POSTFIX = ".lc";
local JSON_POSTFIX = ".json";

----------------------------------------------------------------------------------------
-- private

local function splitUrl ( url )

    if ( url ) then

        -- http://<host>:<port>/<path>
        local urlSchemaStart = url:find ( "http://" );
        
        local urlHostStart = urlSchemaStart and 8 or 1;
        local urlPathStart = url:find ( "/", urlHostStart );
        if ( urlPathStart ) then
        
            local urlPortStart = url:sub ( urlHostStart, urlPathStart - 1 ):find ( ":" );
            if ( urlPortStart ) then
                urlPortStart = urlPortStart + urlHostStart;
            end 
            
            local urlPort = urlPortStart and url:sub ( urlPortStart, urlPathStart - 1 ) or 80;
            local urlHost = url:sub ( urlHostStart, urlPortStart and urlPortStart - 2 or urlPathStart - 1 );
            local urlPath = url:sub ( urlPathStart );
            
            if ( #urlHost > 0 ) then
                return urlHost, urlPort, urlPath;
            end
            
        end
        
    end
    
    return nil;
        
end

local function restart ()

    if ( trace ) then 
        trace.off ( node.restart ); 
    else
        node.restart ();
    end

end

local function wifiLoop ()

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then

        -- Stop the loop
        wifiLoopTimer:stop ();
        
        -- trace on
        if ( nodeConfig.trace.onUpdate ) then
            require ( "trace" ).on ();
        end

        if ( file.open ( updateUrlFilename ) ) then
        
            url = file.readline ();
            file.close ();
            host, port, path = splitUrl ( url );
            print ( "[UPDATE] url=" .. url .. " ,host=" .. host .. " ,port=" .. port .. " ,path=" .. path );
            
            if ( host and port and path ) then
            
                print ( "[UPDATE] downloading file list" );
            
                require ( "httpDL" );
                httpDL.download ( host, port, path .. "/" .. updateJsonFilename, updateJsonFilename,
                
                    function ( response ) -- "ok" or http response code
                    
                        if ( file.open ( updateJsonFilename ) ) then
                        
                            print ( "[UPDATE] open file " .. updateJsonFilename );
                            local payload = file.read ();
                            local json;
                            if ( pcall ( function () json = cjson.decode ( payload ) end  ) ) then

                                updateFilesList = json.files;
                                updateTag = json.tag;
                                print ( "[UPDATE] json.files=" .. tostring ( json.files ) .." json.tag=" .. tostring ( json.tag ) );

                                -- start task for update
                                if ( updateFilesList and #updateFilesList > 0 ) then -- update
                                    updateFilesListIndex = 1;
                                    collectgarbage ();
                                    print ( "[UPDATE] start update task chain" );
                                    node.task.post ( updateFile ); -- updates only the next file
                                else -- close update
                                    print ( "[UPDATE] NO update files -> FINISH" );
                                    finishUpdate ();
                                    node.task.post ( restart ); 
                                end
                            else
                                updateFailure ( "json decode failed" );
                                node.task.post ( restart ); 
                            end
                            
                        else
                        
                            updateFailure ( "file " .. updateJsonFilename .. " not opened" );
                            node.task.post ( restart ); 
                            
                        end
                        file.close ();
                        
                    end
                    
                );
                return; -- control flow is in callback of httpDL
                
            end
            
        end

        print ( "[UPDATE] nothing happens, restart")        
        finishUpdate ();
        node.task.post ( restart ); 

    else
        print ( "[WIFI] Connecting..." );
    end

end

function updateFile ()

    local fileName = updateFilesList [updateFilesListIndex].name;
    local pos = fileName:find ( "%." ); -- we mean the char '.'
    local otaFileName = OTA_PREFIX .. fileName;
    if ( not pos ) then 
        fileName = fileName .. LUA_POSTFIX;
        otaFileName = otaFileName .. LUA_POSTFIX;
    end
    local fileUrl = path .. "/" .. fileName;
    
    print ( "[UPDATE] i=" .. updateFilesListIndex .. " ,fileName=" .. fileName .. " ,url=" .. fileUrl );

    require ( "httpDL" );
    httpDL.download ( host, port, fileUrl, otaFileName,
        function ( rc )
            if ( rc == "ok" ) then
                -- TODO  check for file size
                local fileAttributes = file.stat ( otaFileName );
                if ( fileAttributes ) then
                    -- check file size
                    if ( updateFilesList [updateFilesListIndex].size == fileAttributes.size ) then
                        -- all fine
                        if ( updateFilesListIndex < #updateFilesList ) then
                            updateFilesListIndex = updateFilesListIndex + 1;
                            print ( "[UPDATE] updating index=" .. updateFilesListIndex );
                            node.task.post ( updateFile ); -- updates only the next file
                            return; -- don't restart
                        else
                            finishUpdate ();
                            -- restart
                        end
                    else
                        updateFailure ( "size is different requested=" .. updateFilesList [updateFilesListIndex].size .. " got=" .. fileAttributes.size );
                        -- restart
                    end
                else
                    updateFailure ( "no file attributes for " .. otaFileName );
                    -- restart
                end
            else
                updateFailure ( "http return code " .. rc .. " is not ok" );
                -- restart
            end
            node.task.post ( restart ); 
        end
    );
    
end

function updateFailure ( message )

    print ( "[UPDATE] updateFailure: msg=" .. message .. " heap=" .. node.heap () );
    
    file.remove ( updateUrlFilename );
    file.remove ( updateJsonFilename );
    
    -- TODO remove all ota_ files

end

function finishUpdate ()

    print ( "[UPDATE] finishUpdate: heap=" .. node.heap () );
    
    for i, updateFile in ipairs ( updateFilesList ) do
    
        local fileName = updateFile.name;
        print ( "[UPDATE] rename " .. fileName );
        
        local pos = fileName:find ( "%." );
        local suffix = pos and fileName:sub ( pos + 1 ) or nil;
        
        print ( "[UPDATE] pos=" .. pos .. " suffix=" .. suffix );
        
        local updateFileName = fileName;
        local lcFileName = nil;

        if ( not suffix ) then
            updateFileName = updateFileName .. LUA_POSTFIX;
            lcFileName = fileName .. LC_POSTFIX;
        elseif ( suffix == "lua" ) then
            lcFileName = fileName .. LC_POSTFIX;
        end
        
        local oldUpdateFileName = OLD_PREFIX .. updateFileName;
        local otaUpdateFileName = OTA_PREFIX .. updateFileName;

        local oldLcFileName;
        local otaLcFileName;
        if ( lcFileName ) then
            oldLcFileName = OLD_PREFIX .. lcFileName;
            otaLcFileName = OTA_PREFIX .. lcFileName;
        end

        -- TODO robuster machen!!!
                
        file.remove ( updateFileName );
        file.remove ( oldUpdateFileName );

        if ( lcFileName ) then file.remove ( lcFileName ); end
        if ( oldLcFileName ) then file.remove ( oldLcFileName ); end
        
        if ( not file.rename ( otaUpdateFileName, updateFileName  ) ) then
            print ( "[UPDATE] ERROR renaming" .. otaUpdateFileName );
            -- TODO
        end
        if ( otaLcFileName and file.exists ( otaLcFileName ) and not file.rename ( otaLcFileName, lcFileName  ) ) then
            print ( "[UPDATE] ERROR renaming" .. otaLcFileName );
            -- TODO
        end
        
    end
    
    print ( "[UPDATE] renaming " .. updateUrlFilename );
    file.remove ( OLD_PREFIX .. updateUrlFilename );
    if ( not file.rename ( updateUrlFilename, OLD_PREFIX .. updateUrlFilename  ) ) then
        print ( "[UPDATE] ERROR renaming" .. updateUrlFilename );
        -- TODO
    end

    print ( "[UPDATE] renaming " .. updateJsonFilename );
    file.remove ( OLD_PREFIX .. updateJsonFilename );
    if ( not file.rename ( updateJsonFilename, OLD_PREFIX .. updateJsonFilename  ) ) then
        print ( "[UPDATE] ERROR renaming" .. updateJsonFilename );
        -- TODO
    end
    
end

--------------------------------------------------------------------
-- public

function M.update ()

    print ( "[UPDATE] second stage of update" );
    
    wifiLoopTimer = tmr.create ();
    wifiLoopTimer:alarm ( TIMER_WIFI_PERIOD * 1000, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------