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

-- TODO Rückbau trace
-- TODO Aufrufe sicher machen gegen nil
-- udp server auflösen per dns
local ip = nodeConfig.syslog and nodeConfig.syslog.ip;
local port = nodeConfig.syslog and nodeConfig.syslog.port or 514;
local level =  nodeConfig.syslog and nodeConfig.syslog.level or M.SEVERITY.DEBUG;
if ( type ( level ) == "string" ) then
    level = SEVERITY [level];
end

--print ( "ip=" .. ip .. " port=" .. port .. " level=" .. level );

----------------------------------------------------------------------------------------
-- private

local syslogclient;

-- < prival > version space timestamp space hostname space appname space procid space msgid space structureddata space msg
local hostname = nodeConfig.class .. "/" .. nodeConfig.type .."/" .. nodeConfig.location;
local appname = nodeConfig.app;
local procid = nodeConfig.version;
local msgid = "-";
local syslogpattern = ("<%s>1 - %s %s %s %s - %s"):format ( "%d", hostname, appname, procid, msgid, "%s" );

local function _send ( severity, module, msg )

    --print ( "send: severity=" .. severity .. " module=" .. tostring ( module ) .. " msg=" .. tostring ( msg ) );

    if ( severity <= level ) then

        local syslogmsg = module .. "." .. tostring ( msg );

        if ( syslogclient ) then
            syslogclient:send ( port, ip, syslogpattern:format ( severity, syslogmsg ) );
        end

        local txt = { "EMERGENCY", "ALERT", "CRITICAL", "ERROR", "WARNING", "NOTICE", "INFO", "DEBUG" }
        print ( "<" .. txt [severity + 1] .. "> " .. syslogmsg );

    end

end

local q = require ( "fifo" ).new ();

local function k ( a, islast )

    if ( syslogclient ) then
        _send ( a.severity, a.module, a. msg );
        return nil, true; -- dequeue until queue is empty
    else
        return a; -- dont dequeue
    end

end

local function send ( severity, module, msg )

    q:queue ( {severity = severity, module = module, msg = msg }, k );

end

--------------------------------------------------------------------
-- public

function M.logger ( module )

    local L = {};

    function L.setOnline ()
        syslogclient = net.createUDPSocket ();
        q._go = true;
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

M.logger ( moduleName ).debug ( "loaded: ip=" .. ip .. " port=" .. port .. " level=" .. level );

return M;

-------------------------------------------------------------------------------