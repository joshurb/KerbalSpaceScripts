// Functional Launch Script

function main {
  doLaunch().
  doAscent().
  until apoapsis > 100000 {
    doAutoStage().
  }
  doPauseforManeuver().
  //doShutdown().
  print "Launch Complete".

  doCircularization().

  print "It ran!".
  unlock steering.
  doShutdown().
}

function doCircularization {
  print "Attempting Circularization Orbit.".
  local circ is list(time:seconds + 30, 0, 0, 0).
  until false {
    local oldScore is score(circ).
    set circ to improve(circ).
    if oldScore <= score(circ) {
      //didn't improve
      break.
    }
    //keep improving
  }

  executeManeuver(circ).
}

//Maneuver List -> number (lower is better)
function score {
  parameter data.
  local mnv is node(data[0], data[1], data[2], data[3]).
  addManeuverToFlightPlan(mnv).
  local result is mnv:orbit:eccentricity. // 0 ideally
  removeManeuverFromFlightPlan(mnv).
  return result.
}

//Maneuver list -> hopefully improved Maneuver list
function improve {
  parameter data.
  local scoreToBeat is score(data).

  local bestCandidate is data.
  local candidates is list(
    list(data[0]+1, data[1], data[2], data[3]),
    list(data[0]-1, data[1], data[2], data[3]),
    list(data[0], data[1]+1, data[2], data[3]),
    list(data[0], data[1]-1, data[2], data[3]),
    list(data[0], data[1], data[2]+1, data[3]),
    list(data[0], data[1], data[2]-1, data[3]),
    list(data[0], data[1], data[2], data[3]+1),
    list(data[0], data[1], data[2], data[3]-1)
  ).

  for candidate in candidates {
    local candidateScore is score(candidate).
    if candidateScore < scoreToBeat {
      set scoreToBeat to candidateScore.
      set bestCandidate to candidate.
    }
  }


  return bestCandidate.
}

function executeManeuver {
  parameter mList.
  local mnv is node(mList[0], mList[1], mList[2], mList[3]).
  addManeuverToFlightPlan(mnv).
  local startTime is calculateStartTime(mnv).
  print "start time calculated".
  wait until time:seconds > startTime - 10.
  lockSteeringAtManeuverTarget(mnv).
  wait until time:seconds > startTime.
  lock throttle to 1.
  wait until isManeuverComplete(mnv).
  lock throttle to 0.
  removeManeuverFromFlightPlan(mnv).
}

function addManeuverToFlightPlan {
  parameter mnv.
  print "Maneuver Added to flight plan".
  add mnv.
}

function calculateStartTime {
  parameter mnv.
  return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

function maneuverBurnTime {
  parameter mnv.
  local dV is mnv:deltav:mag.
  local g0 is 9.80665.
  local isp is 0.
  list engines in myEngines.
  for en in myEngines {
    if en:ignition and not en:flameout {
      set isp to isp + (en:isp * (en:maxThrust / ship:maxThrust)).
    }
  }
  //dV = isp * g0 * ln(m0 / mf)
  //mf = m0 - ( fuelFlow * t )
  //F = isp * g0 * fuelFlow
  local mf is ship:mass / constant():e^(dV / (isp * g0)).
  local fuelFlow is ship:maxThrust / (isp * g0).
  local t is (ship:mass - mf) / fuelFlow.

  return t.
}

function lockSteeringAtManeuverTarget {
  parameter mnv.
  lock steering to mnv:burnvector.
}

function isManeuverComplete {
  parameter mnv.
  if not(defined originalVector) or originalVector = -1 {
    declare global originalVector to mnv:burnvector.
  }

  //what was the direction to start with
  //How much have we diverged from the original direction
  //is it a lot?
  //then we overshot/ are done
  if vang(originalVector, mnv:burnvector) > 90 {
    declare global originalVector to -1.
    return true.
  }
  return false.
}

function removeManeuverFromFlightPlan {
  parameter mnv.
  remove mnv.
}

function doLaunch {
  lock throttle to 1.
  doSafeStage().
  //doSafeStage().
}

function doAscent {
  lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
  set targetDirection to 90.
  lock steering to heading(targetDirection, targetPitch).
}

function doAutoStage {
  if not(defined oldThrust) {
    declare global oldThrust to ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    doSafeStage(). wait 1.
    declare global oldThrust to ship:availablethrust.
  }
}

function doPauseforManeuver {
  lock throttle to 0.
  lock steering to prograde.
}

function doShutdown {
  lock throttle to 0.
  lock steering to prograde.
  wait until false.
}

function doSafeStage {
  wait until stage:ready.
  stage.
}

main().
