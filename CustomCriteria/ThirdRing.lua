-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for rare third rings on a body.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Complex Third Ring
if hasRings(scan.Rings) and scan.Rings.Count > 2 then
  local thirdRing = scan.Rings[2]
  local density = thirdRing.MassMT / ((math.pi * (distanceAsKm(thirdRing.OuterRad) ^ 2)) - (math.pi * (distanceAsKm(thirdRing.InnerRad)^ 2)))

  if density > 0.1 then
    return true, 'Potentially visible Third ring', string.format('Density: %.1f MT/km^3\ncCheck sysmap', density)
  else
    return true, 'Likely invisible Third ring', string.format('Density: %.4f MT/km^3\nCheck sysmap; shepherd moons may be false-positives', density)
  end
end
---@End
