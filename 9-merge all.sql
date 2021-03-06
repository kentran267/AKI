set search_path to mimiciii;

drop table if exists public.kentran_9_1_table_global;
with tab1 as
(

select demo.*
	, sofa.sofa
	, sofa.respiration as sofa_respi
	, sofa.coagulation as sofa_coag
	, sofa.liver as sofa_liver
	, sofa.cardiovascular as sofa_cv
	, sofa.cns as sofa_neuro
	, sofa.renal as sofa_renal
	, sapsii.sapsii
	, apsiii.apsiii
	, table_hemodyn.mabp
	, table_hemodyn.day
	, table_hemodyn.cvp
	, table_hemodyn.mpp

from public.kentran_1_3_demographics_nockd demo
left join public.sofa sofa on demo.icustay_id=sofa.icustay_id
left join public.sapsii sapsii on demo.icustay_id=sapsii.icustay_id
left join public.apsiii apsiii on demo.icustay_id=apsiii.icustay_id
left join public.kentran_5_2_table_hemodyn table_hemodyn on demo.icustay_id=table_hemodyn.icustay_id
)
--select * from tab1

, tab2 as   
(
select tab1.*
	, tab_dobutamine.dobutamine
	, tab_dopamine.dopamine
	, tab_epi.epi
	, tab_norepi.norepi
	, tab_vasopressine.vasopressine
	, table_peep.avg_peep
	, table_peep.max_peep
	, table_peep.peep_time
	, table_paw.avg_paw
	, table_paw.max_paw
	, table_paw.paw_time
	, table_pplat.avg_pplat
	, table_pplat.max_pplat
	, table_pplat.pplat_time
	, tab_creat.creat
	, tab_urine.urine_24h_kgh
	, tab_urine.urine_12h_kgh_1
	, tab_urine.urine_12h_kgh_2
	, tab_urine.urine_6h_kgh_1
	, tab_urine.urine_6h_kgh_2
	, tab_urine.urine_6h_kgh_3
	, tab_urine.urine_6h_kgh_4
	, tab_rrt.rrt
	, tab_kdigo.max_kdigo		
from tab1


--
left join public.kentran_7_1_tab_dobutamine tab_dobutamine 
on tab1.icustay_id=tab_dobutamine.icustay_id and tab1.day=tab_dobutamine.day

left join public.kentran_7_1_tab_dopamine tab_dopamine 
on tab1.icustay_id=tab_dopamine.icustay_id and tab1.day=tab_dopamine.day

left join public.kentran_7_1_tab_epi tab_epi 
on tab1.icustay_id=tab_epi.icustay_id and tab1.day=tab_epi.day

left join public.kentran_7_1_tab_norepi tab_norepi 
on tab1.icustay_id=tab_norepi.icustay_id and tab1.day=tab_norepi.day

left join public.kentran_7_1_tab_vasopressine tab_vasopressine 
on tab1.icustay_id=tab_vasopressine.icustay_id and tab1.day=tab_vasopressine.day

left join public.kentran_4_1_table_peep table_peep 
on tab1.icustay_id=table_peep.icustay_id and tab1.day=table_peep.day

left join public.kentran_4_2_table_paw table_paw 
on tab1.icustay_id=table_paw.icustay_id and tab1.day=table_paw.day

left join public.kentran_4_3_table_pplat table_pplat 
on tab1.icustay_id=table_pplat.icustay_id and tab1.day=table_pplat.day

--

left join public.kentran_8_1_table_creat as tab_creat
on tab1.icustay_id=tab_creat.icustay_id and tab1.day=tab_creat.day

left join public.kentran_8_2_table_urine_pivot as tab_urine
on tab1.icustay_id=tab_urine.icustay_id and tab1.day=tab_urine.day_24h

left join public.kentran_8_3_table_rrt as tab_rrt
on tab1.icustay_id=tab_rrt.icustay_id and tab1.day=tab_rrt.day

left join public.kentran_8_4_table_kdigo_daily as tab_kdigo
on tab1.icustay_id=tab_kdigo.icustay_id and tab1.day=tab_kdigo.day_24h

)
select * into public.kentran_9_1_table_global 
from tab2 order by subject_id, admittime;

select * from public.kentran_9_1_table_global;






