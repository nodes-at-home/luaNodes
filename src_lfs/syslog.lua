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

local net, node = net, node;

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
M.SEVERITY = SEVERITY;

local ip;
local host = nodeConfig.syslog and nodeConfig.syslog.host;
local port = nodeConfig.syslog and nodeConfig.syslog.port or 514;
local _level =  nodeConfig.syslog and nodeConfig.syslog.level;
local level = SEVERITY.DEBUG
if ( type ( _level ) == "string" ) then
    level = SEVERITY [_level];
end

--print ( "ip=" .. ip .. " port=" .. port .. " level=" .. level );

----------------------------------------------------------------------------------------
-- private

local syslogclient;

local restart = false;

-- local mode = "online"; -- set to "offline" for developement
local mode = nodeConfig.syslog and nodeConfig.syslog.mode or "offline";
print ( "syslog: mode=" .. mode );

-- < prival > version space timestamp space hostname space appname space procid space msgid space structureddata space msg
local hostname = nodeConfig.class .. "/" .. nodeConfig.type .."/" .. nodeConfig.location;
local appname = nodeConfig.app;
local procid = nodeConfig.version;
local msgid = "-";
local syslogpattern = ("<%s>1 - %s %s %s %s - %s.%s"):format ( "%d", hostname, appname, procid, msgid, "%s", "%s" );

local function printmsg ( severity, module, msg )

    local txt = { "EMERGENCY", "ALERT", "CRITICAL", "ERROR", "WARNING", "NOTICE", "INFO", "DEBUG" };
    print ( ("<%s>%s.%s"):format ( txt [severity + 1], module, msg ) );

end

local function _send ( severity, module, msg )

    --print ( "send: severity=" .. severity .. " module=" .. module .. " msg=" .. msg );

    syslogclient:send ( port, ip, syslogpattern:format ( severity, module, msg ) );
    printmsg ( severity, module, msg );

end

local q = require ( "fifo" ).new ();

local function k ( a, islast )

    if ( syslogclient ) then
        _send ( a.severity, a.module, a. msg );
        --return nil, true; -- dequeue until queue is empty
        return nil; -- stop dequeueing, next deque call is in callback of udpsocket.on
    else
        return a; -- dont dequeue
    end

end

local function send ( severity, module, msg )

    if ( severity <= level ) then
        if ( mode == "online" ) then
            q:queue ( {severity = severity, module = tostring ( module ), msg = tostring ( msg ) }, k );
        elseif ( mode == "offline" ) then
            printmsg ( severity, module, msg );
        end
    end

end

-- This function checks if a given IP address is valid.
-- @param ip: The IP address to validate.
-- @return: Returns true if the IP address is valid, false otherwise.
-- https://codepal.ai/code-generator/query/3pyHMepp/lua-ip-address-validation-function-example
local function isIpAddress ( ip )

    -- Split the IP address into its components using '.' as the delimiter.
    local octets = {};
    for octet in ip:gmatch ( "[^.]+" ) do
        table.insert ( octets, octet );
    end

    -- An IP address must have exactly 4 octets.
    if #octets ~= 4 then
        return false;
    end

    -- Validate each octet.
    for _, octet in ipairs ( octets ) do
        -- Each octet must be a number between 0 and 255.
        if not tonumber ( octet ) or tonumber ( octet ) < 0 or tonumber ( octet ) > 255 then
            return false;
        end
        -- Check for leading zeros (e.g., "01" is invalid).
        if string.len ( octet ) > 1 and octet:sub ( 1, 1 ) == "0" then
            return false;
        end
    end

    return true;

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

function M.setOffline ()

    print ( "------------------- syslog offline ------------------------" );

    mode = "offline";

end

function M.setOnline ()

    print ( "------------------- syslog online -------------------------" );

    mode = "online";

end

function M.startOnline ()

    mode = nodeConfig.syslog.mode; -- set to initial config

    if ( mode == "online" ) then

        print ( "------------------- syslog start online -------------------" );

        syslogclient = net.createUDPSocket ();

        syslogclient:on ( "sent",
            function ( s )
                node.task.post (
                    function ()
                        local empty = not q:dequeue ( k ); -- dequeue next message
                        if ( restart and empty  ) then
                            print ( "### RESTART ###" );
                            syslogclient:close ();
                            syslogclient = nil;
                            node.task.post ( node.restart );
                        end
                    end
                );
            end
        );

        local function go ()
            _send ( SEVERITY.ALERT, moduleName, "start: goes online" ); -- dequeueing starts in udpsocket send callback
        end

        if ( isIpAddress ( host ) ) then
            print ( "IP address found: " .. host );
            ip = host;
            go ();
        else
            syslogclient:dns ( host,
                function ( s, ipaddr )
                    print ( "host=" .. host .. " ipaddr=" .. tostring ( ipaddr ) );
                    if ( ipaddr ) then
                        ip = ipaddr;
                        go ();
                    else
                        print ( "### RESTART ###" );
                        node.restart ();
                    end
                end
            );
        end

    end

end

--------------------------------------------------------------------
-- logger and his metatable

local L = {}

function L.emergency ( self, msg )
    send ( SEVERITY.EMERGENCY, self.module, msg );
end

function L.alert ( self, msg )
    send ( SEVERITY.ALERT, self.module, msg );
end

function L.critical ( self, msg )
    send ( SEVERITY.CRITICAL, self.module, msg );
end

function L.error ( self, msg )
    send ( SEVERITY.ERROR, self.module, msg );
end

function L.warning ( self, msg )
    send ( SEVERITY.WARNING, self.module, msg );
end

function L.notice ( self, msg )
    send ( SEVERITY.NOTICE, self.module, msg );
end

function L.info ( self, msg )
    send ( SEVERITY.INFO, self.module, msg );
end

function L.debug ( self, msg )
    send ( SEVERITY.DEBUG, self.module, msg );
end

function M.logger ( module )

    return setmetatable ( {module = module;}, {__index = L} );

end

-------------------------------------------------------------------------------
-- main

M.logger ( moduleName ):debug ( "loaded: server=" .. host .. ":" .. port .. " level=" .. level );

return M;

-------------------------------------------------------------------------------