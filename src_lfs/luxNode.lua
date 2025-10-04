--------------------------------------------------------------------
--
-- nodes@home/luaNodes/luxNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.09.2025

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );

-------------------------------------------------------------------------------
--  Settings

local sdaPin = nodeConfig.appCfg.sdaPin or ( is_ESP32 and 22 or 1 );    -- yellow
local sclPin = nodeConfig.appCfg.sclPin or ( is_ESP32 and 21 or 2 );    -- white
logger:info ( "main: sdaPin=" .. tostring ( sdaPin ) .. " sclPin=" .. tostring ( sclPin ) );

local veml7700 = i2ctool.veml7700 ( sdaPin, sclPin );

local gain_index = 4;
local inttime_index = 3;
local persistance = veml7700.PERSISTENCE_PROTECT_NUMBER.n1;

local measurementtimer = tmr. create ();
local maxrefreshrate = 2000;

local restartConnection = true;

local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;

local retain = nodeConfig.mqtt.retain;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private

local function measurement ( client, topic )

    local function readvalue ()

        logger:debug ( "measurement.readvalue: ---------------------------------" );

        local lux, raw = veml7700.readAmbientLight ();

        result, gain_index, inttime_index = veml7700.validate ( raw, gain_index, inttime_index );
        logger:debug ( "measurement.readvalue: result=" .. result .. " gain_index=" .. gain_index .. " inttime_index=" .. inttime_index );

        if ( result == "adjust" ) then
            veml7700.setConfiguration ( veml7700.GAIN [gain_index], veml7700.INT_TIME [inttime_index], persistance );
            measurementtimer:start ();
        else
            logger:notice ( "measurement.readvalue: finished result=" .. result .. " lux=" .. lux .. " raw=" .. raw );
            veml7700.poweroff ();
            client:publish ( topic .. "/value/ambientlight", lux, qos, retain );
        end

    end

    veml7700.setConfiguration ( veml7700.GAIN [gain_index], veml7700.INT_TIME [inttime_index], persistance );
    measurementtimer:alarm ( maxrefreshrate, tmr.ALARM_SEMI, readvalue );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    local chipId = veml7700:readWordByMode ( veml7700.REG.ID );
    logger:info ( "start: chipId=" .. tohex ( chipId, 4 ) );
    assert ( chipId == 0xC481, "chipId is wrong" );

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    measurement ( client, topic );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return restartConnection;

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

    measurement ( client, topic );

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------