-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for landable moons that closely
-- orbit a body that appears very large skybox when viewed from the surface of the moon.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Global

-- For High angular diameter parent check.
MINIMUM_ANGULAR_DIAMETER_STAR = 25
MINIMUM_ANGULAR_DIAMETER_PLANET = 45

---@End

---@Complex Landable with high angular diameter parent
  if (isPlanet(scan) and scan.Landable and parents and parents.Count > 0 and parents[0].Scan) then
    local a=0
    if(parents[0].Scan and (isPlanet(parents[0].Scan) or isStar(parents[0].Scan))) then
      a = 57.3 * ((2 * parents[0].Scan.Radius) / scan.SemiMajorAxis)
    end

    if ((a > MINIMUM_ANGULAR_DIAMETER_STAR and isStar(parents[0].Scan)) or (a > MINIMUM_ANGULAR_DIAMETER_PLANET and isPlanet(parents[0].Scan))) then
      local bodyTypeDetail = (parents[0].Scan.StarType or '') .. (parents[0].Scan.PlanetClass or '') -- only one will be set.
      return
          true,
          'Landable with high angular diameter parent ' .. parents[0].ParentType,
          string.format('%.1f°, Parent type: %s; %s', a, parents[0].ParentType, bodyTypeDetail)
    end
  end
---@End
