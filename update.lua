--------------------------------------------------------------------
--
-- nodes@home/luaNodes/update
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 19.10.2016

----
-- (1) write marker file that we are in update proress, the content is the url
-- (2) restart
---
-- (3) read marker file
-- (4) get list of files
-- (5) get each new file with prefixed name "ota_"
-- (6) compile each file
-- (6a) break the update process, when compile failed
-- (7) remove all ".lc" files
-- (8) rename all old ".lua" files with prefix "old_"
-- (9) rename all new ".lua" and ".lc" files by remmoving prefix
-- (10) remove marker file
-- (11) restart
---

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local updateUrlFile = "update.url";
local updateListFile = "update.list";
local updateList = {};
local updateListIndex = 1;
local url;
local host;
local port;
local path;

local TIMER_WIFI_LOOP = 1;
local TIMER_WIFI_PERIOD = 1; -- sec

local OLD_PREFIX = "old_";
local OTA_PREFIX = "ota_";
local LUA_POSTFIX = ".lua";
local LC_POSTFIX = ".lc";

----------------------------------------------------------------------------------------
-- private

local function splitUrl ( url )

    -- http://<host>:<port>/<path>
    local urlSchemaStart = url:find ( "http://" );
    local urlHostStart = urlSchemaStart and 8 or 1;
    local urlPathStart = url:find ( "/", urlHostStart );
    local urlPortStart = url:sub ( urlHostStart, urlPathStart - 1 ):find ( ":" );
    if ( urlPortStart ) then
        urlPortStart = urlPortStart + urlHostStart;
    end 
    
    local urlPort = urlPortStart and url:sub ( urlPortStart, urlPathStart - 1 ) or 80;
    local urlHost = url:sub ( urlHostStart, urlPortStart and urlPortStart - 2 or urlPathStart - 1 );
    local urlPath = url:sub ( urlPathStart );
    
    return urlHost, urlPort, urlPath;
    
end

local function wifiLoop ()

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then

        -- Stop the loop
        tmr.stop ( TIMER_WIFI_LOOP );

        if ( file.open ( updateUrlFile ) ) then
        
            url = file.readline ();
            file.close ();
            host, port, path = splitUrl ( url );
            print ( "[UPDATE] url=" .. url .. " ,host=" .. host .. " ,port=" .. port .. " ,path=" .. path );
            
            require ( "httpDL" );
            
            httpDL.download ( host, port, path .. "/" .. updateListFile, updateListFile,
                function ()
                    if ( file.open ( updateListFile ) ) then
                        print ( "[UPDATE] open file " .. updateListFile );
                        local line = file.readline ();
                        while ( line ) do
                            line = line:gsub ( "[\n\r]+", "" );
                            if ( line ~= "" ) then
                                table.insert ( updateList, line );
                            end
                            line = file.readline ();
                        end
                    end
                    file.close ();
                    -- start task for update
                    if ( #updateList > 0 ) then -- update
                        updateListIndex = 1;
                        collectgarbage ();
                        print ( "[UPDATE] start update task chain" );
                        node.task.post ( function () updateFile () end ); -- updates only the next file
                    else -- close update
                        print ( "[UPDATE] NO update files -> FINISH" );
                        node.task.post ( 
                            function () 
                                compileAndRename (); 
                                node.restart (); 
                            end 
                        );
                    end
                end
            );
            
        end

    else
        print ( "[WIFI] Connecting..." );
    end

end

function updateFile ()

    local fileName = updateList [updateListIndex];
    local pos = fileName:find ( "%." ); -- we mean the char '.'
    local otaFileName = OTA_PREFIX .. fileName;
    if ( not pos ) then 
        fileName = fileName .. LUA_POSTFIX;
        otaFileName = otaFileName .. LUA_POSTFIX;
    end
    local fileUrl = path .. "/" .. fileName;
    
    print ( "[UPDATE] i=" .. updateListIndex .. " ,fileName=" .. fileName .. " ,url=" .. fileUrl );

    require ( "httpDL" );
        
    httpDL.download ( host, port, fileUrl, otaFileName,
        function ( rc )
            if ( rc == "ok" ) then
                if ( updateListIndex < #updateList ) then
                    updateListIndex = updateListIndex + 1;
                    print ( "[UPDATE] updating no=" .. updateListIndex );
                    node.task.post ( 
                        function () 
                            updateFile (); -- updates only the next file
                        end 
                    );
                 else
                    node.task.post ( 
                        function () 
                            compileAndRename (); 
                            node.restart (); 
                        end 
                    );
                 end
            end
        end
    );
    
end

function compileAndRename ()

    print ( "[UPDATE] compileAndRename: heap=" .. node.heap () );
    
    -- TODO activate compile

--    collectgarbage ();
--
--    for i, fileName in ipairs ( updateList ) do
--        print ( "[UPDATE] compile", fileName, "heap=", node.heap () );
--        node.compile ( OTA_PREFIX .. fileName .. LUA_POSTFIX );
--        print ( "[UPDATE] after compile heap=", node.heap () );
--        collectgarbage ();
--    end
    
    for i, fileName in ipairs ( updateList ) do

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
        end
        if ( otaLcFileName and file.exists ( otaLcFileName ) and not file.rename ( otaLcFileName, lcFileName  ) ) then
            print ( "[UPDATE] ERROR renaming" .. otaLcFileName );
        end
        
    end
    
    print ( "[UPDATE] restarting" );
    
    file.remove ( OLD_PREFIX .. updateUrlFile );
    file.remove ( OLD_PREFIX .. updateListFile );

    if ( not file.rename ( updateUrlFile, OLD_PREFIX .. updateUrlFile  ) ) then
        print ( "[UPDATE] ERROR renaming" .. updateUrlFile );
    end
    if ( not file.rename ( updateListFile, OLD_PREFIX .. updateListFile  ) ) then
        print ( "[UPDATE] ERROR renaming" .. updateListFile );
    end
    
end

--------------------------------------------------------------------
-- public

function M.update ()

    print ( "[UPDATE] second stage of update" );
    
    tmr.alarm ( TIMER_WIFI_LOOP, TIMER_WIFI_PERIOD * 1000, tmr.ALARM_AUTO, function () wifiLoop() end ); -- timer_id, interval_ms, mode
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------