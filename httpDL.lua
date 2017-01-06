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

function M.download ( host, port, url, path, callback )

--    print ( "[DL] host=", host, "port=", port, "url=", url, "path=", path );

	file.remove ( path );
	file.open ( path, "w+" );

    continueWrite = false;
    isHttpReponseOk = false;
    httpResponseCode = -1;
    
	local conn = net.createConnection ( net.TCP, false );
	
    conn:on ( "connection", 
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
        function ( conn, payload )
            if ( continueWrite ) then
                file.write ( payload );
                file.flush ();
            else
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
        function ( conn ) 
            conn = nil;
            file.close ()
            callback ( isHttpReponseOk and "ok" or httpResponseCode );
        end
    );

	conn:connect ( port,host );

end

print ( "[MODULE] loaded", moduleName )

return M;