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

local syslog = require ( "syslog" );
local logger = syslog.logger ( moduleName );

local node, file, net, wifi, tmr, mqtt, sjson = node, file, net, wifi, tmr, mqtt, sjson;

-------------------------------------------------------------------------------
--  Settings

UPDATE_URL_FILENAME = "update.url";
UPDATE_JSON_FILENAME = "update_files.json"

local host, port, path;

local fileList = nil;

OLD_PREFIX = "old_";
OTA_PREFIX = "ota_";
LUA_POSTFIX = ".lua";
LC_POSTFIX = ".lc";
JSON_POSTFIX = ".json";

local TIMER_WIFI_PERIOD = 1; -- sec

local wifiLoopTimer = tmr.create ();

local message = nil;

local mqttClient = nil;     -- mqtt client

local fileListIndex;
local updateTag = nil;

local host, port, path;

----------------------------------------------------------------------------------------
-- private


local function download ( host, port, url, path, callback )

    logger:info ( "download: server=" .. host .. ":" .. port .. " url=" .. url .. " path=" .. path );

    local chunkcount;

    file.remove ( path );
	file.open ( path, "w+" );

    local continueWrite = false;
    local isHttpReponseOk = false;
    local httpResponseCode = -1;

	local conn = net.createConnection ( net.TCP, 0 );

    conn:on ( "connection",
        -- request remote file
        function ( conn )
            conn:send (
                table.concat ( {
                    "GET ", url, " HTTP/1.0\r\n",
                    "Host: ", host, "\r\n",
                    "Connection: close\r\n",
                    "Accept-Charset: utf-8\r\n",
                    "Accept-Encoding: \r\n",
                    "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n",
                    "Accept: */*\r\n\r\n"
                } )
            );
        end
    );

	conn:on ( "receive",
        -- received one piece
        function ( conn, payload )
            -- logger:debug ( "download: heap=" .. node.heap () );
            -- logger:debug ( "download: payload=" .. payload );
            if ( continueWrite ) then
                chunkcount = chunkcount + 1;
                logger:debug ( "receive: write chunk " .. chunkcount );
                file.write ( payload );
                file.flush ();
            else
                -- initially write file with the first piece
                local line1 = payload:sub ( 1, payload:find ( "\r\n" ) - 1 );
                local code = line1:match ( "(%d%d%d)" );
                if ( code == "200" ) then
                    isHttpReponseOk = true;
                    local headerEnd = payload:find ( "\r\n\r\n" );
                    if (  headerEnd ) then
                        logger:debug ( "receive: initial chunk" );
                        chunkcount = 0;
                        file.write ( payload:sub ( headerEnd + 4 ) );
                        file.flush ();
                        continueWrite = true;
                    end
                else
                   httpResponseCode = code;
                end
            end
            payload = nil;
            collectgarbage ();
        end
    );

	conn:on ( "disconnection",
        -- callback function called at closing
        function ( conn )
            local response = isHttpReponseOk and "ok" or httpResponseCode;
            logger:debug ( "download: disconnection with response=" .. response );
            conn = nil;
            file.close ()
            collectgarbage ();

            callback ( response );
        end
    );

	conn:connect ( port,host );

end

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

local function updateMqttState ()

    -- Setup MQTT client and events
    if ( mqttClient == nil ) then
        local mqttClientName = wifi.sta.gethostname () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password
    end

    logger:debug ( "updateMqttState: connecting to " .. nodeConfig.mqtt.broker );

    logger:alert ( "updateMqttState: " .. nodeConfig.app .. "@" .. nodeConfig.location .. " -> " .. message );

    mqttClient:connect( nodeConfig.mqtt.broker , 1883, false, -- broker, port, secure
        function ( client )
            logger:debug ( "updateMqttState: connected to MQTT Broker" );
            logger:debug ( "updateMqttState: node=" .. nodeConfig.topic );
            -- 1) set node tag on update state topic
            local topic = "nodes@home/update/" .. node.chipid ();
            local msg = nodeConfig.app .. "@" .. nodeConfig.location;
            logger:debug ( "updateMqttState: publish topic=" .. topic .. " msg=" .. msg );
            client:publish ( topic, msg, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                -- 2) set update state
                function (client )
                    local topic = "nodes@home/update/" .. node.chipid () .. "/state";
                    logger:debug ( "updateMqttState: publish topic=" .. topic .. " msg=" .. message );
                    client:publish ( topic, message, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
                        -- 3) reset update service topic
                        function ( client )
                            local topic = nodeConfig.topic .. "/service/update";
                            logger:debug ( "updateMqttState: publish reset topic=" .. topic );
                            client:publish ( topic, "", 0, 1, -- ..., qos, retain
                                -- 4) restart
                                function ()
                                    syslog.restart ();
                                    logger:alert ( "RESTARTING" ); -- to resolve the restart flag in syslog
                                end
                            );
                        end
                    );
                end
            );
        end,
        function ( client, reason )
            logger:warning ( "updateMqttState: not connected reason=" .. reason );
        end
    );

end

local function updateFailure ()

    logger:debug ( "updateFailure: msg=" .. message .. " heap=" .. node.heap () );

    file.remove ( UPDATE_URL_FILENAME );
    file.remove ( UPDATE_JSON_FILENAME );

    -- TODO remove all ota_ files

    node.task.post ( updateMqttState );

end

local function renameUrlAndJsonFiles ()

    logger:info ( "renameUrlAndJsonFiles: heap=" .. node.heap () );

    logger:debug ( "renameUrlAndJsonFiles: renaming " .. UPDATE_URL_FILENAME );
    file.remove ( OLD_PREFIX .. UPDATE_URL_FILENAME );
    if ( not file.rename ( UPDATE_URL_FILENAME, OLD_PREFIX .. UPDATE_URL_FILENAME  ) ) then
        logger:debug ( "ERROR renaming" .. UPDATE_URL_FILENAME );
    end

    logger:debug ( "renameUrlAndJsonFiles: renaming " .. UPDATE_JSON_FILENAME );
    file.remove ( OLD_PREFIX .. UPDATE_JSON_FILENAME );
    if ( not file.rename ( UPDATE_JSON_FILENAME, OLD_PREFIX .. UPDATE_JSON_FILENAME  ) ) then
        logger:warning ( "renameUrlAndJsonFiles: ERROR renaming" .. UPDATE_JSON_FILENAME );
    end

    message = "ok: " .. message;
    node.task.post ( updateMqttState );

end

local function renameUpdateFile ()

    local fileName = fileList [fileListIndex].name;
    logger:info ( "renameUpdateFile: filename=" .. fileName .. " fileListIndex=" .. fileListIndex .. " heap=" .. node.heap () );

    local pos = fileName:find ( "%." );
    local suffix = pos and fileName:sub ( pos + 1 ) or nil;
    --logger:debug ( "renameUpdateFile: pos=" .. pos .. " suffix=" .. suffix );

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

    if ( fileListIndex < #fileList ) then -- next
        fileListIndex = fileListIndex + 1;
        node.task.post ( renameUpdateFile );
    else
        node.task.post ( renameUrlAndJsonFiles );
    end

end

local function updateCompletion ()

    logger:info ( "updateCompletion: message=" .. message .. " heap=" .. node.heap () );

    if ( fileList and #fileList > 0 ) then -- update
        fileListIndex = 1;
        node.task.post ( renameUpdateFile );
    else
        node.taks.post ( renameUrlAndJsonFiles );
    end

end

local function updateFile ()

    logger:info ( "updateFile:" );

    local fileName = fileList [fileListIndex].name;
    local pos = fileName:find ( "%." ); -- we mean the char '.'
    local otaFileName = OTA_PREFIX .. fileName;
    if ( not pos ) then
        fileName = fileName .. LUA_POSTFIX;
        otaFileName = otaFileName .. LUA_POSTFIX;
    end
    local fileUrl = path .. "/" .. fileName;

    logger:debug ( "updateFile: i=" .. fileListIndex .. " ,fileName=" .. fileName .. " ,url=" .. fileUrl );

    download ( host, port, fileUrl, otaFileName,
        function ( rc )
            if ( rc == "ok" ) then
                -- before 2.0.0 was none stat function
                local fileAttributes;
                if ( file.stat ) then
                    logger:debug ( "updateFile: file.stat exists" );
                    fileAttributes = file.stat ( otaFileName );
                else
                    logger:debug ( "updateFile: create file.stat fake" );
                    fileAttributes = { size = fileList [fileListIndex].size };
                end
                if ( fileAttributes ) then
                    -- check file size
                    if ( fileList [fileListIndex].size == fileAttributes.size ) then
                        -- all fine
                        if ( fileListIndex < #fileList ) then
                            fileListIndex = fileListIndex + 1;
                            -- logger:debug ( "updateFile: updating index=" .. fileListIndex );
                            node.task.post ( updateFile ); -- updates only the next file
                        else
                            message = "update finished normally for tag=" .. updateTag;
                            node.task.post ( updateCompletion );
                        end
                    else
                        message = "size is different for " .. fileList [fileListIndex].name .. " requested=" .. fileList [fileListIndex].size .. " got=" .. fileAttributes.size;
                        node.task.post ( updateFailure );
                    end
                else
                    message = "no file attributes for " .. otaFileName;
                    node.task.post ( updateFailure );
                end
            else
                message = "http return code " .. rc .. " is not ok for " .. fileList [fileListIndex].name;
                node.task.post ( updateFailure );
            end
        end
    );

end

local function updateFiles ()

    logger:info ( "updateFiles:" );

    if ( file.open ( UPDATE_JSON_FILENAME ) ) then
        logger:debug ( "updateFiles: open file " .. UPDATE_JSON_FILENAME );
        local payload = "";
        repeat
            local content = file.read (); -- is reading max., 1024 bytes
            if ( content ) then payload = payload .. content end
        until not content
        logger:debug ( "updateFiles: payload=" .. payload );
        local pcallOk, json = pcall ( sjson.decode, payload );
        logger:debug ( "updateFiles: pcallOk=" .. tostring ( pcallOk ) .. " result=" .. tostring ( json ) );
        if ( pcallOk ) then
            fileList = json and json.files or {};
            updateTag = json and json.tag or "unknown";
            logger:debug ( "updateFiles: json.files=" .. tostring ( json.files ) .." json.tag=" .. tostring ( json.tag ) );
            -- start task for update
            if ( fileList and #fileList > 0 ) then -- update
                fileListIndex = 1;
                logger:debug ( "updateFiles: update task chain" );
                node.task.post ( updateFile ); -- updates the next file
            else -- close update
                logger:debug ( "updateFiles: NO update files -> FINISH" );
                message = "NO update files found for tag=" .. updateTag;
                node.task.post ( updateCompletion );
            end
        else
            message = "json decode failed with error=" .. json;
            node.task.post ( updateFailure );
        end

    else

        message = "file " .. UPDATE_JSON_FILENAME .. " not to open";
        node.task.post ( updateFailure );

    end
    file.close ();

end

local function wifiLoop ()

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then

        -- Stop the loop
        wifiLoopTimer:stop ();

        syslog.setOnline ();

        -- sdk version
        local swversion = node.info ( "sw_version" );
        local major, minor, patch = swversion.node_version_major, swversion.node_version_minor, swversion.node_version_revision;
        logger:debug ( "wifiLoop: sdk=" .. major .. "." .. minor .. "." .. patch );

        if ( file.open ( UPDATE_URL_FILENAME ) ) then

            local url = file.readline ();
            file.close ();
            local _host, _port, _path = splitUrl ( url );
            logger:notice ( "wifiLoop: url=" .. tostring ( url ) .. " server=" .. tostring ( _host ) .. ":" .. tostring ( _port ) .. " path=" .. tostring ( _path ) );

            if ( _host and _port and _path ) then

                host = _host;
                port = _port;
                path = _path;

                logger:debug ( "wifiLoop: downloading file list" );

                download ( host, port, path .. "/" .. UPDATE_JSON_FILENAME, UPDATE_JSON_FILENAME,

                    function ( response ) -- "ok" or http response code
                        logger:debug ( "wifiLoop: response from httpDL is " .. response );
                        if ( response ~= "ok" ) then
                            message = "httpRsponse=" .. response;
                        end
                        node.task.post ( updateFiles );
                    end

                );
                return; -- control flow is now in callback of download

            end

        end

        logger:warning ( "wifiLoop: nothing happens, restart" );
        message = "file with update url not to open";
        node.task.post ( updateFailure );

    else
        logger:debug ( "wifiLoop: Connecting..." );
    end

end

--------------------------------------------------------------------
-- public

function M.start ()

    syslog.setLevel ( "INFO" );
    logger:info ( "start: second stage of update" );

    wifiLoopTimer:alarm ( TIMER_WIFI_PERIOD * 1000, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------