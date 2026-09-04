-- MurmurHash3-style fmix32 avalanche finalizer over a djb2 accumulation. Plain djb2
-- alone diffuses poorly for shared-prefix inputs (e.g. "sandbox-0-null" vs
-- "sandbox-1-review" only diverge in their last few bytes), which left same-parent-
-- directory siblings only 1-8 degrees apart on a hue wheel built from it. fmix32 spreads
-- any single-bit input difference across the whole output. Requires native Lua integers
-- (bitwise ops force that) rather than `% (2 ^ 31)`, which forces float and silently
-- rounds once products exceed 2^53.
--
-- Selene's parser doesn't support Lua 5.2+ bitwise operators (`&`, `~`, `>>`) in any
-- released version, so this file is excluded from selene's lint pass in selene.toml.
local MASK32 = 0xFFFFFFFF

local function fmix32(h)
    h = h & MASK32
    h = h ~ (h >> 16)
    h = (h * 0x85ebca6b) & MASK32
    h = h ~ (h >> 13)
    h = (h * 0xc2b2ae35) & MASK32
    h = h ~ (h >> 16)
    return h
end

local function hash_string(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) & MASK32
    end
    return fmix32(hash)
end

-- Re-avalanche the base hash with a salt so saturation/lightness are decorrelated from
-- hue instead of being sliced from the same value (which made near-miss hues also land
-- in the same saturation/lightness bucket)
local function mix_hash(hash, salt) return fmix32(hash ~ salt) end

return {
    hash_string = hash_string,
    mix_hash = mix_hash,
}
