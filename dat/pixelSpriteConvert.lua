
function tohex ( byte, len )

    return "0x" .. string.format( "%0" .. (len or 2) .. "X", byte );

end


require ( "pixelSprite" );

local function createJson ()

    for i= 1, #SPRITE do
        --print ( i, #SPRITE [i] )
        local line = '{ "index": ' .. i-1 .. ', "char": "_", "data": [ ';
        for j = 1, #SPRITE [i] do
            if ( j > 1 ) then line = line .. "," end
            --line = string.format ( "%s %s", line, tohex ( tonumber ( SPRITE [i] [j], 2 ) ) );
            line = string.format ( '%s "%s"', line, SPRITE [i] [j] );
        end
        line = line .. " ] },"
        print ( line );
    end

end

local function createSpriteFiles ()

    for i = 1, #SPRITE do
        local line = "return {"
        for j = 1, #SPRITE [i] do
            if ( j > 1 ) then line = line .. "," end
            line = string.format ( "%s %s", line, tohex ( tonumber ( SPRITE [i] [j], 2 ) ) );
            --line = string.format ( '%s "%s"', line, SPRITE [i] [j] );
        end
        line = line .. " }";
        local filename = "sprite_0x" .. string.format ( "%02X", 31 + i ) .. ".lua";
        print ( filename .. ": " .. line );
        local file = io.open ( filename, "w" );
        if ( file ) then
            file:write ( line );
            file:close ();
        end
    end

end

local function createSpriteFilesv2 ()

    for i = 1, #SPRITE do
        local line = ""
        for j = 1, #SPRITE [i] do
            line = string.format ( "%s %s", line, tohex ( tonumber ( SPRITE [i] [j], 2 ) ) );
        end
        local filename = "sprite_0x" .. string.format ( "%02X", 31 + i ) .. ".dat";
        print ( filename .. ": " .. line );
        local file = io.open ( filename, "w" );
        if ( file ) then
            file:write ( line );
            file:close ();
        end
    end

end

local function createSpriteStrings ()

    local umlaute = {
        [96] = "0xC3_0x84",
        [97] = "0xC3_0x96",
        [98] = "0xC3_0x9C",
        [999] = "0xC3_0xA4",
        [100] = "0xC3_0xB6",
        [101] = "0xC3_0xBC",
        [102] = "0xC3_0x9F",
        [103] = "0xC2_0xB0",
    };

    for i = 1, #SPRITE do

        local index = 31 + i;
        --print ( i, index, tohex ( index ) );

        local code = tohex ( index );
        if ( umlaute [i] ) then
            code = umlaute [i];
        end

        local line = "sprite_" .. code .. " = string.char ";
        local first = true;
        for j = 1, #SPRITE [i] do
            line = string.format ( "%s%s%s", line, (first and "( " or ', '), tostring ( tonumber ( SPRITE [i] [j], 2 ) ) );
            first = false;
        end
        line = line .. " );";
        print ( line );
--        local filename = "sprite_0x" .. string.format ( "%02X", 31 + i ) .. ".dat";
--        print ( filename .. ": " .. line );
--        local file = io.open ( filename, "w" );
--        if ( file ) then
--            file:write ( line );
--            file:close ();
--        end
    end

end

local function createSpriteString ()

    local umlaute = {
        [96] = "0xC3_0x84",
        [97] = "0xC3_0x96",
        [98] = "0xC3_0x9C",
        [999] = "0xC3_0xA4",
        [100] = "0xC3_0xB6",
        [101] = "0xC3_0xBC",
        [102] = "0xC3_0x9F",
        [103] = "0xC2_0xB0",
    };

    local file = io.open ( "pixel.dat", "w" );
    for i = 1, #SPRITE do
        local s = SPRITE [i];
        local t = { #s, 0, 0, 0, 0, 0 };
        for j = 1, #SPRITE [i] do
            t [j + 1] = tonumber ( SPRITE [i] [j], 2 );
        end
        print ( "len=" .. #t, unpack(t) );
        file:write ( string.char ( unpack ( t ) ) );
    end
    file:close ();

    print ( "dat file generated" );

end

--createSpriteFilesv2 ();
--string.gsub ( " 0x01 0x02 0x03", "(%w+)", print )
createSpriteString ();