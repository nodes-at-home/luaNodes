--
-- nodes@home/luaNodes/updateWifi
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

local wifiLoopTimer = nil;
local TIMER_WIFI_PERIOD = 1; -- sec

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

local function wifiLoop ()

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then

        -- Stop the loop
        wifiLoopTimer:stop ();

        logger.setOnline ();

        -- sdk version
        local major, minor, patch = node.info ();
        logger.debug ( "wifiLoop: sdk=" .. major .. "." .. minor .. "." .. patch );

        if ( file.open ( update.UPDATE_URL_FILENAME ) ) then

            local url = file.readline ();
            file.close ();
            local host, port, path = splitUrl ( url );
            logger.notice ( "wifiLoop: url=" .. tostring ( url ) .. " server=" .. tostring ( host ) .. ":" .. tostring ( port ) .. " path=" .. tostring ( path ) );

            if ( host and port and path ) then

                update.host = host;
                update.port = port;
                update.path = path;

                logger.debug ( "wifiLoop: downloading file list" );

                require ( "httpDL" );
                httpDL.download ( host, port, path .. "/" .. update.UPDATE_JSON_FILENAME, update.UPDATE_JSON_FILENAME,

                    function ( response ) -- "ok" or http response code
                        logger.debug ( "wifiLoop: response from httpDL is " .. response );
                        if ( response == "ok" ) then
                            -- node.task.post ( startLoop );
                            update.unrequire ( "httpDL" );
                            node.task.post ( function () update.next ( moduleName, "updateFiles" ) end );
                        else
                            -- updateFailure ( "httpRsponse=" .. response );
                            node.task.post ( function () update.next ( moduleName, "updateFailure", "httpRsponse=" .. response ) end );
                        end
                    end

                );
                return; -- control flow is now in callback of httpDL

            end

        end

        logger.warning ( "wifiLoop: nothing happens, restart" );
        -- updateFailure ( "file with update url not to open" );
        node.task.post ( function () update.next ( moduleName, "updateFailure", "file with update url not to open" ) end );

    else
        logger.debug ( "wifiLoop: Connecting..." );
    end

end

--------------------------------------------------------------------
-- public

function M.start ()

    logger.info ( "start:" );

    wifiLoopTimer = tmr.create ();
    wifiLoopTimer:alarm ( TIMER_WIFI_PERIOD * 1000, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------