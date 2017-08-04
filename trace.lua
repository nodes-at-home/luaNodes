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

traceSocket = nil;

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.on ()

    if ( traceSocket == nil ) then
    
        traceSocket = net.createConnection ( net.TCP, 0 ); -- no secure
        print ( "[TRACE] connecting to " .. nodeConfig.trace.ip .. ":" .. nodeConfig.trace.port );
        traceSocket:connect ( nodeConfig.trace.port, nodeConfig.trace.ip );
        
        traceSocket:on ( "connection", 
            function ( socket, errorCode )
                socket:send ( node.chipid () .. "#***" .. node.chipid () .. " is tracing ***\n"  );
                -- redirect
                node.output ( 
                    function ( s )
                        if ( s and s ~= "\n" ) then
                            if ( socket ) then
                                socket:send ( node.chipid () .. "#" .. s .. "\n" );
                            end
                        end
                    end,
                    1               -- additional serial out  
                ); 
            end 
        );
        
        traceSocket:on ( "disconnection",
            function ( socket, errorCode )
                print ( "[TRACE] disconnection errorCode= " .. errorCode );
                traceSocket = nil;
                node.output ( nil );
                -- TODO reconnect here?
            end
        );
        
    end  

end

function M.off ( delayedCallback )

    print ( "[TRACE] off with callback " .. tostring ( delayedCallback ) );
    
    if ( traceSocket ) then
        traceSocket:send ( node.chipid () .. "#***" .. node.chipid () .. " tracing ENDS ***\n"  );
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