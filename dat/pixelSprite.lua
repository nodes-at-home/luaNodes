-- junand 25.04.2018

-- Set module name as parameter of require
local modname = ...;
local M = {};
_G[modname] = M;

--------------------------------------------------------------------------------
-- settings

SPRITE = {
    -- each byte stands for one column from left to right in a sprite
    { "00000000", "00000000", "00000000" },                           -- space       0
    { "01011111" },                                                   -- !
    { "00000011", "00000000", "00000011" },                           -- "
    { "00010100", "00111110", "00010100", "00111110", "00010100" },   -- #
    { "00100100", "01101010", "00101011", "00010010" },               -- $
    { "01100011", "00010011", "00001000", "01100100", "01100011" },   -- %
    { "00110110", "01001001", "01010110", "00100000", "01010000" },   -- &
    { "00000011" },                                                   -- '
    { "00011100", "00100010", "01000001" },                           -- (
    { "01000001", "00100010", "00011100" },                           -- )
    { "00100010", "00010100", "00111110", "00010100", "00100010" },   -- *           10
    { "00001000", "00001000", "00111110", "00001000", "00001000" },   -- +
    { "10110000", "01110000" },                                       -- ,
    { "00001000", "00001000", "00001000", "00001000" },               -- -
    { "01100000", "01100000" },                                       -- .
    { "01100000", "00011000", "00000110", "00000001" },               -- /
    { "00111110", "01000001", "01000001", "00111110" },               -- 0           16 0x10
    { "01000010", "01111111", "01000000" },                           -- 1
    { "01100010", "01010001", "01001001", "01000110" },               -- 2
    { "00100010", "01000001", "01001001", "00110110" },               -- 3
    { "00011000", "00010100", "00010010", "01111111" },               -- 4           20
    { "00100111", "01000101", "01000101", "00111001" },               -- 5
    { "00111110", "01001001", "01001001", "00110000" },               -- 6
    { "01100001", "00010001", "00001001", "00000111" },               -- 7
    { "00110110", "01001001", "01001001", "00110110" },               -- 8
    { "00000110", "01001001", "01001001", "00111110" },               -- 9
    { "01101100", "01101100" },                                       -- :
    { "10000000", "01010000" },                                       -- ;
    { "00010000", "00101000", "01000100" },                           -- <
    { "00010100", "00010100", "00010100" },                           -- =
    { "01000100", "00101000", "00010000" },                           -- >           30
    { "00000010", "01011001", "00001001", "00000110" },               -- ?
    { "00111110", "01001001", "01010101", "01011101", "00001110" },   -- @           32 0x20
    { "01111110", "00010001", "00010001", "01111110" },               -- A
    { "01111111", "01001001", "01001001", "00110110" },               -- B
    { "00111110", "01000001", "01000001", "00100010" },               -- C
    { "01111111", "01000001", "01000001", "00111110" },               -- D
    { "01111111", "01001001", "01001001", "01000001" },               -- E
    { "01111111", "00001001", "00001001", "00000001" },               -- F
    { "00111110", "01000001", "01001001", "01111010" },               -- G
    { "01111111", "00001000", "00001000", "01111111" },               -- H           40
    { "01000001", "01111111", "01000001" },                           -- I
    { "00110000", "01000000", "01000001", "00111111" },               -- J
    { "01111111", "00001000", "00010100", "01100011" },               -- K
    { "01111111", "01000000", "01000000", "01000000" },               -- L
    { "01111111", "00000010", "00001100", "00000010", "01111111" },   -- M
    { "01111111", "00000100", "00001000", "00010000", "01111111" },   -- N
    { "00111110", "01000001", "01000001", "00111110" },               -- O
    { "01111111", "00001001", "00001001", "00000110" },               -- P           48 0x30
    { "00111110", "01000001", "01000001", "10111110" },               -- Q
    { "01111111", "00001001", "00001001", "01110110" },               -- R           50
    { "01000110", "01001001", "01001001", "00110010" },               -- S
    { "00000001", "00000001", "01111111", "00000001", "00000001" },   -- T
    { "00111111", "01000000", "01000000", "00111111" },               -- U
    { "00001111", "00110000", "01000000", "00110000", "00001111" },   -- V
    { "00111111", "01000000", "00111000", "01000000", "00111111" },   -- W
    { "01100011", "00010100", "00001000", "00010100", "01100011" },   -- X
    { "00000111", "00001000", "01110000", "00001000", "00000111" },   -- Y
    { "01100001", "01010001", "01001001", "01000111" },               -- Z
    { "01111111", "01000001" },                                       -- [
    { "00000001", "00000110", "00011000", "01100000" },               -- \ 0backslash 60
    { "01000001", "01111111" },                                       -- ]
    { "00000010", "00000001", "00000010" },                           -- hat
    { "01000000", "01000000", "01000000", "01000000" },               -- _
    { "00000001", "00000010" },                                       -- `           64 0x40
    { "00100000", "01010100", "01010100", "01111000" },               -- a
    { "01111111", "01000100", "01000100", "00111000" },               -- 0b
    { "00111000", "01000100", "01000100", "00101000" },               -- c
    { "00111000", "01000100", "01000100", "01111111" },               -- d
    { "00111000", "01010100", "01010100", "00011000" },               -- e
    { "00000100", "01111110", "00000101" },                           -- f           70
    { "10011000", "10100100", "10100100", "01111000" },               -- g
    { "01111111", "00000100", "00000100", "01111000" },               -- h
    { "01000100", "01111101", "01000000" },                           -- i
    { "01000000", "10000000", "10000100", "01111101" },               -- j
    { "01111111", "00010000", "00101000", "01000100" },               -- k
    { "01000001", "01111111", "01000000" },                           -- l
    { "01111100", "00000100", "01111100", "00000100", "01111000" },   -- m
    { "01111100", "00000100", "00000100", "01111000" },               -- n
    { "00111000", "01000100", "01000100", "00111000" },               -- o
    { "11111100", "00100100", "00100100", "00011000" },               -- p           80 0x50
    { "00011000", "00100100", "00100100", "11111100" },               -- q
    { "01111100", "00001000", "00000100", "00000100" },               -- r
    { "01001000", "01010100", "01010100", "00100100" },               -- s
    { "00000100", "00111111", "01000100" },                           -- t
    { "00111100", "01000000", "01000000", "01111100" },               -- u
    { "00011100", "00100000", "01000000", "00100000", "00011100" },   -- v
    { "00111100", "01000000", "00111100", "01000000", "00111100" },   -- w
    { "01000100", "00101000", "00010000", "00101000", "01000100" },   -- x
    { "10011100", "10100000", "10100000", "01111100" },               -- y
    { "01100100", "01010100", "01001100" },                           -- z           90
    { "00001000", "00110110", "01000001" },                           -- {
    { "01111111" },                                                   -- |
    { "01000001", "00110110", "00001000" },                           -- }
    { "00001000", "00000100", "00001000", "00000100" },               -- ~           94
    -- ---------------------------------------------------------------------------------
    { "01111101", "00010010", "00010010", "01111101" },               -- AE          95         0xC3_0x84
    { "00111101", "01000010", "01000010", "00111101" },               -- OE          96         0xC3_0x96
    { "00111101", "01000000", "01000000", "00111101" },               -- UE          97         0xC3_0x9C
    { "00100000", "01010101", "01010101", "01111000" },               -- ae          98         0xC3_0xA4
    { "00111000", "01000101", "01000101", "00111000" },               -- oe          99         0xC3_0xB6
    { "00111100", "01000001", "01000001", "01111100" },               -- ue         100         0xC3_0xBC
    { "11111000", "01010100", "00101000" },                           -- sz         101         0xC3_0x9F
    { "00000011", "00000011" },                                       -- grad       102         0xC2_0xB0

};

--------------------------------------------------------------------------------
-- public

function M.get ( index )

    assert ( index > 0 and index <= #SPRITE, "out of range index=" .. index );

    return SPRITE [index];

end

--------------------------------------------------------------------------------

return M;

--------------------------------------------------------------------------------
