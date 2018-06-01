--------------------------------------------------------------------
--
-- nodes@home/luaNodes/pixelNodeConnect
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 10.05.2018

local moduleName, super = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

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

local function handleCategory ( category, text, printFunc, insertCol )

    --print ( "[APP] handleCategory: category=" .. category .. " text=" .. tostring ( text ) .. " enabled=" .. tostring ( displayEnabled [category] ) .. " heap=" .. node.heap () );

    if ( text ~= nil and ( displayEnabled [category] == nil or displayEnabled [category] ) ) then
        if ( printFunc ) then
            printFunc ( text, insertCol );
         else
            pixel.printAndShakeString ( text );
         end
    else
        -- process next category, the category is computet in loop
        displayCategoryPeriodCounter = displayCategoryPeriod;
        node.task.post ( loop );
    end

end

loop = function ()

    --print ( "[APP] loop: category=" .. tostring ( displayCategory ) ..  " heap=" .. node.heap () );

    if ( false and displayCategory == "time" ) then -- toggle colon
        local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
        local sign = tm ["sec"] % 2 == 0 and ":" or " ";
        matrix.printDateTimeString ( string.format ( "%02d%s%02d", tm ["hour"], sign, tm ["min"] ) );
    end
    
    displayCategoryPeriodCounter = displayCategoryPeriodCounter + 1;
    
    if ( displayCategoryPeriodCounter > displayCategoryPeriod ) then

        displayCategoryPeriodCounter = 1;

        local oldDisplayCategory = displayCategory;
        if ( displayCategory == "time" ) then
            displayCategory = "date";
            local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
            local sign = tm ["sec"] % 2 == 0 and ":" or " ";
            handleCategory ( oldDisplayCategory, string.format ( "%02d%s%02d", tm ["hour"], sign, tm ["min"] ), pixel.printDateTimeString );
        elseif ( displayCategory == "date" ) then
            displayCategory = "msg1";
            local tm = rtctime.epoch2cal ( correctTimezone ( rtctime.get () ) );
            handleCategory ( oldDisplayCategory, string.format ( "%02d.%02d.%04d", tm ["day"], tm ["mon"], tm ["year"] ), pixel.printDateTimeString );
        elseif ( displayCategory:sub ( 1, 3 ) == "msg" ) then
            local i = tonumber ( displayCategory:sub ( 4 ) );
            if ( i < 20 ) then
                displayCategory = "msg" .. (i + 1);
            else
                displayCategory = "time";
            end
            handleCategory ( oldDisplayCategory, displayMessage [i] );
        else
            displayCategory = "time";
        end

    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    print ( "[APP] connect: topic=" .. topic );
    
    -- subscibe to .../message/#
    -- subsciption to .../command and .../alert is not necesssary

    local t = topic .. "/message/#";
    --print ( "[APP] subscripe to topic=" .. t );
    client:subscribe ( t, 0, -- ..., qos
        function ( client )
            print ( "[APP] syncing to server=" .. SNTP );
            sntp.sync ( SNTP, 
                function ( sec, usec )
                    print ( "[APP] setting time to sec=" .. sec .. " usec=" .. usec );
                    rtctime.set ( sec, usec );
                    local t = tmr.create ();
                    print ( "[APP] t=" .. tostring ( t ) );
                    t:alarm ( 1000, tmr.ALARM_AUTO, loop );
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

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------