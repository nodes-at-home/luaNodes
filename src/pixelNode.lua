--------------------------------------------------------------------
--
-- nodes@home/luaNodes/pixelNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 26.04.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local pixel = require ( "pixel" );

-------------------------------------------------------------------------------
--  Settings

local csPin = nodeConfig.appCfg.csPin;
local shakePeriod = nodeConfig.timer.shakePeriod;

local numberOfModules = nodeConfig.appCfg.modules or 1;

local displayCategory = "time";

local SNTP = nodeConfig.appCfg.sntpServer or "de.pool.ntp.org" or "192.168.2.1";

local displayBrightness = 3;
local standardDisplayCategoryPeriod = 15;
local displayCategoryPeriod = standardDisplayCategoryPeriod;
local displayEnabled = {};
local displayMessage = {};

local displayCategoryPeriodCounter = 1;

----------------------------------------------------------------------------------------
-- private

local function correctTimezone ( utc )

    local tm = rtctime.epoch2cal ( utc );
    local m = tm ["mon"];

    local isCest;
    if ( m == 1 or m == 2 or m == 11 or m == 12 ) then              -- CET
        isCest = false;
    elseif ( m >= 4 and m <=9 ) then                                -- CEST
        isCest = true;
    elseif ( m == 3 or m == 10 ) then                               -- CEST -> CES / CES -> CEST
        isCest = (m == 10);                                         -- on beginning of october is CEST
        if ( tm ["day"] > 24 ) then                                 -- last week in march or october
            if ( tm ["wday"] + 31 - tm ["day"] < 8 ) then           -- it is sunday or behind
                isCest = not isCest;                                -- we are in the new/next "time zone"
                if ( tm ["wday"] == 1 and tm ["hour"] < 1 ) then    -- uups, it is sunday before time is changing
                    isCest = not isCest;                            -- a little bit summer- or winter time
                end
            end
        end
    end
    
    return utc + ( isCest and 2 * 60 * 60 or 60 * 60 ); -- +2h (cest) or +1h (cet) 
    
end

local loop;

local function handleCategory ( category, clear, text, printFunc, insertCol )

    --print ( "[APP] handleCategory: category=" .. category .. " text=" .. tostring ( text ) .. " enabled=" .. tostring ( displayEnabled [category] ) .. " heap=" .. node.heap () );

    if ( text ~= nil and ( displayEnabled [category] == nil or displayEnabled [category] ) ) then
        if ( clear ) then
            pixel.clear ();
        end            
        if ( printFunc ) then
            printFunc ( text, insertCol );
        else
            local len, cols = pixel.printAndShakeString ( text );
            local ticks = standardDisplayCategoryPeriod * 1000 / shakePeriod;
            if ( (len - cols) > ticks ) then
                local period = math.floor ( (len - cols) * shakePeriod / 1000 + 1 );
                displayCategoryPeriod = period;
            end
        end
    else
        -- process next category, the category is computed in loop
        displayCategoryPeriod = standardDisplayCategoryPeriod;
        displayCategoryPeriodCounter = displayCategoryPeriod;
        node.task.post ( loop );
    end

end

loop = function () -- every 1sec

    --print ( "[APP] loop: category=" .. tostring ( displayCategory ) ..  " heap=" .. node.heap () );

    if ( displayCategory == "time" ) then -- toggle colon
        local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
        local sign = tm ["sec"] % 2 == 0 and ":" or " ";
        handleCategory ( displayCategory, false, string.format ( "%02d%s%02d", tm ["hour"], sign, tm ["min"] ), pixel.printDateTimeString, 22 );
    end
    
    displayCategoryPeriodCounter = displayCategoryPeriodCounter + 1;
    
    if ( displayCategoryPeriodCounter > displayCategoryPeriod ) then

        displayCategoryPeriodCounter = 1;
        displayCategoryPeriod = standardDisplayCategoryPeriod;
        
        -- split between state transitions and display routines, so displayCategory is every time the current category !

        if ( displayCategory == "time" ) then
            displayCategory = "date";
        elseif ( displayCategory == "date" ) then
            displayCategory = "msg1";
        elseif ( displayCategory:sub ( 1, 3 ) == "msg" ) then
            local i = tonumber ( displayCategory:sub ( 4 ) );
            if ( i < 20 ) then
                displayCategory = "msg" .. (i + 1);
            else
                displayCategory = "time";
            end
        else
            displayCategory = "time";
        end

        if ( displayCategory == "time" ) then
            local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
            local sign = tm ["sec"] % 2 == 0 and ":" or " ";
            handleCategory ( displayCategory, true, string.format ( "%02d%s%02d", tm ["hour"], sign, tm ["min"] ), pixel.printDateTimeString, 22 );
        elseif ( displayCategory == "date" ) then
            local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
            handleCategory ( displayCategory, true, string.format ( "%02d.%02d.%04d", tm ["day"], tm ["mon"], tm ["year"] ), pixel.printDateTimeString, 10 );
        elseif ( displayCategory:sub ( 1, 3 ) == "msg" ) then
            local i = tonumber ( displayCategory:sub ( 4 ) );
            handleCategory ( displayCategory, true, displayMessage [i] );
        else
            displayCategory = "time";
        end

    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
    pixel.init ( csPin, numberOfModules, shakePeriod, displayBrightness );
    
end

function M.connect ( client, topic )

    print ( "[APP] connect: topic=" .. topic );
    
    -- subscribe to .../message/#
    -- subscription to .../command and .../alert is not necessary
    
    local t = topic .. "/message/#";
    --print ( "[APP] subscripe to topic=" .. t );
    client:subscribe ( t, 0, -- ..., qos
        function ( client )
            print ( "[APP] syncing to server=" .. SNTP );
            sntp.sync ( SNTP, 
                function ( sec, usec )
                    print ( "[APP] setting time to sec=" .. sec .. " usec=" .. usec );
                    rtctime.set ( sec, usec );
                    tmr.create ():alarm ( 1000, tmr.ALARM_AUTO, loop );
                end,                
                function ()
                    print ( "[APP] sntp sync failed" );
                    node.task.post ( function () M.connect ( client, topic ) end );
                end,                        
                1       -- autorepeat
            );
        end
    );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

function M.message ( client, topic, payload )

    --print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );
    
    print ( "[APP] message: heap=" .. node.heap () );
    
    local detailTopic = topic:sub ( nodeConfig.topic:len () + 1 );

    if ( detailTopic == "/command" or detailTopic:sub ( 1, 8 ) == "/message" ) then
    
        local ok, json = pcall ( sjson.decode, payload );
        if ( ok ) then
        
            if ( json.display ) then
                if ( json.display.duration ) then
                    print ( "[APP] duration=" .. json.display.duration ); 
                    standardDisplayCategoryPeriod = json.display.duration;
                end
                if ( json.display.brightness ) then
                    print ( "[APP] brightness=" .. json.display.brightness ); 
                    displayBrightness = json.display.brightness;
                    pixel.setBrightness ( displayBrightness );
                end
                if ( json.display.time ) then
                    --print ( "[APP] time=" .. json.display.time );
                    displayEnabled.time = (json.display.time == "on") and nil;
                end
                if ( json.display.date ) then
                    --print ( "[APP] date=" .. json.display.date ); 
                    displayEnabled.date = (json.display.date == "on") and nil;
                end
                if ( json.display.enabled ) then
                    --print ( "[APP] enabled" ); 
                    for i, v in ipairs ( json.display.enabled ) do
                        --print ( "[APP] enabled i=" .. i .. " value=" .. v ); 
                        displayEnabled ["msg" .. i] = (v == "on") and nil;
                    end
                end
            end            
 
            if ( json.messages ) then
                for i, m in ipairs ( json.messages ) do
                    local l = m.line + 1;
                    if ( m.clear ) then
                        displayMessage [l] = nil;
                    elseif ( m.text ) then
                        displayMessage [l] = m.text;
                    end
                    if ( m.enabled ) then
                        displayEnabled ["msg" .. l] = (m.enabled == "on") and nil;
                    end
                end
            end
            
        end
        
        json = nil;
        
    end 

end

--function M.periodic ( client, topic )
--
--    print ( "[APP] periodic call topic=" .. topic );
--    
--end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------