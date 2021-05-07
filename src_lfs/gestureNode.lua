--------------------------------------------------------------------
--
-- nodes@home/luaNodes/gestureNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.10.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );
local apds9960 = require ( "apds9960" );

-------------------------------------------------------------------------------
--  settings

local sdaPin = nodeConfig.appCfg.sdaPin;
local sclPin = nodeConfig.appCfg.sclPin;
local intPin = nodeConfig.appCfg.triggerPin;

local readByte = i2ctool.readByte;
local writeByte = i2ctool.writeByte;
local setBit = i2ctool.setBit;
local setBits = i2ctool.setBits;
local isBit = i2ctool.isBit;
local readWord = i2ctool.readWord;
--local registerBits = i2ctool.registerBits;

local offDelay = nodeConfig.timer.offDelay or 2000;
local proximityPeristence = nodeConfig.appCfg.proximityPersistence or 4;
local proximityThreshold = nodeConfig.appCfg.proximityThreshold or 20;

----------------------------------------------------------------------------------------
-- private

local function publishAmbientJson ( client, topic )

    logger.info ( "publishAmbientJson: topic=" .. topic );

    -- sensing ambient light
    local cdata = readWord ( apds9960.REG.CDATAH, apds9960.REG.CDATAL );
    local rdata = readWord ( apds9960.REG.RDATAH, apds9960.REG.RDATAL );
    local gdata = readWord ( apds9960.REG.GDATAH, apds9960.REG.GDATAL );
    local bdata = readWord ( apds9960.REG.BDATAH, apds9960.REG.BDATAL );

    local json = table.concat (
        {
            "{",
            [["ambient":]], cdata, ",",
            [["red":]], rdata, ",",
            [["green":]], gdata, ",",
            [["blue":]], bdata,
            "}"
        }
    );
    logger.debug ( "publishAmbientJson: json=" .. json );

    client:publish ( topic .. "/value/ambient", json, 0, 0,  -- qos, NO retain!!!
        function ( client )
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger.info ( "start: topic=" .. topic );

    apds9960.init ( sdaPin, sclPin );

    gpio.mode ( intPin, gpio.INT );
    gpio.trig ( intPin, "down",

        function ( level, when ) -- when is in us

--            logger.debug (
--                table.concat (
--                    {
--                        "start: "
--                        "interrupt: level=", level,
--                        "when=", when,
--                        "proximity=", readByte ( apds9960.REG.PDATA ),
--                        "cdate=", readWord ( apds9960.REG.CDATAH, apds9960.REG.CDATAL );
--                        "rdate=", readWord ( apds9960.REG.RDATAH, apds9960.REG.RDATAL );
--                        "gdate=", readWord ( apds9960.REG.GDATAH, apds9960.REG.GDATAL );
--                        "bdate=", readWord ( apds9960.REG.BDATAH, apds9960.REG.BDATAL );
--                        "enable=", registerBits ( readByte ( apds9960.REG.ENABLE ), apds9960.ENABLE_BITS );
--                        "status=", registerBits ( readByte ( apds9960.REG.STATUS ), apds9960.STATUS_BITS );
--                    },
--                    " "
--                )
--            );

            logger.debug ( "start: publish button press ON" );
            client:publish ( topic .. "/value/state", "ON", 0, 0,  -- qos, NO retain!!!
                function ( client )
                    tmr:create ():alarm ( offDelay, tmr.ALARM_SINGLE,
                        function ()
                            logger.debug ( "start: publish button press OFF" );
                            client:publish ( topic .. "/value/state", "OFF", 0, 0, -- qos, NO retain!!!
                                function ( client )
                                    -- clear all interrupts
                                    readByte ( apds9960.REG.AICLEAR );
                                end
                            );
                        end
                    );
                end
            );

        end
    );

--    setBits ( apds9960.REG.CONTROL, 3, 2, 3 );                            -- ENABLE<3:2> proximity gain, 3 -> apds9960.PGAIN_8X
    writeByte ( apds9960.REG.PIHT, proximityThreshold );                                    -- proximity interrupt high threshold
    setBits ( apds9960.REG.PERS, 7, 4, proximityPeristence );               -- PERS<7:4> proximity interrupt persistence, 0 means every cycle, 1 .. 15

end

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    setBit ( apds9960.REG.ENABLE, 3 );                                      -- wait enable, only usefull, when ALS is activated?
    setBit ( apds9960.REG.ENABLE, 5 );                                      -- ENABLE<5> proximity interrupt enable
    setBit ( apds9960.REG.ENABLE, 0 );                                      -- ENABLE<0> power on
    setBit ( apds9960.REG.ENABLE, 2 );                                      -- ENABLE<2> proximity enable
--    setBit ( apds9960.REG.ENABLE, 4 );                                      -- ENABLE<4> ALS interrupt enable
    setBit ( apds9960.REG.ENABLE, 1 );                                      -- ENABLE<1> ALS enable

    -- dont publish ambient light here, all values are 0
    --publishAmbientJson ( client, topic );

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.offline ( client )

    logger.debug ( "offline:" );

    return true; -- restart mqtt connection

end

function M.periodic ( client, topic )

    logger.info ( "periodic: topic=" .. topic );

    publishAmbientJson ( client, topic );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------
