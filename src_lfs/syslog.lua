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
    ["EMERGENCY"]   = 0;
    ["ALERT"]       = 1;
    ["CRITICAL"]    = 2;
    ["ERROR"]       = 3;
    ["WARNING"]     = 4;
    ["NOTICE"]      = 5;
    ["INFO"]        = 6;
    ["DEBUG"]       = 7;
};

-- TODO in espConfig und default config anpassen
-- TODO Rückbau trace
-- TODO Puffer für offline Phasen
-- TODO Aufrufe sicher machen gegen nil
local ip = nodeConfig.syslog and nodeConfig.syslog.ip;
local port = nodeConfig.syslog and nodeConfig.syslog.port or 514;
local level =  nodeConfig.syslog and nodeConfig.syslog.level or M.SEVERITY.DEBUG;
if ( type ( level ) == "string" ) then
    level = SEVERITY [level];
end

--print ( "ip=" .. ip .. " port=" .. port .. " level=" .. level );

----------------------------------------------------------------------------------------
-- private

local syslogclient = net.createUDPSocket ();

-- < prival > version space timestamp space hostname space appname space procid space msgid space structureddata space msg
local hostname =nodeConfig.class .. "/" .. nodeConfig.type .."/" .. nodeConfig.location;
local appname = nodeConfig.app;
local procid = nodeConfig.version;
local msgid = "-";
local syslogpattern = ("<%s>1 - %s %s %s %s - %s"):format ( "%d", hostname, appname, procid, msgid, "%s" );

local function send ( severity, module, msg )

    --print ( "send: severity=" .. severity .. " module=" .. tostring ( module ) .. " msg=" .. tostring ( msg ) );

    if ( severity <= level ) then

        local syslogmsg = module .. "." .. tostring ( msg );

        if ( syslogclient ) then
            syslogclient:send ( port, ip, syslogpattern:format ( severity, syslogmsg ) );
        end

        local txt = { "EMERGENCY", "ALERT", "CRITICAL", "ERROR", "WARNING", "NOTICE", "INFO", "DEBUG" }
        print ( "[" .. txt [severity + 1] .. "] " .. syslogmsg );

    end

end

--------------------------------------------------------------------
-- public

function M.emergency ( module, msg )

    send ( SEVERITY.EMERGENCY, module, msg );

end

function M.alert ( module, msg )

    send ( SEVERITY.ALERT, module, msg );

end

function M.critical ( module, msg )

    send ( SEVERITY.CRITICAL, module, msg );

end

function M.error ( module, msg )

    send ( SEVERITY.ERROR, module, msg );

end

function M.warning ( module, msg )

    send ( SEVERITY.WARNING, module, msg );

end

function M.notice ( module, msg )

    send ( SEVERITY.NOTICE, module, msg );

end

function M.info ( module, msg )

    send ( SEVERITY.INFO, module, msg );

end

function M.debug ( module, msg )

    send ( SEVERITY.DEBUG, module, msg );

end

-------------------------------------------------------------------------------
-- main

M.debug ( moduleName, "loaded:" );

return M;

-------------------------------------------------------------------------------