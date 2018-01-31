﻿-- This query extracts the duration of mechanical ventilation
-- The main goal of the query is to aggregate sequential ventilator settings
-- into single mechanical ventilation "events". The start and end time of these
-- events can then be used for various purposes: calculating the total duration
-- of mechanical ventilation, cross-checking values (e.g. PaO2:FiO2 on vent), etc

-- The query's logic is roughly:
--    1) The presence of a mechanical ventilation setting starts a new ventilation event
--    2) Any instance of a setting in the next 8 hours continues the event
--    3) Certain elements end the current ventilation event
--        a) documented extubation ends the current ventilation
--        b) initiation of non-invasive vent and/or oxygen ends the current vent
-- The ventilation events are numbered consecutively by the `num` column.

set search_path to mimiciii;
-- First, create a temporary table to store relevant data from CHARTEVENTS.
DROP TABLE IF EXISTS public.kentran_2_1_ventsettings2 CASCADE;
CREATE TABLE public.kentran_2_1_ventsettings2 AS
select
  icustay_id
  , charttime
  -- case statement determining whether it is an instance of mech vent
  , max(
    case
      --when itemid is null or value is null then 0 -- can't have null values; Ken: already accounted for in "where" below
      when itemid = 720 and value != 'Other/Remarks' THEN 1  -- VentTypeRecorded
      when itemid = 223848 and value != 'Other' THEN 1
      when itemid = 467 and value = 'Ventilator' THEN 1 -- O2 delivery device == ventilator
      when itemid = 648 and value = 'Intubated/trach' THEN 1 -- Speech = intubated
      when itemid in
        (
        445, 448, 449, 450, 1340, 1486, 1600, 224687 -- minute volume
        , 639, 654, 681, 682, 683, 684,224685,224684,224686 -- tidal volume
        , 218,436,535,444,459,224697,224695,224696,224746,224747 -- High/Low/Peak/Mean/Neg insp force ("RespPressure")
        , 221,1,1211,1655,2000,226873,224738,224419,224750,227187 -- Insp pressure
        , 543 -- PlateauPressure
        , 5865,5866,224707,224709,224705,224706 -- APRV pressure
        , 60,437,505,506,686,220339,224700 -- PEEP
        , 3459 -- high pressure relief
        , 501,502,503,224702 -- PCV
        , 223,667,668,669,670,671,672 -- TCPCV
        , 157,158,1852,3398,3399,3400,3401,3402,3403,3404,8382,227809,227810 -- ETT
        , 224701 -- PSVlevel
        )
        THEN 1
      else 0
    end
    ) as MechVent
    , max(
       case 
        -- when itemid is null or value is null then 0
        -- extubated indicates ventilation event has ended
        when itemid = 640 and value = 'Extubated' then 1
        when itemid = 640 and value = 'Self Extubation' then 1
        -- initiation of oxygen therapy indicates the ventilation has ended
        when itemid = 226732 and value in
        (
          'Nasal cannula', -- 153714 observations
          'Face tent', -- 24601 observations
          'Aerosol-cool', -- 24560 observations
          'Trach mask ', -- 16435 observations
          'High flow neb', -- 10785 observations
          'Non-rebreather', -- 5182 observations
          'Venti mask ', -- 1947 observations
          'Medium conc mask ', -- 1888 observations
          'T-piece', -- 1135 observations
          'High flow nasal cannula', -- 925 observations
          'Ultrasonic neb', -- 9 observations
          'Vapomist' -- 3 observations
        ) then 1
        when itemid = 467 and value in
        (
          'Cannula', -- 278252 observations
          'Nasal Cannula', -- 248299 observations
          'None', -- 95498 observations
          'Face Tent', -- 35766 observations
          'Aerosol-Cool', -- 33919 observations
          'Trach Mask', -- 32655 observations
          'Hi Flow Neb', -- 14070 observations
          'Non-Rebreather', -- 10856 observations
          'Venti Mask', -- 4279 observations
          'Medium Conc Mask', -- 2114 observations
          'Vapotherm', -- 1655 observations
          'T-Piece', -- 779 observations
          'Hood', -- 670 observations
          'Hut', -- 150 observations
          'TranstrachealCat', -- 78 observations
          'Heated Neb', -- 37 observations
          'Ultrasonic Neb' -- 2 observations
        ) then 1
      else 0
      end
      )
      as Extubated
    , max(
      case 
        -- when itemid is null or value is null then 0 
        when itemid = 640 and value = 'Self Extubation' then 1
      else 0
      end
      )
      as SelfExtubated

from chartevents ce
where ce.value is not null and ce.itemid is not null
-- exclude rows marked as error
and ce.error IS DISTINCT FROM 1
and ce.itemid in 
(
    -- the below are settings used to indicate ventilation
      648 -- speech
    , 720, 223848 -- vent type
    , 445, 448, 449, 450, 1340, 1486, 1600, 224687 -- minute volume
    , 639, 654, 681, 682, 683, 684,224685,224684,224686 -- tidal volume
    , 218,436,535,444,224697,224695,224696,224746,224747 -- High/Low/Peak/Mean ("RespPressure")
    , 221,1,1211,1655,2000,226873,224738,224419,224750,227187 -- Insp pressure
    , 543 -- PlateauPressure
    , 5865,5866,224707,224709,224705,224706 -- APRV pressure
    , 60,437,505,506,686,220339,224700 -- PEEP
    , 3459 -- high pressure relief
    , 501,502,503,224702 -- PCV
    , 223,667,668,669,670,671,672 -- TCPCV
    , 157,158,1852,3398,3399,3400,3401,3402,3403,3404,8382,227809,227810 -- ETT
    , 224701 -- PSVlevel

    -- the below are settings used to indicate extubation
    , 640 -- extubated

    -- the below indicate oxygen/NIV, i.e. the end of a mechanical vent event
    , 468 -- O2 Delivery Device#2
    , 469 -- O2 Delivery Mode
    , 470 -- O2 Flow (lpm)
    , 471 -- O2 Flow (lpm) #2
    , 227287 -- O2 Flow (additional cannula)
    , 226732 -- O2 Delivery Device(s)
    , 223834 -- O2 Flow

    -- used in both oxygen + vent calculation
    , 467 -- O2 Delivery Device
    , 459 -- added by Ken
)
-- Ken: new filter to look only at patients from our cohort. Remove if desired
and icustay_id in (
  select icustay_id from public.kentran_1_3_demographics_nockd)
group by icustay_id, charttime
UNION
-- add in the extubation flags from procedureevents_mv
-- note that we only need the start time for the extubation
-- (extubation is always charted as ending 1 minute after it started)
select
  icustay_id
  , starttime as charttime
  , 0 as MechVent
  , 1 as Extubated 
  , case when itemid = 225468 then 1 else 0 end as SelfExtubated
from procedureevents_mv
where itemid in
(
  227194 -- "Extubation"
, 225468 -- "Unplanned Extubation (patient-initiated)"
, 225477 -- "Unplanned Extubation (non-patient initiated)"
)
-- Ken: filter for icustay_id in our cohort
and icustay_id in (
  select icustay_id from public.kentran_1_3_demographics_nockd)
and value is not null and itemid is not null; -- Ken: added to remove nulls

select * from public.kentran_2_1_ventsettings2
order by icustay_id, charttime;







--DROP MATERIALIZED VIEW IF EXISTS VENTDURATIONS CASCADE;
DROP TABLE IF EXISTS public.kentran_2_1_VENTDURATIONS CASCADE;
create table public.kentran_2_1_ventdurations as
-- create the durations for each mechanical ventilation instance
select icustay_id
  , ventnum
  , min(charttime) as starttime
  , max(charttime) as endtime
  , extract(epoch from max(charttime)-min(charttime))/60/60 AS duration_hours
from
(
  select vd1.*
  -- create a cumulative sum of the instances of new ventilation
  -- this results in a monotonic integer assigned to each instance of ventilation
  , case when MechVent=1 or Extubated = 1 then
      SUM( newvent )
      OVER ( partition by icustay_id order by charttime )
    else null end
    as ventnum
  --- now we convert CHARTTIME of ventilator settings into durations
  from ( -- vd1
      select
          icustay_id
          -- this carries over the previous charttime which had a mechanical ventilation event
          , case
              when MechVent=1 then
                LAG(CHARTTIME, 1) OVER (partition by icustay_id, MechVent order by charttime)
              else null
            end as charttime_lag
          , charttime
          , MechVent
          , Extubated
          , SelfExtubated

          -- if this is a mechanical ventilation event, we calculate the time since the last event
          , case
              -- if the current observation indicates mechanical ventilation is present
              when MechVent=1 then
              -- copy over the previous charttime where mechanical ventilation was present
                CHARTTIME - (LAG(CHARTTIME, 1) OVER (partition by icustay_id, MechVent order by charttime))
              else null
            end as ventduration

          -- now we determine if the current mech vent event is a "new", i.e. they've just been intubated
          , case
            -- if there is an extubation flag, we mark any subsequent ventilation as a new ventilation event
              when Extubated = 1 then 0 -- extubation is *not* a new ventilation event, the *subsequent* row is
              -- when LAG(Extubated,1) OVER( partition by icustay_id, case when MechVent=1 or Extubated=1 then 1 else 0 end order by charttime) = 1 then 1
              when MechVent = 1 and LAG(extubated, 1) over (partition by icustay_id order by charttime) = 1 then 1
              -- if there is less than 8 hours between vent settings, we do not treat this as a new ventilation event
              when MechVent = 1 
                and (CHARTTIME - (LAG(CHARTTIME, 1) OVER (partition by icustay_id, MechVent order by charttime))) > interval '8' hour 
                then 1 -- changed to >8 and then 1. Same logic but allow else to be 0. Also need to exclude when MechVent = 0 when considering 8 hrs. 
              when MechVent = 1 and LAG(charttime,1) over (partition by icustay_id, MechVent order by charttime) is null then 1 -- Ken: added to make sure first event is new event
              
            else 0 -- Ken: changed to 0 to avoid mis-classification
            end as newvent
      -- use the staging table with only vent settings from chart events
      FROM public.kentran_2_1_ventsettings2 ventsettings2
      order by icustay_id, charttime
  ) AS vd1
  -- now we can isolate to just rows with ventilation settings/extubation settings
  -- (before we had rows with extubation flags)
  -- this removes any null values for newvent
  where
    MechVent = 1 or Extubated = 1
) AS vd2
group by icustay_id, ventnum
order by icustay_id, ventnum;

select * from public.kentran_2_1_ventdurations; 