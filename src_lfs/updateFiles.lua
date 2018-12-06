--
-- nodes@home/luaNodes/updateFiles
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

local updateFilesListIndex = 1;
local updateTag = nil;

----------------------------------------------------------------------------------------
-- private


local function next ( nextModule, msg )

    update.unrequire ( "httpDL" );
    
    node.task.post ( 
        function () 
            update.next ( moduleName, nextModule, msg ) 
        end 
    );

end

local function updateFailure ( msg )

    next ( "updateFailure", msg ); 

end

local function updateCompletion ( msg )

    next ( "updateCompletion", msg ); 

end

local function updateFile ()

    local fileName = update.filesList [updateFilesListIndex].name;
    local pos = fileName:find ( "%." ); -- we mean the char '.'
    local otaFileName = update.OTA_PREFIX .. fileName;
    if ( not pos ) then 
        fileName = fileName .. update.LUA_POSTFIX;
        otaFileName = otaFileName .. update.LUA_POSTFIX;
    end
    local fileUrl = update.path .. "/" .. fileName;
    
    print ( "[UPDATE] i=" .. updateFilesListIndex .. " ,fileName=" .. fileName .. " ,url=" .. fileUrl );

    require ( "httpDL" );
    httpDL.download ( update.host, update.port, fileUrl, otaFileName,
        function ( rc )
            if ( rc == "ok" ) then
                -- before 2.0.0 was none stat function
                local fileAttributes;
                if ( file.stat ) then
                    print ( "[UPDATE] file.stat exists" );
                    fileAttributes = file.stat ( otaFileName );
                else
                    print ( "[UPDATE] create file.stat fake" );
                    fileAttributes = { size = update.filesList [updateFilesListIndex].size };
                end
                if ( fileAttributes ) then
                    -- check file size
                    if ( update.filesList [updateFilesListIndex].size == fileAttributes.size ) then
                        -- all fine
                        if ( updateFilesListIndex < #update.filesList ) then
                            updateFilesListIndex = updateFilesListIndex + 1;
                            -- print ( "[UPDATE] updating index=" .. updateFilesListIndex );
                            node.task.post ( updateFile ); -- updates only the next file
                        else
                            updateCompletion ( "update finished normally for tag=" .. updateTag );
                        end
                    else
                        updateFailure ( "size is different for " .. update.filesList [updateFilesListIndex].name .. " requested=" .. update.filesList [updateFilesListIndex].size .. " got=" .. fileAttributes.size );
                    end
                else
                    updateFailure ( "no file attributes for " .. otaFileName );
                end
            else
                updateFailure ( "http return code " .. rc .. " is not ok for " .. update.filesList [updateFilesListIndex].name );
            end
        end
    );
    
end

--------------------------------------------------------------------
-- public

function M.start ()

    print ( "[" .. moduleName .. "] start" );

    if ( file.open ( update.UPDATE_JSON_FILENAME ) ) then
        print ( "[UPDATE] open file " .. update.UPDATE_JSON_FILENAME );
        local payload = "";
        repeat
            local content = file.read (); -- is rading max., 1024 bytes
            if ( content ) then payload = payload .. content end 
        until not content        
        print ( "[UPDATE] payload=" .. payload );
        local pcallOk, json = pcall ( sjson.decode, payload );
        print ( "[UPDATE] pcall: pcallOk=" .. tostring ( pcallOk ) .. " result=" .. tostring ( json ) );
        if ( pcallOk ) then
            update.filesList = json and json.files or {};
            updateTag = json and json.tag or "unknown";
            print ( "[UPDATE] json.files=" .. tostring ( json.files ) .." json.tag=" .. tostring ( json.tag ) );
            -- start task for update
            if ( update.filesList and #update.filesList > 0 ) then -- update
                updateFilesListIndex = 1;
                print ( "[UPDATE] start update task chain" );
                node.task.post ( updateFile ); -- updates the next file
            else -- close update
                print ( "[UPDATE] NO update files -> FINISH" );
                updateCompletion ( "NO update files found for tag=" .. updateTag );
            end
        else
            updateFailure ( "json decode failed with error=" .. json );
        end
        
    else
    
        updateFailure ( "file " .. update.UPDATE_JSON_FILENAME .. " not to open" );
        
    end
    file.close ();
                                
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------