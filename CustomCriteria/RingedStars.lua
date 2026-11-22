-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for undiscovered systems.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras
--
-- Version History:
-- version 2026-11-22.1 - Disambiguate functions and global variables to prevent collisions with other scripts.
-- version 2026-01-15.1 - Initial revision.

---@Global

function string.startsWith_RingedStars(String, Start)
   if (String == nil) or (Start == nil) then
     return false
   end
   return string.sub(String,1,string.len(Start))==Start
end

_RingedStars_UninterestingRingedStarTypes = {
  ['L'] = true;
  ['T'] = true;
  ['Y'] = true;
}
---@End

-- Ringed stars of interest. Exclude the dirty dwarfs (LTY)
---@Complex Ringed Stars
if isStar(scan) and not _RingedStars_UninterestingRingedStarTypes[scan.StarType] and hasRings(scan.Rings) then
  for ring in ringsOnly(scan.Rings) do
    local starTypeDesc = string.format('%s star', scan.StarType:gsub('_', ' '))
    if string.startsWith_RingedStars(scan.StarType, 'D') then
      starTypeDesc = string.format('White Dwarf (%s) star', scan.StarType)
    elseif scan.StarType == 'H' then
      starTypeDesc = 'Black Hole'
    elseif scan.StarType == 'N' then
      starTypeDesc = 'Neutron star'
    elseif scan.StarType == 'X' then
      starTypeDesc = 'Exotic star'
    end
    return true, string.format('Ringed %s', starTypeDesc), string.format('Distance from Arrival: %s Ls', Thousands(scan.DistanceFromArrivalLS))
  end
end
---@End
