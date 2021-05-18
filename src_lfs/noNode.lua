--------------------------------------------------------------------
--
-- nodes@home/luaNodes/xmasNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 08.02.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.offline ( client )

    logger.info ( "offline:" );

    return true; -- restart mqtt connection

end

function M.periodic ( client, topic )

    logger.info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------
