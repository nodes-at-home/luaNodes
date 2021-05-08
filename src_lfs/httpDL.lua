--------------------------------------------------------------------
--
-- nodes@home/luaNodes/httpDownload
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
-- from https://github.com/Manawyrm/ESP8266-HTTP/blob/master/httpDL.lua
--------------------------------------------------------------------
-- junand 25.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------

function M.download ( host, port, url, path, callback )

    logger.info ( "download: server=" .. host .. ":" .. port .. " url=" .. url .. " path=" .. path );

	file.remove ( path );
	file.open ( path, "w+" );

    continueWrite = false;
    isHttpReponseOk = false;
    httpResponseCode = -1;

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
            -- logger.debug ( "download: heap=" .. node.heap () );
            -- logger.debug ( "download: payload=" .. payload );
            if ( continueWrite ) then
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
            logger.debug ( "download: disconnection with response=" .. response );
            conn = nil;
            file.close ()
            collectgarbage ();

            callback ( response );
        end
    );

	conn:connect ( port,host );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------
