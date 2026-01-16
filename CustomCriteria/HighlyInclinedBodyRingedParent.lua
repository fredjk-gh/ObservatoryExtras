-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for landable moons closely orbiting
-- a ringed parent body. When viewed from the moon, the rings and/or parent body will appear large in the skybox.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras


---@Complex Inclined body Ringed Parent
local parentRingsList = nil
local sma = 0
local inclination = 0
local barycenterStr = ''
if (parents ~= nil and parents[0].Scan and parents[0].ParentType == 'Null' and parents[1] and parents[1].Scan and hasRings(parents[1].Scan.Rings)) then
  parentRingsList = parents[1].Scan.Rings
  sma = scan.SemiMajorAxis + parents[0].Scan.SemiMajorAxis
  inclination = parents[0].Scan.OrbitalInclination
  barycenterStr = '(with barycenter)'
elseif (parents ~= nil and parents[0].Scan and hasRings(parents[0].Scan.Rings)) then
  parentRingsList = parents[0].Scan.Rings
  sma = scan.SemiMajorAxis
  inclination = scan.OrbitalInclination
end

if isPlanet(scan) and scan.Landable and math.abs(inclination) > 10 and distanceAsLs(sma) < 10 and parentRingsList and hasRings(parentRingsList) then
  local angularDiameters = ''
  local angularDiameter = 0.0
  for parentRing in ringsOnly(parentRingsList) do
    angularDiameter = 57.3 * ((2 * parentRing.outerrad) / sma)
    angularDiameters = angularDiameters .. string.format('%.1f°, ', angularDiameter)
  end
  if (angularDiameter > 40) then
    return true, 'Landable, High Inclination body close to ringed parent', string.format('%.1f°, %.1f Ls, angular diameter of rings: %s%s', inclination, distanceAsLs(sma), angularDiameters, barycenterStr)
  end
end
---@End
