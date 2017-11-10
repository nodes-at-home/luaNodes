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

require ( "apds9960" );

-------------------------------------------------------------------------------
--  settings

local sdaPin = nodeConfig.appCfg.sdaPin;
local sclPin = nodeConfig.appCfg.sclPin;
local intPin = nodeConfig.appCfg.triggerPin;

local readByte = apds9960.readByte;
local writeByte = apds9960.writeByte;
local setBit = apds9960.setBit;
local setBits = apds9960.setBits;
local isBit = apds9960.isBit;
local set16BitThreshold = apds9960.set16BitThreshold;

local offDelay = nodeConfig.timer.offDelay or 2000;

----------------------------------------------------------------------------------------
-- private

----------------------------------------------------------------------------------------
-- helper

local function tohex ( byte, len )

    return "0x" .. string.format( "%0" .. (len or 2) .. "X", byte );
    
end

local function publishAmbientJson ( client, topic )

    -- sensing ambient light
    local cdata = readByte ( apds9960.REG.CDATAL ) + 256 * readByte ( apds9960.REG.CDATAH );
    local rdata = readByte ( apds9960.REG.RDATAL ) + 256 * readByte ( apds9960.REG.RDATAH );
    local gdata = readByte ( apds9960.REG.GDATAL ) + 256 * readByte ( apds9960.REG.GDATAH );
    local bdata = readByte ( apds9960.REG.BDATAL ) + 256 * readByte ( apds9960.REG.BDATAH );

    local json = table.concat (
        {
            "{",
            [["clear":]], cdata, ",",
            [["red":]], rdata, ",",
            [["green":]], gdata, ",",
            [["blue":]], bdata,
            "}"
        }
    );
    print ( "[APP] json=" .. json );
    
    client:publish ( topic .. "/value/ambient", json, 0, 0,  -- qos, NO retain!!!
        function ( client )
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] started with topic=" .. topic );
    
    apds9960.init ( sdaPin, sclPin );
    
    gpio.mode ( intPin, gpio.INT );
    gpio.trig ( intPin, "down",
    
        function ( level, when ) -- when is in us
    
            print (
                table.concat (
                    { 
                        "interrupt: level=", level, 
                        "when=", when,
                        "proximity=", readByte ( apds9960.REG.PDATA ),
--                        "cdate=", tohex ( readByte ( apds9960.REG.CDATAL ) + 16 * readByte ( apds9960.REG.CDATAH ), 4 ),
--                        "rdate=", tohex ( readByte ( apds9960.REG.RDATAL ) + 16 * readByte ( apds9960.REG.RDATAH ), 4 ),
--                        "gdate=", tohex ( readByte ( apds9960.REG.GDATAL ) + 16 * readByte ( apds9960.REG.GDATAH ), 4 ),
--                        "bdate=", tohex ( readByte ( apds9960.REG.BDATAL ) + 16 * readByte ( apds9960.REG.BDATAH ), 4 ),
--                        "enable=", registerBits ( readByte ( apds9960.REG.ENABLE ), ENABLE_FIELDS );
--                        "status=", registerBits ( readByte ( apds9960.REG.STATUS ), STATUS_FIELDS );
                    },
                    " "
                )
            );

            print ( "[APP] publish button press ON" );
            client:publish ( topic .. "/value/state", "ON", 0, 0,  -- qos, NO retain!!!
                function ( client ) 
                    tmr:create ():alarm ( offDelay, tmr.ALARM_SINGLE,
                        function ()
                            print ( "[APP] publish button press OFF" );
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

--    setBits ( apds9960.REG.CONTROL, 3, 2, 3 );                              -- ENABLE<3:2> proximity gain, 3 -> apds9960.PGAIN_8X
--    writeByte ( apds9960.REG.PIHT, 20 );                                    -- proximity interrupt high threshold
--    writeByte ( apds9960.REG.PERS, 0x81 );                                  -- PERS<7:4> proximity interrupt persistence, 0 means every cycle; PERS<3:0> ALS interrupt persistence

end

function M.connect ( client, topic )

    print ( "[APP] connected: topic=" .. topic );
    
    setBit ( apds9960.REG.ENABLE, 3 );                                      -- wait enable, only usefull, when ALS is activated?
    setBit ( apds9960.REG.ENABLE, 5 );                                      -- ENABLE<5> proximity interrupt enable
    setBit ( apds9960.REG.ENABLE, 0 );                                      -- ENABLE<0> power on
    setBit ( apds9960.REG.ENABLE, 2 );                                      -- ENABLE<2> proximity enable
--    setBit ( apds9960.REG.ENABLE, 4 );                                      -- ENABLE<4> ALS interrupt enable
    setBit ( apds9960.REG.ENABLE, 1 );                                      -- ENABLE<1> ALS enable

    -- dont publish ambient light here, all values are 0
    -- publishAmbientJson ( client, topic );

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );
    
end

function M.offline ( client )

    print ( "[APP] offline" );
    
    return true; -- restart mqtt connection
    
end

function M.periodic ( client, topic )
	
    print ( "[APP] periodic: topic=" .. topic );
    
    publishAmbientJson ( client, topic );
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName );

return M;

-------------------------------------------------------------------------------
