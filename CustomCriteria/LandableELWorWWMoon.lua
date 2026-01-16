-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for landable moons within 1 ls of a
-- WW or ELW.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Complex Landable Moon of an ELW or WW
if isPlanet(scan) and scan.Landable and distanceAsLs(scan.SemiMajorAxis) <= 1 and parents ~= nil and parents[0].Scan and (parents[0].Scan.PlanetClass == "Earthlike body" or parents[0].Scan.PlanetClass == "Water world") then
  return true,
      'Nearby landable moon of a ' .. parents[0].Scan.PlanetClass,
      string.format('Distance: %.1f Ls; Orbital inclination: %.1f°', distanceAsLs(scan.SemiMajorAxis), scan.OrbitalInclination)
end
---@End
