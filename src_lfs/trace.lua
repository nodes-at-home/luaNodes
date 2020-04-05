--------------------------------------------------------------------
--
-- nodes@home/luaNodes/ttrace
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 04.08.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local CALLBACK_DELAY = 5*1000; -- ms

local ip = nodeConfig.trace and nodeConfig.trace.ip;
local port = nodeConfig.trace and nodeConfig.trace.port;

local traceSocket = nil;

----------------------------------------------------------------------------------------
-- private

local starting = false;

--------------------------------------------------------------------
-- public

function M.isStarting ()

    return starting;
    
end

function M.on ()

    if ( traceSocket == nil ) then
    
        if ( ip and port ) then

            print ( "[TRACE] connecting to " .. ip .. ":" .. port );
    
            starting = true;
    
            traceSocket = net.createConnection ( net.TCP, 0 ); -- no secure
            traceSocket:connect ( nodeConfig.trace.port, nodeConfig.trace.ip );
            
            traceSocket:on ( "connection", 
                function ( socket, errorCode )
                    socket:send ( node.chipid () .. "#***" .. node.chipid () .. " is tracing ***###"  );
                    -- redirect
                    node.output ( 
                        function ( s )
                            if ( s and s ~= "\n" ) then
                                if ( socket ) then
                                    socket:send ( node.chipid () .. "#" .. s .. "###" );
                                end
                            end
                        end,
                        1               -- additional serial out  
                    ); 
                    starting = false;
                end 
            );
            
            traceSocket:on ( "disconnection",
                function ( socket, errorCode )
                    node.output ( nil );
                    traceSocket = nil;
                    print ( "[TRACE] disconnection errorCode= " .. tostring ( errorCode ) );
                    starting = false;
                    -- TODO reconnect here?
                end
            );
            
        else
            
            print ( "[TRACE] parameter undefined ip=" .. tostring ( ip ) .. " port=" .. tostring ( port ) );

        end
        
    end  

end

function M.off ( delayedCallback )

    print ( "[TRACE] off with callback " .. tostring ( delayedCallback ) );
    
    if ( traceSocket ) then
        traceSocket:send ( node.chipid () .. "#***" .. node.chipid () .. " tracing ENDS ***###"  );
        traceSocket:close ();
        traceSocket = nil;
        node.output ( nil );
    end
    
    if ( delayedCallback ) then
        tmr.create ():alarm ( CALLBACK_DELAY, tmr.ALARM_SINGLE, delayedCallback ); -- timer_id, interval_ms, mode
    end    

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------