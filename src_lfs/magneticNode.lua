--------------------------------------------------------------------
--
-- nodes@home/luaNodes/magneticNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 27.07.2023

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );
local lsm303dlhc = require ( "lsm303dlhc" );

local gpio, tmr = gpio, tmr;

-------------------------------------------------------------------------------
--  Settings

local sclPin = nodeConfig.appCfg.sclPin or 6;   -- white
local sdaPin = nodeConfig.appCfg.sdaPin or 5;   -- yellow
local intPin = nodeConfig.appCfg.intPin or 1;   -- green (DRDY)

local retain = 0;
local qos = nodeConfig.mqtt.qos;

local restartConnection = true;

local highThreshold = nodeConfig.appCfg.threshold and nodeConfig.appCfg.threshold.high or 100000; -- threshold for state change
local lowThreshold = nodeConfig.appCfg.threshold and nodeConfig.appCfg.threshold.low or 1000; -- threshold for state change

local delay = nodeConfig.appCfg.delay or 500; -- delay for start data conversion

----------------------------------------------------------------------------------------
-- private

local state = "high";

local shortTimer = tmr.create ();

local function startSingleDataConversion ()

    logger:debug ( "startSingleDataConversion: " );

    shortTimer:alarm ( delay, tmr.ALARM_SINGLE,
        function ()
            i2ctool.writeByte ( lsm303dlhc.REG.MR_REG_M, 0x01 ); -- 0000 0001
        end
    );

end

local function publishTick ( client, topic, val, mx, my, mz, t )

    logger:info ( "publishTick: topic=" .. topic .. " val=" .. val .. " mx=" .. mx .. " my=" .. my .. " mz=" .. mz .. " t=" .. t );

    local payload = string.format ( '{"val":%.2f,"m":{"x":%d,"y":%d,"z":%d},"t":%.2f}', val, mx, my, mz, t );
    --print ( "publishTick: payload=" .. payload );
    logger:notice ( "publishTick: payload=" .. payload );
    client:publish ( topic .. "/value/tick", payload, qos, retain, startSingleDataConversion );

end

local function initIntPin ( client, topic )

    logger:info ( "initIntPin: topic=" .. topic );

    -- read magnetic field by interrupt
    gpio.mode ( intPin, gpio.INT );
    gpio.trig ( intPin, "up",

        function ( level, when )

            local mx, my, mz = lsm303dlhc.readMagneticField ();
            local t = lsm303dlhc.readTemperature ();
            local val = math.sqrt ( mx * mx + my * my + mz * mz );

            local last = state;
            if ( val > highThreshold ) then
                state = "high"
            end
            if ( val < lowThreshold ) then
                state = "low"
            end

            --print ( string.format ( "initIntPin: state=%s val=%.2f Mx=%5d My=%5d Mz=%5d t=%.1f", state, val, mx, my, mz, t ) );
            logger:debug ( string.format ( "initIntPin: state=%s val=%.2f Mx=%5d My=%5d Mz=%5d t=%.1f", state, val, mx, my, mz, t ) );

            -- check level for next tick
            if ( last ~= state and state == "high" ) then
                publishTick ( client, topic, val, mx, my, mz, t );
            else
                startSingleDataConversion ();
            end

        end

    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    -- initialize magnetic sensor
    lsm303dlhc.init ( sdaPin, sclPin );
    initIntPin ( client, topic );

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    startSingleDataConversion ();

end

function M.offline ( client )

    logger:info ( "offline:" );

    return restartConnection; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    print ( "topic=" .. topic .. " payload=" .. payload )

    if ( topic == nodeConfig.topic .. "/service/threshold_high" ) then
        highThreshold = tonumber ( payload ) or highThreshold;
    elseif ( topic == nodeConfig.topic .. "/service/threshold_low" ) then
        lowThreshold = tonumber ( payload ) or lowThreshold;
    elseif ( topic == nodeConfig.topic .. "/service/delay" ) then
        delay = tonumber ( payload ) or delay;
    end

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------