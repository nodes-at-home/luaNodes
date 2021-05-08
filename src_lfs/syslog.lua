--------------------------------------------------------------------
--
-- nodes@home/luaNodes/syslog
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 05.05.2021

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local SEVERITY = {
    EMERGENCY = 0;
    ALERT     = 1;
    CRITICAL  = 2;
    ERROR     = 3;
    WARNING   = 4;
    NOTICE    = 5;
    INFO      = 6;
    DEBUG     = 7;
};

local ip;
local host = nodeConfig.syslog and nodeConfig.syslog.host;
local port = nodeConfig.syslog and nodeConfig.syslog.port or 514;
local level =  nodeConfig.syslog and nodeConfig.syslog.level or M.SEVERITY.DEBUG;
if ( type ( level ) == "string" ) then
    level = SEVERITY [level];
end

--print ( "ip=" .. ip .. " port=" .. port .. " level=" .. level );

----------------------------------------------------------------------------------------
-- private

local syslogclient;

local restart = false;

-- < prival > version space timestamp space hostname space appname space procid space msgid space structureddata space msg
local hostname = nodeConfig.class .. "/" .. nodeConfig.type .."/" .. nodeConfig.location;
local appname = nodeConfig.app;
local procid = nodeConfig.version;
local msgid = "-";
local syslogpattern = ("<%s>1 - %s %s %s %s - %s.%s"):format ( "%d", hostname, appname, procid, msgid, "%s", "%s" );

local function _send ( severity, module, msg )

    print ( "send: severity=" .. severity .. " module=" .. tostring ( module ) .. " msg=" .. tostring ( msg ) );

    if ( severity <= level ) then

        syslogclient:send ( port, ip, syslogpattern:format ( severity, module, msg ) );

        local txt = { "EMERGENCY", "ALERT", "CRITICAL", "ERROR", "WARNING", "NOTICE", "INFO", "DEBUG" };
        print ( ("<%s>%s.%s"):format ( txt [severity + 1], module, msg ) );

    end

end

local q = require ( "fifo" ).new ();

local function k ( a, islast )

    if ( syslogclient ) then
        _send ( a.severity, a.module, a. msg );
        --return nil, true; -- dequeue until queue is empty
        return nil; -- stop dequeueing, next deque call is in callback of udpsockert.on
    else
        return a; -- dont dequeue
    end

end

local function send ( severity, module, msg )

    q:queue ( {severity = severity, module = module, msg = msg }, k );

end

--------------------------------------------------------------------
-- public

function M.restart ()
    restart = true;
end

function M.setLevel ( newLevel )

    if ( type ( newLevel ) == "string" ) then
        level = SEVERITY [newLevel];
    end

end

function M.logger ( module )

    local L = {};

    function L.setOnline ()
        print ( "------------------- syslog start -------------------" );
        syslogclient = net.createUDPSocket ();
        syslogclient:on ( "sent",
            function ( s )
                node.task.post (
                    function ()
                        local empty = not q:dequeue ( k ); -- dequeue next message
                        if ( restart and empty  ) then
                            print ( "### RESTART ###" );
                            node.restart ();
                        end
                    end
                );
            end
        );
        syslogclient:dns ( host,
            function ( s, ipaddr )
                print ( "ipaddr=" .. tostring ( ipaddr ) );
                ip = ipaddr;
                _send ( SEVERITY.ALERT, moduleName, "start: goes online" ); -- dequeueing starts inudpsocket send callback
            end
        );
    end

    function L.emergency ( msg )
        send ( SEVERITY.EMERGENCY, module, msg );
    end

    function L.alert ( msg )
        send ( SEVERITY.ALERT, module, msg );
    end

    function L.critical (  msg )
        send ( SEVERITY.CRITICAL, module, msg );
    end

    function L.error ( msg )
        send ( SEVERITY.ERROR, module, msg );
    end

    function L.warning ( msg )
        send ( SEVERITY.WARNING, module, msg );
    end

    function L.notice ( msg )
        send ( SEVERITY.NOTICE, module, msg );
    end

    function L.info ( msg )
        send ( SEVERITY.INFO, module, msg );
    end

    function L.debug ( msg )
        send ( SEVERITY.DEBUG, module, msg );
    end

    return L;

end

-------------------------------------------------------------------------------
-- main

M.logger ( moduleName ).debug ( "loaded: server=" .. host .. ":" .. port .. " level=" .. level );

return M;

-------------------------------------------------------------------------------