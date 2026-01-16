-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for bodies with rings with a high
-- rotational velocity. When parked in the ring, you may see the skybox moving.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Global

-- For Fast Ring check.
RING_ORBITAL_PERIOD_ENABLED = true
RING_ORBITAL_PERIOD_S_TO_TRIGGER = 5400

---@End


---@Complex Fast Rings
if hasRings(scan.Rings) then
    local G = 6.674 * (10^(-11))
    local bodyMass = scan.MassEM * 5.972*(10^24)
    local bodyType = scan.PlanetClass
    if isStar(scan) then
      bodyMass = scan.StellarMass * 1.988*(10^30)
      bodyType = string.format('Star: %s', scan.StarType:gsub('_', ' '))
    end

    local periodResult = ""
    local fastRingCount = 0

    for ring in rings(scan.Rings) do
        local averageRadius_m = (ring.outerrad + ring.innerrad) / 2
        local orbitalVelocity_kmps = distanceAsKm(math.sqrt(G * (bodyMass / averageRadius_m)))
        local ringCircumference_km = 2 * (math.pi * distanceAsKm(averageRadius_m))
        local ringOrbitalPeriod_s = (ringCircumference_km / orbitalVelocity_kmps)

        if ringOrbitalPeriod_s <= RING_ORBITAL_PERIOD_S_TO_TRIGGER then
          fastRingCount = fastRingCount + 1
          periodResult = periodResult .. string.format('%s: %.0f minutes, %.0f km/s, Body type: %s; ', ring.name:sub(scan.BodyName:len() + 2), orbitalVelocity_kmps, ringOrbitalPeriod_s / 60, bodyType)
        end
    end
    if fastRingCount > 0 and RING_ORBITAL_PERIOD_ENABLED then
        return true, 'Fast ring(s)', periodResult
    end
end
---@End
