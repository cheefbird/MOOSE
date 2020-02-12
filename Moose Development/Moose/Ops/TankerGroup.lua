--- **Ops** - (R2.5) - Aerial refueling tanker.
--
-- **Main Features:**
--
--    * Monitor flight status of elements or entire group.
--    * Create a mission queue.
--    * Inherits FLIGHTGROUP class.
--
--
-- ===
--
-- ### Author: **funkyfranky**
-- @module Ops.TankerGroup
-- @image OPS_TankerGroup.png


--- TANKERGROUP class.
-- @type TANKERGROUP
-- @field #string ClassName Name of the class.
-- @field #boolean Debug Debug mode. Messages to all about status.
-- @field #string lid Class id string for output to DCS log file.
-- @field #table Qmissions Mission queue.
-- @field #table Qclients Client queue.
-- @field #TANKERGROUP.Mission currentmission Currently assigned mission.
-- @field #number missioncounter Counter of total missions.
-- @field Core.Scheduler#SCHEDULER Statusupdater Scheduler to update tanker status.
-- @extends Ops.FlightGroup#FLIGHTGROUP

--- *To invent an airplane is nothing. To build one is something. To fly is everything.* -- Otto Lilienthal
--
-- ===
--
-- ![Banner Image](..\Presentations\CarrierAirWing\TANKERGROUP_Main.jpg)
--
-- # The TANKERGROUP Concept
--
-- # Events
-- 
-- 
-- # Tasking
-- 
-- 
-- # Examples
-- 
-- 
--  
--
--
-- @field #TANKERGROUP
TANKERGROUP = {
  ClassName          = "TANKERGROUP",
  Debug              = false,
  lid                =   nil,
  Qmissions          =    {},
  Qclients           =    {},
  currentmission     =   nil,
  missioncounter     =   nil,
  Statusupdater      =   nil,
}

--- Tanker mission table.
-- @type TANKERGROUP.Mission
-- @field #string name Name of the mission.
-- @field #number mid ID of the mission.
-- @field #string status Mission status.
-- @field Ops.FlightGroup#FLIGHTGROUP.Task task Task of mission.
-- @field Core.Zone#ZONE zone Mission zone.
-- @field #number duration Duration of mission.
-- @field #number altitude Altitude of orbit in meters ASL.
-- @field #number distance Length of orbit leg in meters.
-- @field #number heading Heading of orbit in degrees.
-- @field #number speed Speed in m/s.
-- @field #number Tadded Time the mission was added.
-- @field #number Tstart Start time in seconds.
-- @field #number Tstarted Time the mission was started.
-- @field #number Tstop Time the mission is stopped.
-- @field #number Tsopped Time the mission was stopped.
-- @field #number prio Priority of the mission.

--- Mission status.
-- @type TANKERGROUP.MissionStatus
-- @field #string SCHEDULED Task is scheduled.
-- @field #string EXECUTING Task is being executed.
-- @field #string ACCOMPLISHED Task is accomplished.
TANKERGROUP.MissionStatus={
  SCHEDULED="scheduled",
  EXECUTING="executing",
  ACCOMPLISHED="accomplished",
}
--- TANKERGROUP class version.
-- @field #string version
TANKERGROUP.version="0.0.2"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- TODO list
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TODO: Add orbit task.
-- TODO: Add client queue.
-- TODO: Add menu?

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new TANKERGROUP object and start the FSM.
-- @param #TANKERGROUP self
-- @param #string groupname Name of the group.
-- @return #TANKERGROUP self
function TANKERGROUP:New(groupname)

  -- Create flight group.
  local fg=FLIGHTGROUP:New(groupname, false)

  -- Inherit everything from TANKERGROUP class.
  local self=BASE:Inherit(self, fg) -- #TANKERGROUP
    
  -- Init mission counter.
  self.missioncounter=0
  
  -- Log id.
  self.lid=string.format("FLIGHTGROUP %s (TANKER) | ", groupname)
  
  if false then
    BASE:TraceOn()
    BASE:TraceLevel(3)
    BASE:TraceClass(self.ClassName)
    BASE:TraceClass("FLIGHTGROUP")
  end
  
  -- Add FSM transitions.
  --                 From State     -->     Event     -->          To State
  self:AddTransition("*",                 "TankerState",          "*")              -- Tanker is on station and ready to refuel.
  self:AddTransition("*",                 "OnStation",            "Ready2Refuel")   -- Tanker is on station and ready to refuel.
  self:AddTransition("*",                 "MissionStart",         "*")              -- Tanker is on station and ready to refuel.  
  self:AddTransition("*",                 "MissionAccomplished",  "*")              -- Tanker is on station and ready to refuel.
  

  -- Call status update.
  self:__TankerState(-5)
  
  -- Start FSM.
  self:Start()
  
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- User API functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Add mission for tanker.
-- @param #TANKERGROUP self
-- @param Core.Zone#ZONE Zone The mission zone. Orbit is picked at a random location.
-- @param #number Altitude Orbit altitude in feet. Default is 10000 ft.
-- @param #number Distance Length of the race-track pattern leg in NM.
-- @param #number Heading Heading of the race-track pattern in degrees. Default is 90, i.e. from West to East.
-- @param #number SpeedOrbit Orbit speed in knots. Default is 280 knots.
-- @param #string ClockStart Time the mission is started, e.g. "05:00" for 5 am. If specified as a #number, it will be relative (in seconds) to the current mission time.
-- @param #string ClockStop Time the mission is stopped, e.g. "13:00" for 1 pm. If mission could not be started at that time, it will be removed from the queue. If specified as a #number it will be relative (in seconds) to the current mission time.
-- @param #number Prio Priority of the mission, i.e. a number between 1 and 100. Default 50.
-- @param #string Name Mission name. Default "Aerial Refueling #00X", where "#00X" is a running mission counter index starting at "#001".
-- @return #TANKERGROUP.Mission The mission table.
function TANKERGROUP:AddMission(Zone, Altitude, Distance, Heading, SpeedOrbit, ClockStart, ClockStop, Prio, Name)

  -- Increase mission counter.
  self.missioncounter=self.missioncounter+1
  
  -- Current mission time.
  local Tnow=timer.getAbsTime()
  
  -- Set start time. Default in 5 sec.
  local Tstart=Tnow+5
  if ClockStart and type(ClockStart)=="number" then
    Tstart=Tnow+ClockStart
  elseif ClockStart and type(ClockStart)=="string" then
    Tstart=UTILS.ClockToSeconds(ClockStart)
  end

  -- Set stop time. Default nil.
  local Tstop=nil
  if ClockStop and type(ClockStop)=="number" then
    Tstop=Tnow+ClockStop
  elseif ClockStop and type(ClockStop)=="string" then
    Tstop=UTILS.ClockToSeconds(ClockStop)
  end

  -- Make mission table.
  local mission={} --#TANKERGROUP.Mission  
  mission.zone=Zone
  mission.mid=self.missioncounter
  mission.altitude=UTILS.FeetToMeters(Altitude or 10000)
  mission.distance=UTILS.NMToMeters(Distance or 25)
  mission.name=Name or string.format("Aerial Refueling #%03d", mission.mid) 
  mission.speed=UTILS.KnotsToMps(SpeedOrbit or 280)
  mission.heading=Heading or 270
  mission.Tadded=Tnow
  mission.Tstart=Tstart
  mission.Tstop=Tstop
  mission.status=TANKERGROUP.MissionStatus.SCHEDULED
  if Tstop then
    mission.duration=mission.Tstop-mission.Tstart
  end
  mission.prio=Prio or 50
  mission.task=nil

  -- Add mission to queue.
  table.insert(self.Qmissions, mission)
  
  local text=string.format("Added mission %s at zone %s. Starting at %s. Stopping at %s. Altitude=%d ft, Leg=%s NM, Heading=%03d, Speed=%d kts",
  mission.zone:GetName(), mission.name, UTILS.SecondsToClock(mission.Tstart, true), mission.Tstop and UTILS.SecondsToClock(mission.Tstop, true) or "never", 
  UTILS.MetersToFeet(mission.altitude), UTILS.MetersToNM(mission.distance), mission.heading, UTILS.MpsToKnots(mission.speed))
  self:I(self.lid..text)
  
  return mission
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FSM functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- On after "TankerStatus" event.
-- @param #TANKERGROUP self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function TANKERGROUP:onafterTankerState(From, Event, To)

  -- FSM state.
  local fsmstate=self:GetState()

  -- First check if group is alive?
  if self:IsAlive()~=nil and not self.currentmission then
  
    local mission=self:_GetNextMission()
    
    if mission then
      
      env.info("FF starting mission")
      self:MissionStart(mission)
      
    end
  end
  
  -- Current mission name.
  local mymission=self.currentmission and self.currentmission.name or "N/A"
  
  -- Current status.
  local text=string.format("Tanker Status %s: Mission=%s (%d)", fsmstate, mymission, #self.Qmissions)
  for i,_mission in pairs(self.Qmissions) do
    local mission=_mission --#TANKERGROUP.Mission
    text=text..string.format("\n[%d] %s status=%s", i, tostring(mission.name), tostring(mission.status))
  end
  self:I(self.lid..text)
  
  -- Nest status update in 30 sec.
  self:__TankerState(-30)
end

--- On after "MissionStart" event.
-- @param #TANKERGROUP self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param #TANKERGROUP.Mission Mission The mission table.
function TANKERGROUP:onafterMissionStart(From, Event, To, Mission)

  -- TODO: need to handle case that group is spawned at a later point in time!

  -- Delay for route to mission. Group needs to be activated and controlled.
  local delay=nil

  -- Check if group is spawned.
  if self:IsInUtero() then
  
    -- Activate group if it is late activated.
    if self:IsLateActivated() then   
      self:Activate()
      delay=1
    end
    
    -- Activate group if it is uncontrolled.
    if self:IsUncontrolled() then
      self:StartUncontrolled(5)
      delay=6
    end
  
  end
  
  -- Set current mission.
  self.currentmission=Mission
  
  -- Set Tstarted time stamp.
  self.currentmission.Tstarted=timer.getAbsTime()
  
  -- Set mission status.
  self.currentmission.status=TANKERGROUP.MissionStatus.EXECUTING

  -- Route flight to mission zone.
  self:RouteToMission(Mission, delay)

end

--- On after "TaskDone" event.
-- @param #TANKERGROUP self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.FlightGroup#FLIGHTGROUP.Task Task.
function TANKERGROUP:onafterTaskDone(From, Event, To, Task)

  -- First call flight status.
  self:GetParent(self).onafterTaskDone(self, From, Event, To, Task)
  
  if self.currentmission then
  
    local missiontask=self.currentmission.task
    
    if missiontask.id==Task.id then
      self:MissionAccomplished(self.currentmission)
    end
    
  end  
end

--- On after "MissionAccomplished" event.
-- @param #TANKERGROUP self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param #TANKERGROUP.Mission Mission
function TANKERGROUP:onafterMissionAccomplished(From, Event, To, Mission)

  Mission.status=TANKERGROUP.MissionStatus.ACCOMPLISHED
  self.currentmission=nil

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MISC functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Get next mission.
-- @param #TANKERGROUP self
-- @return #TANKERGROUP.Mission Next mission or *nil*.
function TANKERGROUP:_GetNextMission()

  -- Number of missions.
  local Nmissions=#self.Qmissions

  -- Treat special cases.
  if Nmissions==0 then
    return nil
  end

  -- Sort results table wrt times they have already been engaged.
  local function _sort(a, b)
    local taskA=a --#TANKERGROUP.Mission
    local taskB=b --#TANKERGROUP.Mission
    return (taskA.Tstart<taskB.Tstart) or (taskA.Tstart==taskB.Tstart and taskA.prio<taskB.prio)
  end
  table.sort(self.Qmissions, _sort)
  
  -- Current time.
  local time=timer.getAbsTime()

  -- Look for first task that is not accomplished.
  for _,_mission in pairs(self.Qmissions) do
    local mission=_mission --#TANKERGROUP.Mission
    if mission.status==TANKERGROUP.MissionStatus.SCHEDULED and time>=mission.Tstart then
      return mission
    end
  end

  return nil
end

--- Route group to mission. Also sets the 
-- @param #TANKERGROUP self
-- @param #TANKERGROUP.Mission mission The mission table.
-- @param #number delay Delay in seconds.
function TANKERGROUP:RouteToMission(mission, delay)

  if delay and delay>0 then
    -- Delay call.
    self:ScheduleOnce(delay, TANKERGROUP.RouteToMission, self, mission)
  else

    -- Get random coordinate in mission zone.
    local Coordinate=mission.zone:GetRandomCoordinate():SetAltitude(mission.altitude, true)
    
    -- Set second coordinate for race track pattern.
    local CoordRaceTrack=Coordinate:Translate(mission.distance, mission.heading, true)
    
    Coordinate:MarkToAll("Orbit 1")
    CoordRaceTrack:MarkToAll("Orbit 2")
  
    -- Add waypoint.
    self:AddWaypointAir(Coordinate, nil, self.speedmax*0.8)
    
    -- Create task to orbit.
    local taskorbit=self.group:TaskOrbit(Coordinate, mission.altitude, mission.speed, CoordRaceTrack)
    
    -- Add waypoint task.
    -- TODO: find last AIR waypoint! We dont want this at landing waypoints.   
    mission.task=self:AddTaskWaypoint(taskorbit, #self.waypoints, mission.name, 10, mission.duration)
  end
end
