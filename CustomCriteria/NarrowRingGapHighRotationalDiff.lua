-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which rings with a narrow gap a high relative
-- ring velocity difference.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Complex Narrow ring gap with High rotational difference
if hasRings(scan.Rings) and scan.Rings.Count >= 2 then
  -- Only checking 2 innermost rings because 3rd rings are rarely visible.
  local G = 6.674 * (10^(-11))
  local innerRing = scan.Rings[0]
  local outerRing = scan.Rings[1]

  local bodyMass_kg = scan.MassEM * 5.972*(10^24)
  local bodyTypeString = scan.PlanetClass
  if isStar(scan) then
    bodyMass_kg = scan.StellarMass * 1.98847*(10^30)
    bodyTypeString = string.format('Star: %s', scan.StarType:gsub('_', ' '))
  end

  -- Radii are specified in meters.
  local innerRingWidth_m = innerRing.OuterRad - innerRing.InnerRad
  local ringGap_km = distanceAsKm(outerRing.InnerRad - innerRing.OuterRad)
  local innerRingAvgRad_m = (innerRing.OuterRad + innerRing.InnerRad) / 2
  local outerRingAvgRad_m = (outerRing.OuterRad + outerRing.InnerRad) / 2

  local innerRingOrbitalVelocity_kmps = distanceAsKm(math.sqrt(G * (bodyMass_kg / innerRingAvgRad_m)))
  local outerRingOrbitalVelocity_kmps = distanceAsKm(math.sqrt(G * (bodyMass_kg / outerRingAvgRad_m)))
  local ringVelocityDelta_kmps = math.abs(outerRingOrbitalVelocity_kmps - innerRingOrbitalVelocity_kmps)

  if ringGap_km <= 99 and ringVelocityDelta_kmps >= 5 then
    local ringWidthText = ''
    if distanceAsLs(innerRingWidth_m) >= 0.1 then
      ringWidthText = string.format('%.1f Ls', distanceAsLs(innerRingWidth_m))
    else
      ringWidthText = string.format('%.0f km', distanceAsKm(innerRingWidth_m))
    end

    return true,
        'Narrow ring gap with high rotational difference',
        string.format('Gap: %.0f km; Inner ring width: %s; Ring velocity difference: %.1f km/s (%.1f, %.1f); Host body type: %s', ringGap_km, ringWidthText, ringVelocityDelta_kmps, innerRingOrbitalVelocity_kmps, outerRingOrbitalVelocity_kmps, bodyTypeString)
    -- .. string.format('Inner ring velocity: %.1f km/s, Outer ring velocity: %.1f km/s', innerRingOrbitalVelocity_kmps, outerRingOrbitalVelocity_kmps)
  end
end
---@End
