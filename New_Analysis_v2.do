* === Last Revised 5/19/26 ===

clear all

import delimited using "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/cases/Benton vs Richland/Benton vs Richland_Final_RDD_Dataset_newgeo.csv", clear

* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* SETUP
* =============================================================================
* Recall: in_ter1 = Benton, in_ter2 = Richland. 
set scheme s2color

foreach var in inc_type_num inc_type_rand_num group_num htc_num incentpct incentpct_rand prog_year_5 l_home_value l_live_square_feet l_e_rate l_g_rate l_bldg_age l_stories l_income l_income_rand l_actual_incent L_actual_incent_rand l_actual_incent_rand Year_* in_range in_type in_inc in_inc_rand included included included pre_2010 hp_dif2 l_resdents l_residents_rand hp_dif_cumu2 hp_dif_cumu_15_2 prog_age l_prog_age full_set treat post count_hh l_residents l_residents_rand not_new prior_htc renovation prog_novelty L_htc_num prior_htc_num builtgroup builtgroup_num first_year prior_heating_type started_pre2015 erate_alt l_square_feet baseline_inc baseline_inc_rand switch prog_novelty_num L_* l_* inc_type_num_rand area n_obs fuel_num switch_str switch_type htc_dif l_erate_alt{
    cap drop `var'
}

gen prog_age = .
	replace prog_age = year_revised - 2014 if missing(prog_age) & in_ter1==1
	replace prog_age = year_revised - 1981 if missing(prog_age) & in_ter1==0
tostring prog_age, gen(prog_novelty) 
encode prog_novelty, gen(prog_novelty_num)
egen area= group(geoid_blk in_ter1)
gen hp_dif_cumu2 = hp_dif_cumu
cap drop hp_dif
cap drop hp_dif_cumu
cap drop hp_dif_cumu_15
xtset hh_id_num year_revised
bysort hh_id_num (year_revised): gen hp_dif = hp - L.hp
replace hp_dif = 0 if year_revised<=year_built+1

bys hh_id_num (year_revised): gen hp_dif_cumu = sum(hp_dif)
bys hh_id_num (year_revised): gen hp_dif_cumu_15 = hp_dif_cumu - (sum(hp_dif)*(year_revised<2015))
replace hp_dif_cumu_15 = . if year_revised<2015
sort hh_id year_revised
gen l_square_feet = ln(square_feet)


bysort hh_id (year_revised): gen first_year = year_revised[1]
gen started_pre2015 = first_year < 2015
bys hh_id_num: gen n_obs = _N

drop if heating_type == "type_unknown"
drop if missing(heating_type)

xtset hh_id_num year_revised
encode fuel_type, gen(fuel_num)
encode qual_type, gen(inc_type_num)
encode qual_type_rand, gen(inc_type_num_rand)
bysort hh_id_num (year_revised): gen baseline_inc = inc_type_num[1]
bysort hh_id_num (year_revised): gen baseline_inc_rand = inc_type_num_rand[1]
encode group, gen(group_num)
encode heating_type, gen(htc_num)
gen prior_htc_num = L.htc_num
recast long prior_htc_num

gen builtgroup = cond(year_built<2010, "Pre-2010", string(year_built))
encode builtgroup, gen(builtgroup_num)
gen incentpct = actual_incent / income
gen incentpct_rand = actual_incent_rand / income_rand 
gen prog_year_5 = prog_age+5
gen l_prog_age = log(prog_age)
gen l_home_value = log(home_value)
gen l_live_square_feet = log(live_square_feet)
gen l_e_rate = log(e_rate)
gen l_g_rate = log(g_rate)
gen l_bldg_age = log(bldg_age)
gen l_stories = log(stories)
gen l_residents = log(residents)
gen l_residents_rand = log(residents_rand)
gen l_income = log(income)
gen l_income_rand = log(income_rand)
gen l_actual_incent = 0 
replace l_actual_incent = log(actual_incent) if actual_incent>0
gen l_actual_incent_rand = 0
replace l_actual_incent_rand = log(actual_incent_rand) if actual_incent>0
tabulate year_revised, generate(Year_)
gen in_type = luse_clean==163
gen post = year_revised >= 2015
gen treat = post * in_ter1
cap drop L_treat 
cap drop L_actual_incent
cap drop L_inc_type_num
bysort hh_id_num (year_revised): gen L_treat = L.treat
bysort hh_id_num (year_revised): gen L_actual_incent = L.actual_incent
bysort hh_id_num (year_revised): gen L_actual_incent_rand = L.actual_incent_rand
bysort hh_id_num (year_revised): gen L_inc_type_num = L.inc_type_num
bysort hh_id_num (year_revised): gen L_inc_type_num_rand = L.inc_type_num_rand

xtset hh_id_num year_revised
gen L_htc_num = L.htc_num
gen L_new_build = L.new_build
gen L_l_home_value = L.l_home_value
gen L_l_square_feet = L.l_square_feet
gen L_l_stories = L.l_stories
gen L_l_income = L.l_income
gen L_l_income_rand = L.l_income_rand
gen L_l_bldg_age = L.l_bldg_age

xtset hh_id_num year_revised
by hh_id_num (year_revised): gen renovation = (_n>1) ///
    & (square_feet != L.square_feet) ///
    & (square_feet == F.square_feet) ///
    & (sum(square_feet == square_feet[1]) == 1)
by hh_id_num (year_revised): replace renovation = 1 if F.renovation == 1 & renovation == 0
by hh_id_num (year_revised): replace renovation = 0 if L.renovation == 1 & renovation == 1
by hh_id_num (year_revised): gen switch = htc_num != L.htc_num

gen str switch_str = cond(prior_htc_num == htc_num | prior_htc_num == ., "no switch", string(prior_htc_num) + "->" + string(htc_num))
encode switch_str, gen(switch_type)

egen count_hh = count(hh_id)
gen full_set = count_hh >= 12 
gen pre_2010 = year_built < 2010
gen not_new = new_build == 0

gen in_inc = income <= 3*pov_limit
gen in_inc_rand = income_rand <= 3*pov_limit_rand
scalar range = 1000
gen in_range = (distance >= -1*range) & (distance <= range)
gen included = in_range * in_type 

gen erate_alt = .
 
replace erate_alt = 0.0739 if in_ter1==1 & year_revised>=2020
replace erate_alt = 0.0741 if in_ter1==0 & year_revised>=2020
replace erate_alt = 0.0718 if in_ter1==1 & year_revised<=2019 
replace erate_alt = 0.0686 if in_ter1==0 & year_revised<=2019
replace erate_alt = 0.0644 if in_ter1==0 & year_revised<=2017 
replace erate_alt = 0.0616 if in_ter1==0 & year_revised<=2015 // assumed
replace erate_alt = 0.0684 if in_ter1==1 & year_revised<=2015
replace erate_alt = 0.0649 if in_ter1==1 & year_revised==2011
replace erate_alt = 0.0605 if in_ter1==1 & year_revised==2010
gen l_erate_alt = ln(erate_alt)
gen L_l_erate_alt = L.l_erate_alt

tab year_revised in_ter1, summarize(erate_alt)

cap drop at_risk
cap drop switch
cap drop everswitch
cap drop at_risk_age
cap drop at_risk_hp
xtset hh_id_num year_revised
gen switch = 0
bys hh_id_num (year_revised): replace switch = 1 if htc_num!=L.htc_num
bys hh_id_num (year_revised): replace switch = 0 if year_revised == year_revised[1] 
bys hh_id_num: egen everswitch = max(switch)
gen at_risk = 1
bys hh_id_num (year_revised): replace at_risk = 0 if L.switch==1
bys hh_id_num: replace at_risk = 0 if year_built==year_revised | year_built == year 
bys hh_id_num (year_revised): replace at_risk = 0 if L.at_risk == 0
gen at_risk_age = at_risk
bys hh_id_num (year_revised): replace at_risk_age = 0 if year_revised - year_built<=15  
gen at_risk_hp = at_risk
bys hh_id_num (year_revised): replace at_risk_hp = 0 if L.hp == 1


* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================

tabulate renter_occupied year_revised if in_type==1


* =============================================================================
* Start with graph of difference in adoption
* =============================================================================

*----------------------------------------
* 1. Overall
*----------------------------------------

preserve
collapse (mean) mean_hp=hp (sem) se_hp=hp if in_type == 1, by(in_ter2 year_revised)
gen ci_lower = mean_hp - 1.96 * se_hp
gen ci_upper = mean_hp + 1.96 * se_hp
twoway (line mean_hp year_revised if in_ter2 == 1, lcolor(red)) /// 
  (line mean_hp year_revised if in_ter2 == 0, lcolor(blue)) ///
  (rarea ci_lower ci_upper year_revised if in_ter2 == 1, color(red%30)) /// 
  (rarea ci_lower ci_upper year_revised if in_ter2 == 0, color(blue%30)), /// 
    xlabel(2010(1)2021, angle(45)) ylabel(, angle(horizontal)) ///
	ylabel(0(0.1)0.3, angle(horizontal)) /// 
  legend(order(1 "Richland" 2 "Benton")) /// 
  xtitle("Year") ytitle("Fraction Using Heat Pumps") 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_use.png", replace
restore

*----------------------------------------
* 2. Income-Specific Heat Pump Use
*----------------------------------------
foreach inc in low mid high {
	preserve
	collapse (mean) mean_hp=hp (sem) se_hp=hp if in_type == 1 & `inc'_inc_qual==1, by(in_ter2 year_revised)
	gen ci_lower = mean_hp - 1.96 * se_hp
	gen ci_upper = mean_hp + 1.96 * se_hp
	tempfile sorted
	save `sorted'
	restore
	preserve
	collapse (mean) mean_hp=hp (sem) se_hp=hp if in_type == 1 & `inc'_inc_qual_rand==1, by(in_ter2 year_revised)
	gen ci_lower = mean_hp - 1.96 * se_hp
	gen ci_upper = mean_hp + 1.96 * se_hp
	tempfile rand
	save `rand'
	restore
	preserve
	use `sorted', clear
	rename (mean_hp se_hp ci_lower ci_upper) (mean_hp_actual se_hp_actual ci_lower_a ci_upper_a)
	merge 1:1 in_ter2 year_revised using `rand', nogen
	rename (mean_hp se_hp ci_lower ci_upper) (mean_hp_rand se_hp_rand ci_lower_r ci_upper_r)
	gen lower_area = min(mean_hp_actual, mean_hp_rand)
	gen upper_area = max(mean_hp_actual, mean_hp_rand)
	gen ci_upper_combined = max(ci_upper_a, ci_upper_r)
	gen ci_lower_combined = min(ci_lower_a, ci_lower_r)
	gen mean_hp_combined = (mean_hp_actual + mean_hp_rand)/2
	twoway ///
		(rarea lower_area upper_area year_revised if in_ter2==1, color(red%30)) /// 
		(rarea ci_lower_combined ci_upper_combined year_revised if in_ter2 == 1, color(red%30)) /// 
		(rarea lower_area upper_area year_revised if in_ter2==0, color(blue%30)) ///  
		(rarea ci_lower_combined ci_upper_combined year_revised if in_ter2 == 0, color(blue%30)) ///
		(line mean_hp_combined year_revised if in_ter2==1, lcolor(red) lpattern(solid)) ///
		(line mean_hp_combined year_revised if in_ter2==0, lcolor(blue) lpattern(solid)), ///
		xlabel(2010(1)2021, angle(45)) ///
		ylabel(0(0.1)0.35, angle(horizontal)) ///
		legend(order(5 "Richland" 6 "Benton") cols(1)) ///
		xtitle("Year") ///
		ytitle("Fraction Using Heat Pumps") ///
		title("Heat Pump Use Among `=proper("`inc'")'-Income Households")
	graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_use_`inc'.png", replace
	restore
}


* =============================================================================
* Adoption Rate Differences
* =============================================================================

*----------------------------------------
* 1. Overall
*----------------------------------------

preserve
collapse (mean) mean_hp=hp_dif (sem) se_hp=hp_dif if in_type == 1, by(in_ter2 year_revised)
gen ci_lower = mean_hp - 1.96 * se_hp
gen ci_upper = mean_hp + 1.96 * se_hp
twoway (line mean_hp year_revised if in_ter2 == 1, lcolor(red)) /// 
  (line mean_hp year_revised if in_ter2 == 0, lcolor(blue)) ///
  (rarea ci_lower ci_upper year_revised if in_ter2 == 1, color(red%30)) /// 
  (rarea ci_lower ci_upper year_revised if in_ter2 == 0, color(blue%30)), /// 
    xlabel(2010(1)2021, angle(45)) ylabel(, angle(horizontal)) ///
	ylabel(-0.1(0.1)0.1, angle(horizontal)) /// 
  legend(order(1 "Richland" 2 "Benton")) /// 
  xtitle("Year") ytitle("Net Adoption of Heat Pumps") 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_adopt.png", replace
restore

*----------------------------------------
* 2. Income-Specific Heat Pump Adoption
*----------------------------------------
foreach inc in high mid low {
	preserve
	collapse (mean) mean_hp=hp_dif (sem) se_hp=hp_dif if in_type == 1 & `inc'_inc_qual==1, by(in_ter2 year_revised)
	gen ci_lower = mean_hp - 1.96 * se_hp
	gen ci_upper = mean_hp + 1.96 * se_hp
	tempfile sorted
	save `sorted'
	restore
	preserve
	collapse (mean) mean_hp=hp_dif (sem) se_hp=hp_dif if in_type == 1 & `inc'_inc_qual_rand==1, by(in_ter2 year_revised)
	gen ci_lower = mean_hp - 1.96 * se_hp
	gen ci_upper = mean_hp + 1.96 * se_hp
	tempfile rand
	save `rand'
	restore
	preserve
	use `sorted', clear
	rename (mean_hp se_hp ci_lower ci_upper) (mean_hp_actual se_hp_actual ci_lower_a ci_upper_a)
	merge 1:1 in_ter2 year_revised using `rand', nogen
	rename (mean_hp se_hp ci_lower ci_upper) (mean_hp_rand se_hp_rand ci_lower_r ci_upper_r)
	gen lower_area = min(mean_hp_actual, mean_hp_rand)
	gen upper_area = max(mean_hp_actual, mean_hp_rand)
	gen ci_upper_combined = max(ci_upper_a, ci_upper_r)
	gen ci_lower_combined = min(ci_lower_a, ci_lower_r)
	gen mean_hp_combined = (mean_hp_actual+mean_hp_rand)/2
	twoway ///
		(rarea ci_lower_combined ci_upper_combined year_revised if in_ter2 == 1, color(red%30)) /// 
		(rarea ci_lower_combined ci_upper_combined year_revised if in_ter2 == 0, color(blue%30)) ///
		(line mean_hp_combined year_revised if in_ter2==1, lcolor(red) lpattern(solid)) ///
		(line mean_hp_combined year_revised if in_ter2==0, lcolor(blue) lpattern(solid)), ///
		xlabel(2010(1)2021, angle(45)) ///
		ylabel(-0.1(0.1)0.3, angle(horizontal)) ///
		legend(order(3 "Richland" 4 "Benton") cols(1)) ///
		xtitle("Year") ///
		ytitle("Fraction Using Heat Pumps") ///
		title("Heat Pump Net Adoption Among `=proper("`inc'")'-Income Households")
	graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_adopt_`inc'.png", replace
	restore
}


* =============================================================================
* RD Pre-2015 / Post-2015 for Equilibrium & Policy Discussion
* =============================================================================

* Pre-2015 ====================================================================

foreach inc in high mid low {
	local covs "L_htc_num L_new_build L_l_home_value L_l_square_feet L_l_stories L_l_income L_l_bldg_age L_l_erate_alt"
	local covs_r "L_htc_num L_new_build L_l_home_value L_l_square_feet L_l_stories L_l_income_rand L_l_bldg_age"
    local params   "in_type==1 & year_revised == 2014 & abs(distance)<=1000 & `inc'_inc_qual==1"
    local params_r "in_type==1 & year_revised == 2014 & abs(distance)<=1000 & `inc'_inc_qual_rand==1"

    rdrobust hp_dif_cumu distance if `params', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
        eststo post_rd_`inc'_nc
        scalar bwl         = e(h_l)
        scalar bwr         = e(h_r)
        scalar intercept_l = e(beta_p_l)[1,1]
        scalar intercept_r = e(beta_p_r)[1,1]

    rdrobust hp_dif_cumu distance if `params_r', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
        eststo post_rd_`inc'_nc_r
        scalar bwl_r         = e(h_l)
        scalar bwr_r         = e(h_r)
        scalar intercept_l_r = e(beta_p_l)[1,1]
        scalar intercept_r_r = e(beta_p_r)[1,1]

    cap drop lprobust_* 
	cap drop left_* 
	cap drop right_*

    * --- Left: treatment ---
    lprobust hp_dif_cumu distance if `params' & distance<0, ///
        p(1) h(`=bwl') kernel(epa) neval(100) genvars
    rename lprobust_eval    left_eval
    rename lprobust_gx_us   left_hat
    rename lprobust_CI_l_rb left_cil
    rename lprobust_CI_r_rb left_ciu
    drop lprobust_*

    * --- Left: random ---
    cap drop lprobust_*
    lprobust hp_dif_cumu distance if `params_r' & distance<0, ///
        p(1) h(`=bwl_r') kernel(epa) neval(100) genvars
    rename lprobust_gx_us   left_hat_r
    rename lprobust_CI_l_rb left_cil_r
    rename lprobust_CI_r_rb left_ciu_r
    drop lprobust_*

    * --- Right: treatment ---
    cap drop lprobust_*
    lprobust hp_dif_cumu distance if `params' & distance>=0, ///
        p(1) h(`=bwr') kernel(epa) neval(100) genvars
    rename lprobust_eval    right_eval
    rename lprobust_gx_us   right_hat
    rename lprobust_CI_l_rb right_cil
    rename lprobust_CI_r_rb right_ciu
    drop lprobust_*

    * --- Right: random ---
    cap drop lprobust_*
    lprobust hp_dif_cumu distance if `params_r' & distance>=0, ///
        p(1) h(`=bwr_r') kernel(epa) neval(100) genvars
    rename lprobust_gx_us   right_hat_r
    rename lprobust_CI_l_rb right_cil_r
    rename lprobust_CI_r_rb right_ciu_r
    drop lprobust_*

    * --- Construct envelope CI and average line ---
    gen left_hat_avg  = (left_hat  + left_hat_r)  / 2
    gen right_hat_avg = (right_hat + right_hat_r) / 2

    gen left_cil_env  = min(left_cil,  left_cil_r)
    gen left_ciu_env  = max(left_ciu,  left_ciu_r)
    gen right_cil_env = min(right_cil, right_cil_r)
    gen right_ciu_env = max(right_ciu, right_ciu_r)

    * --- Average cutoff intercepts for scatteri ---
    local il_avg = (intercept_l   + intercept_l_r) / 2
    local ir_avg = (intercept_r   + intercept_r_r) / 2

    twoway ///
        (rarea left_cil_env  left_ciu_env  left_eval,  fcolor(blue%25)      lwidth(none)) ///
        (rarea right_cil_env right_ciu_env right_eval,  fcolor(red%25) lwidth(none)) ///
        (line  left_hat_avg  left_eval,                 lcolor(blue)         lwidth(medthick)) ///
        (line  right_hat_avg right_eval,                lcolor(red)    lwidth(medthick)) ///
        (scatteri `il_avg' 0 `ir_avg' 0, ///
            msymbol(circle) mcolor(black) msize(medium)), ///
        xline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
        xtitle("Distance") ytitle("Fraction of Households") ///
        legend(off) graphregion(color(white))
	graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/1. Current Draft/Figures/rdd_`inc'_pre.png", replace

    cap drop left_* right_*
}

* Post-2015 ===================================================================

foreach inc in high mid low {
	local covs "L_htc_num L_new_build L_l_home_value L_l_square_feet L_l_stories L_l_income L_l_bldg_age L_l_erate_alt"
	local covs_r "L_htc_num L_new_build L_l_home_value L_l_square_feet L_l_stories L_l_income_rand L_l_bldg_age"
    local params   "in_type==1 & year_revised == 2020 & abs(distance)<=1000 & `inc'_inc_qual==1"
    local params_r "in_type==1 & year_revised == 2020 & abs(distance)<=1000 & `inc'_inc_qual_rand==1"

    rdrobust hp_dif_cumu_15 distance if `params', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
        eststo post_rd_`inc'_nc
        scalar bwl         = e(h_l)
        scalar bwr         = e(h_r)
        scalar intercept_l = e(beta_p_l)[1,1]
        scalar intercept_r = e(beta_p_r)[1,1]

    rdrobust hp_dif_cumu_15 distance if `params_r', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
        eststo post_rd_`inc'_nc_r
        scalar bwl_r         = e(h_l)
        scalar bwr_r         = e(h_r)
        scalar intercept_l_r = e(beta_p_l)[1,1]
        scalar intercept_r_r = e(beta_p_r)[1,1]

    cap drop lprobust_* 
	cap drop left_* 
	cap drop right_*

    * --- Left: treatment ---
    lprobust hp_dif_cumu_15 distance if `params' & distance<0, ///
        p(1) h(`=bwl') kernel(epa) neval(100) genvars
    rename lprobust_eval    left_eval
    rename lprobust_gx_us   left_hat
    rename lprobust_CI_l_rb left_cil
    rename lprobust_CI_r_rb left_ciu
    drop lprobust_*

    * --- Left: random ---
    cap drop lprobust_*
    lprobust hp_dif_cumu_15 distance if `params_r' & distance<0, ///
        p(1) h(`=bwl_r') kernel(epa) neval(100) genvars
    rename lprobust_gx_us   left_hat_r
    rename lprobust_CI_l_rb left_cil_r
    rename lprobust_CI_r_rb left_ciu_r
    drop lprobust_*

    * --- Right: treatment ---
    cap drop lprobust_*
    lprobust hp_dif_cumu_15 distance if `params' & distance>=0, ///
        p(1) h(`=bwr') kernel(epa) neval(100) genvars
    rename lprobust_eval    right_eval
    rename lprobust_gx_us   right_hat
    rename lprobust_CI_l_rb right_cil
    rename lprobust_CI_r_rb right_ciu
    drop lprobust_*

    * --- Right: random ---
    cap drop lprobust_*
    lprobust hp_dif_cumu_15 distance if `params_r' & distance>=0, ///
        p(1) h(`=bwr_r') kernel(epa) neval(100) genvars
    rename lprobust_gx_us   right_hat_r
    rename lprobust_CI_l_rb right_cil_r
    rename lprobust_CI_r_rb right_ciu_r
    drop lprobust_*

    * --- Construct envelope CI and average line ---
    gen left_hat_avg  = (left_hat  + left_hat_r)  / 2
    gen right_hat_avg = (right_hat + right_hat_r) / 2

    gen left_cil_env  = min(left_cil,  left_cil_r)
    gen left_ciu_env  = max(left_ciu,  left_ciu_r)
    gen right_cil_env = min(right_cil, right_cil_r)
    gen right_ciu_env = max(right_ciu, right_ciu_r)

    * --- Average cutoff intercepts for scatteri ---
    local il_avg = (intercept_l   + intercept_l_r) / 2
    local ir_avg = (intercept_r   + intercept_r_r) / 2

    twoway ///
        (rarea left_cil_env  left_ciu_env  left_eval,  fcolor(blue%25)      lwidth(none)) ///
        (rarea right_cil_env right_ciu_env right_eval,  fcolor(red%25) lwidth(none)) ///
        (line  left_hat_avg  left_eval,                 lcolor(blue)         lwidth(medthick)) ///
        (line  right_hat_avg right_eval,                lcolor(red)    lwidth(medthick)) ///
        (scatteri `il_avg' 0 `ir_avg' 0, ///
            msymbol(circle) mcolor(black) msize(medium)), ///
        xline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
        xtitle("Distance") ytitle("Fraction of Households") ///
        legend(off) graphregion(color(white))
	graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/1. Current Draft/Figures/rdd_`inc'_post.png", replace

    cap drop left_* right_*
}

*----------------------------------------
* 5. Income-Specific Heat Pump Adoption Table
*----------------------------------------

*
esttab pre_rd_low pre_rd_low_r pre_rd_mid pre_rd_mid_r pre_rd_high pre_rd_high_r, ///
    keep(RD_Estimate) b(%9.4fc) se(%9.4fc) nomtitle nonumber noobs noline ///
    scalars("ci_rb Robust 95\% CI" "pv_rb Robust p-value" "N Observations") ///
    sfmt(%9.4fc %9.4fc %9.0fc)

*Table 5 pre
esttab pre_rd_low_nc pre_rd_low_r_nc pre_rd_mid_nc pre_rd_mid_r_nc pre_rd_high_nc pre_rd_high_r_nc, ///
    keep(RD_Estimate) b(%9.4fc) se(%9.4fc) nomtitle nonumber noobs noline ///
    scalars("ci_rb Robust 95\% CI" "pv_rb Robust p-value" "N Observations") ///
    sfmt(%9.4fc %9.4fc %9.0fc)
	
* 
esttab post_rd_low post_rd_low_r post_rd_mid post_rd_mid_r post_rd_high post_rd_high_r, ///
    keep(RD_Estimate) b(%9.4fc) se(%9.4fc) nomtitle nonumber noobs noline ///
    scalars("ci_rb Robust 95\% CI" "pv_rb Robust p-value" "N Observations") ///
    sfmt(%9.4fc %9.4fc %9.0fc)
	
* Table 5 Post
esttab post_rd_low_nc post_rd_low_r_nc post_rd_mid_nc post_rd_mid_r_nc post_rd_high_nc post_rd_high_r_nc, ///
    keep(RD_Estimate) b(%9.4fc) se(%9.4fc) ///
    scalars("pv_rb P-val" "N Observations") ///
    sfmt(%9.4fc %9.0fc)
	
	

* =============================================================================
* Treatment Effects
* =============================================================================

*----------------------------------------
* TWFE INDIVIDUAL INCOME GROUPS
*----------------------------------------
*---- Prep -----------------------------------------
capture program drop add_lincom
program define add_lincom
    * arg 1: income type variable name (inc_type_num or inc_type_num_rand)
    args incvar
    
    lincom 1.post#1.in_ter1 + 2.L.`incvar'#1.post#1.in_ter1
    estadd scalar b_low  = r(estimate)
    estadd scalar se_low = r(se)
    estadd scalar p_low  = r(p)
    
    lincom 1.post#1.in_ter1 + 3.L.`incvar'#1.post#1.in_ter1
    estadd scalar b_mid  = r(estimate)
    estadd scalar se_mid = r(se)
    estadd scalar p_mid  = r(p)
end

cap drop ric_elig
cap drop ric_elig_rand
gen ric_elig = inc_type_num == 2 | inc_type_num == 3
gen ric_elig_rand = inc_type_num_rand == 2 | inc_type_num_rand == 3

* No Controls ----------------------------------------------
    * Full sample
    reghdfe hp_dif L.i.inc_type_num##i.post##i.in_ter1 ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_nc
	add_lincom inc_type_num

	* Full sample Random
    reghdfe hp_dif L.i.inc_type_num_rand##i.post##i.in_ter1 ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_nc_r
	add_lincom inc_type_num_rand

    * At risk
    reghdfe hp_dif L.i.inc_type_num##i.post##i.in_ter1 ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_risk_nc
	add_lincom inc_type_num

    * At risk Random
    reghdfe hp_dif L.i.inc_type_num_rand##i.post##i.in_ter1 ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_risk_nc_r
	add_lincom inc_type_num_rand

	
* All Controls ----------------------------------------------
    * Full sample
    reghdfe hp_dif L.i.inc_type_num##(i.post##i.in_ter1 ///
        L.(i.new_build i.renteroccupied c.l_home_value c.l_square_feet ///
           c.l_stories c.l_income c.l_bldg_age c.l_erate_alt) i.renovation) ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_ac
	add_lincom inc_type_num

	* Random
    reghdfe hp_dif L.i.inc_type_num_rand##(i.post##i.in_ter1 ///
        L.(i.new_build i.renter_occupied_random c.l_home_value c.l_square_feet ///
           c.l_stories c.l_income_rand c.l_bldg_age c.l_erate_alt) i.renovation) ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_ac_r
	add_lincom inc_type_num_rand

    * At risk
    reghdfe hp_dif L.i.inc_type_num##(i.post##i.in_ter1 ///
        L.(i.new_build i.renteroccupied c.l_home_value c.l_square_feet ///
           c.l_stories c.l_income c.l_bldg_age c.l_erate_alt) i.renovation) ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_risk_ac
	add_lincom inc_type_num

    * At risk Random
    reghdfe hp_dif L.i.inc_type_num_rand##(i.post##i.in_ter1 ///
        L.(i.new_build i.renter_occupied_random c.l_home_value c.l_square_feet ///
           c.l_stories c.l_income_rand c.l_bldg_age c.l_erate_alt) i.renovation) ///
        if in_type==1 & at_risk==1, coeflegend ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_twfe_risk_ac_r
	add_lincom inc_type_num_rand


*----------------------------------------
* Tabulate
*----------------------------------------

esttab t_twfe_nc t_twfe_nc_r t_twfe_ac t_twfe_ac_r ///
       t_twfe_risk_nc t_twfe_risk_nc_r t_twfe_risk_ac t_twfe_risk_ac_r, ///
	   rename(2L.inc_type_num_rand#1.post#1.in_ter1 "Low" 2L.inc_type_num#1.post#1.in_ter1 "Low" ///
	   3L.inc_type_num#1.post#1.in_ter1 "Mid" 3L.inc_type_num_rand#1.post#1.in_ter1 "Mid"  ///
	   1.post#1.in_ter1 "High") ///
       keep("Low" "Mid" "High" ) ///
       scalars(b_low se_low p_low b_mid se_mid p_mid) ///
       sfmt(%9.3fc %9.3fc %6.4f %9.3fc %9.3fc %6.4f) ///
       b(%9.3fc) se(%9.3fc) ///
       mlabels("Full" "Full (R)" "Full AC" "Full AC (R)" ///
               "Risk" "Risk (R)" "Risk AC" "Risk AC (R)") ///
       varlabels(1.post#1.in_ter1 "High Income (Treatment)" ///
                 b_low  "Low Income (level)"  ///
                 se_low "  SE"                ///
                 p_low  "  p-value"           ///
                 b_mid  "Mid Income (level)"  ///
                 se_mid "  SE"                ///
                 p_mid  "  p-value")          ///
       note("Columns alternate actual and randomised (R) income assignment." ///
            "High income is base category; low and mid are lincom level effects." ///
            "Standard errors clustered at area level.")
			

*----------------------------------------
* SENSITIVITY ANALYSIS: HOW MISALIGNED MUST INCOMES BE TO NULLIFY THIS FINDING? 
*----------------------------------------	
* Under income assignment, the rank-order income assignment shouldn't be the exact assignment found in the real world. How "wrong" must that assignment be to make the effects seen here null? 
* First, for different levels of misassignment, what must the actual B* be? 
* Second, Were the program actually having an impact as expected and B*_1 = 0 but B*_2 and B*_3 are >0, how wrong would income assignemnt have to be for that to show up? 


* --------- Given the results eariler, what is the likley ----------------------
* --------- B* if miscalssification is happening at a rate of \rho--------------

* ── Get observed betas first ─────────────────────────────────────────────
estimates restore t_twfe_risk_ac

lincom 1.post#1.in_ter1
scalar B_1  = r(estimate)
scalar SE_1 = r(se)

lincom 1.post#1.in_ter1 + 2.L.inc_type_num#1.post#1.in_ter1
scalar B_2  = r(estimate)
scalar SE_2 = r(se)

lincom 1.post#1.in_ter1 + 3.L.inc_type_num#1.post#1.in_ter1
scalar B_3  = r(estimate)
scalar SE_3 = r(se)

matrix bhat = (B_1 \ B_2 \ B_3)

* ── Collapse to tract-year level Ordered ──────────────────────────────────────
preserve
    keep if in_type==1
    collapse (mean) p_1_2 p_1_3 p_2_1 p_2_3 p_3_1 p_3_2 ///
             (firstnm) N_cell, ///
             by(tract_fips year_revised)

    * Total weight
    quietly summarize N_cell
    scalar N_total = r(sum)
    local nrows = _N

    * Initialize results matrix
    matrix results = J(6, 7, .)
    local row = 0

    foreach rho in 0.01 0.05 0.10 0.20 0.30 0.40 {
        local ++row

        * Accumulate weighted average of inverted matrices
        matrix Mavg = J(3, 3, 0)

        forvalues i = 1/`nrows' {

            * Local phis for this tract-year
            local phi_1_2 = p_1_2[`i']
            local phi_1_3 = p_1_3[`i']
            local phi_2_1 = p_2_1[`i']
            local phi_2_3 = p_2_3[`i']
            local phi_3_1 = p_3_1[`i']
            local phi_3_2 = p_3_2[`i']

            * Cell weight
            local w = N_cell[`i'] / N_total

            * Build local mixing matrix
            matrix Mc = ((1-`rho'),         (`rho'*`phi_2_1'), (`rho'*`phi_3_1') \ ///
                         (`rho'*`phi_1_2'), (1-`rho'),         (`rho'*`phi_3_2') \ ///
                         (`rho'*`phi_1_3'), (`rho'*`phi_2_3'), (1-`rho'))

            * Accumulate weighted inverse
            matrix Mavg = Mavg + `w' * Mc
        }

        * Apply weighted average inverse to observed betas
        matrix btrue = inv(Mavg) * bhat

        local b1s = btrue[1,1]
        local b2s = btrue[2,1]
        local b3s = btrue[3,1]
        local t1s = `b1s' / SE_1
        local t2s = `b2s' / SE_2
        local t3s = `b3s' / SE_3

        matrix results[`row', 1] = `rho'
        matrix results[`row', 2] = `b1s'
        matrix results[`row', 3] = `b2s'
        matrix results[`row', 4] = `b3s'
        matrix results[`row', 5] = `t1s'
        matrix results[`row', 6] = `t2s'
        matrix results[`row', 7] = `t3s'
    }
restore

* Display
display _newline "=== Implied True Effects: M(rho)^-1 * Bhat ==="
display "rho   | B1*       | B2*       | B3*       | t1*      | t2*      | t3*"
display "------+-----------+-----------+-----------+----------+----------+----------"
forvalues row = 1/6 {
    display %5.2f results[`row',1] " | " ///
        %9.5f results[`row',2] " | " ///
        %9.5f results[`row',3] " | " ///
        %9.5f results[`row',4] " | " ///
        %8.3f results[`row',5] " | " ///
        %8.3f results[`row',6] " | " ///
		%8.3f results[`row',7] " | "
}
 

* If B* = [0, >0, >0] what must \rho be? -----------------------------------


* ── Assumed true effects ─────────────────────────────────────────────────
* B*_1 = 0 (high income has no true effect)
* B*_2 = observed B_2 as lower bound (or set to any value)
* B*_3 = observed B_3 as lower bound

* You can change these to any economically meaningful values
scalar Bstar_1 = 0
scalar Bstar_2 = B_2    // or set manually e.g. scalar Bstar_2 = 0.02
scalar Bstar_3 = B_3   // or set manually e.g. scalar Bstar_3 = 0.02

matrix bstar = (Bstar_1 \ Bstar_2 \ Bstar_3)

* ── Search over rho ──────────────────────────────────────────────────────
preserve
    keep if in_type==1
    collapse (mean) p_1_2 p_1_3 p_2_1 p_2_3 p_3_1 p_3_2 ///
             (firstnm) N_cell, ///
             by(tract_fips year_revised)

    foreach var in p_1_2 p_1_3 p_2_1 p_2_3 p_3_1 p_3_2 N_cell {
        drop if missing(`var')
    }

    quietly summarize N_cell
    scalar N_total = r(sum)
    local nrows = _N

    * Initialize results — 99 rows for rho = 0.01 to 0.99
    matrix results_inv = J(99, 5, .)

    forvalues j = 1/99 {
        local rho = `j' / 100

        * Accumulate weighted average M(rho) — NOT inverted this time
        * because we want M(rho)*bstar and compare to bhat
        matrix Mavg = J(3, 3, 0)

        forvalues i = 1/`nrows' {
            local phi_1_2 = p_1_2[`i']
            local phi_1_3 = p_1_3[`i']
            local phi_2_1 = p_2_1[`i']
            local phi_2_3 = p_2_3[`i']
            local phi_3_1 = p_3_1[`i']
            local phi_3_2 = p_3_2[`i']
            local w       = N_cell[`i'] / N_total

            if missing(`phi_1_2') | missing(`phi_2_1') | ///
               missing(`phi_1_3') | missing(`phi_3_1') | ///
               missing(`phi_2_3') | missing(`phi_3_2') continue

            matrix Mc = ((1-`rho'),           (`rho'*`phi_2_1'), (`rho'*`phi_3_1') \ ///
                         (`rho'*`phi_1_2'), (1-`rho'),           (`rho'*`phi_3_2') \ ///
                         (`rho'*`phi_1_3'), (`rho'*`phi_2_3'), (1-`rho'))

            matrix Mavg = Mavg + `w' * Mc
        }

        * Implied observed betas if true betas are bstar
        matrix bhat_implied = Mavg * bstar

        * How far are implied betas from actual observed betas?
        local b1_imp = bhat_implied[1,1]
        local b2_imp = bhat_implied[2,1]
        local b3_imp = bhat_implied[3,1]

        * Distance between implied and observed
        local dist = sqrt((`b1_imp' - B_1)^2 + ///
                          (`b2_imp' - B_2)^2 + ///
                          (`b3_imp' - B_3)^2)

        matrix results_inv[`j', 1] = `rho'
        matrix results_inv[`j', 2] = `b1_imp'
        matrix results_inv[`j', 3] = `b2_imp'
        matrix results_inv[`j', 4] = `b3_imp'
        matrix results_inv[`j', 5] = `dist'
    }

restore

* ── Display: find rho that minimises distance ────────────────────────────
display _newline "=== Inverted Analysis: rho needed to produce Bhat from Bstar ==="
display "Assumed: Bstar_1=0, Bstar_2=" %6.4f Bstar_2 ", Bstar_3=" %6.4f Bstar_3
display _newline "rho   | B1_imp    | B2_imp    | B3_imp    | distance"
display "------+-----------+-----------+-----------+----------"

* Find minimum distance row
local min_dist = 999
local min_rho  = .

forvalues j = 1/99 {
    local dist = results_inv[`j', 5]
    if `dist' < `min_dist' {
        local min_dist = `dist'
        local min_rho  = results_inv[`j', 1]
    }
    * Print rows near minimum
    if `dist' < 0.002 {
        display %5.2f results_inv[`j',1] " | " ///
            %9.5f results_inv[`j',2] " | " ///
            %9.5f results_inv[`j',3] " | " ///
            %9.5f results_inv[`j',4] " | " ///
            %9.6f results_inv[`j',5]
    }
}

scalar rho0  = 0.10
scalar odds0 = rho0 / (1 - rho0)

scalar rho_inv   = `min_rho'
scalar Gamma_inv = (rho_inv / (1-rho_inv)) / odds0

display _newline "Best matching rho: " %6.4f `min_rho'
display "Minimum distance:  " %9.6f `min_dist'
display "Gamma:             " %6.3f Gamma_inv

* --- What's needed to hide a true effect so \beta ----------------------------

* ── Grid of hypothetical true differentials ─────────────────────────────
* For each assumed true delta_2* = B2*-B1* and delta_3* = B3*-B1*,
* find rho that minimises distance between M(rho)*bstar and bhat

* Define grid of hypothetical true differentials
* Positive values = qualified groups truly have higher effects than high income
* Zero = equal effects
* Negative = qualified groups truly have lower effects (the anomaly is real)

local delta_vals "-0.02 -0.01 0.00 0.01 0.02 0.03 0.04 0.05"

* Keep B1* free — set to observed B_1 as neutral assumption
* Then B2* = B1* + delta2, B3* = B1* + delta3

display _newline "=== Minimum rho needed to mask true differential ==="
display "delta2* | delta3* | rho*(low) | rho*(mid) | Gamma(low) | Gamma(mid)"
display "--------+---------+-----------+-----------+------------+-----------"

preserve
    keep if in_type==1
    collapse (mean) p_1_2 p_1_3 p_2_1 p_2_3 p_3_1 p_3_2 ///
             (firstnm) N_cell, ///
             by(tract_fips year_revised)

    foreach var in p_1_2 p_1_3 p_2_1 p_2_3 p_3_1 p_3_2 N_cell {
        drop if missing(`var')
    }

    quietly summarize N_cell
    scalar N_total = r(sum)
    local nrows = _N

    foreach d2 of local delta_vals {
        foreach d3 of local delta_vals {

            * Assumed true effects
            * B1* = B_1 (high income true effect — left unrestricted)
            * B2* = B_1 + d2
            * B3* = B_1 + d3
            scalar Bstar_1 = B_1
            scalar Bstar_2 = B_1 + `d2'
            scalar Bstar_3 = B_1 + `d3'
            matrix bstar = (Bstar_1 \ Bstar_2 \ Bstar_3)

            * Search over rho
            local min_dist2 = 999
            local min_dist3 = 999
            local min_rho2  = .
            local min_rho3  = .

            forvalues j = 1/99 {
                local rho = `j' / 100

                matrix Mavg = J(3, 3, 0)

                forvalues i = 1/`nrows' {
                    local phi_1_2 = p_1_2[`i']
                    local phi_1_3 = p_1_3[`i']
                    local phi_2_1 = p_2_1[`i']
                    local phi_2_3 = p_2_3[`i']
                    local phi_3_1 = p_3_1[`i']
                    local phi_3_2 = p_3_2[`i']
                    local w       = N_cell[`i'] / N_total

                    if missing(`phi_1_2') | missing(`phi_2_1') | ///
                       missing(`phi_1_3') | missing(`phi_3_1') | ///
                       missing(`phi_2_3') | missing(`phi_3_2') continue

                    matrix Mc = ((1-`rho'),           (`rho'*`phi_2_1'), (`rho'*`phi_3_1') \ ///
                                 (`rho'*`phi_1_2'), (1-`rho'),           (`rho'*`phi_3_2') \ ///
                                 (`rho'*`phi_1_3'), (`rho'*`phi_2_3'), (1-`rho'))

                    matrix Mavg = Mavg + `w' * Mc
                }

                matrix bhat_implied = Mavg * bstar

                * Distance for low income (B2 differential)
                local dist2 = abs(bhat_implied[2,1] - B_2)
                if `dist2' < `min_dist2' {
                    local min_dist2 = `dist2'
                    local min_rho2  = `rho'
                }

                * Distance for mid income (B3 differential)
                local dist3 = abs(bhat_implied[3,1] - B_3)
                if `dist3' < `min_dist3' {
                    local min_dist3 = `dist3'
                    local min_rho3  = `rho'
                }
            }

            * Gamma values
            local Gamma2 = (`min_rho2'/(1-`min_rho2')) / odds0
            local Gamma3 = (`min_rho3'/(1-`min_rho3')) / odds0

            display %7.4f `d2' "  | " %7.4f `d3' "  | " ///
                %9.4f `min_rho2' "  | " %9.4f `min_rho3' "  | " ///
                %10.3f `Gamma2' "  | " %9.3f `Gamma3'
        }
    }

restore



* =============================================================================
* =============================================================================	
* =============================================================================		
* =============================================================================
* Incentive Effects
* =============================================================================

* Income Group Estimation =====================================================

foreach g in 1 3 2{
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"
*----------------------------------------
* IVFE 
*----------------------------------------
	xtset hh_id_num year_revised

*-------Ordered--------------------------
	* IVFE no con
	ivreghdfe hp_dif (L.l_actual_incent = L.treat) if in_type==1 & L.inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) 
	eststo i_ivfe`g'_nc

	* IVFE all con
	xtset hh_id_num year_revised
	ivreghdfe hp_dif (L.l_actual_incent = L.treat) L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo i_ivfe`g'_ac

*-------Random--------------------------
	* IVFE no con rand
	ivreghdfe hp_dif (L.l_actual_incent_rand = L.treat) if in_type==1 & L.inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) 
	eststo i_ivfe`g'_nc_r

	* IVFE all con rand
	xtset hh_id_num year_revised
	ivreghdfe hp_dif (L.l_actual_incent_rand = L.treat) L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
	eststo i_ivfe`g'_ac_r
}
*----------------------------------------
* IVFE Risk
*----------------------------------------
foreach g in 1 3 2{
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"
*-------Ordered--------------------------
	* IVFE no con
	ivreghdfe hp_dif (L.l_actual_incent = L.treat) if in_type==1 & L.inc_type_num==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) cluster(area)  
	eststo i_ivfe_risk`g'_nc

	* IVFE all con
	xtset hh_id_num year_revised
	ivreghdfe hp_dif (L.l_actual_incent = L.treat) L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_type_num==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo i_ivfe_risk`g'_ac

*-------Random--------------------------
	* IVFE no con rand
	ivreghdfe hp_dif (L.l_actual_incent_rand = L.treat) if in_type==1 & L.inc_type_num_rand ==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area)
	eststo i_ivfe_risk`g'_nc_r

	* IVFE all con rand
	xtset hh_id_num year_revised
	ivreghdfe hp_dif (L.l_actual_incent_rand = L.treat) L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_type_num_rand ==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
	eststo i_ivfe_risk`g'_ac_r
}

*-------------------------------------------
* Tabulate
*-------------------------------------------

* Individual Income Groups ----------------
* Full sample
esttab i_ivfe2_nc i_ivfe2_nc_r i_ivfe2_ac i_ivfe2_ac_r ///
       i_ivfe3_nc i_ivfe3_nc_r i_ivfe3_ac i_ivfe3_ac_r ///
       i_ivfe1_nc i_ivfe1_nc_r i_ivfe1_ac i_ivfe1_ac_r ///
    , ///
    rename(L.l_actual_incent_rand "log Incentive" ///
			L.l_actual_incent "log Incentive") ///
    keep("log Incentive") ///
    coeflabels(L.actual_incent "Log Incentive") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    mtitles("NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand") ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    title("Within-Group Incentive Effects (IVFE) — Full Sample") ///
    nonumbers scalars("N Observations") sfmt(%12.0fc)

* At-risk sample
esttab i_ivfe_risk2_nc i_ivfe_risk2_nc_r i_ivfe_risk2_ac i_ivfe_risk2_ac_r ///
       i_ivfe_risk3_nc i_ivfe_risk3_nc_r i_ivfe_risk3_ac i_ivfe_risk3_ac_r ///
       i_ivfe_risk1_nc i_ivfe_risk1_nc_r i_ivfe_risk1_ac i_ivfe_risk1_ac_r ///
    , ///
	rename(L.l_actual_incent_rand "log Incentive" ///
			L.l_actual_incent "log Incentive") ///
    keep("log Incentive") ///
    coeflabels(L.actual_incent "Log Incentive") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    mtitles("NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand") ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    nonumbers scalars("N Observations") sfmt(%12.0fc)
	
* =============================================================================
* =============================================================================
* =============================================================================	
* =============================================================================
* Changes in Energy Prices 
* =============================================================================


*------ Setup --------------------------------------------
foreach var in year_pair period_type D1 DeltaD absDD S D1_DD hp_dif_prior DeltaD_prior year_pair_lag {
	cap drop `var'
}
* Core first-difference variables
xtset hh_id_num year_revised
gen D1       = L_l_erate_alt             // baseline log price at t
gen DeltaD   = l_erate_alt - L_l_erate_alt    // Δ log price (treatment change)
gen absDD    = abs(DeltaD)			  // abs(∆D)
gen S        = sign(DeltaD)           // sgn(ΔD) 
gen D1_DD    = L_l_erate_alt * DeltaD            // interaction: slope heterogeneity by baseline

* Period-pair identifier (the "from" year labels the transition)
gen year_pair = L.year_revised

* Label period types for transparency
gen period_type = ""
replace period_type = "all_stay"     if inlist(year_pair, 2012, 2013, 2014, 2016, 2018, 2020, 2021)
replace period_type = "no_stay"      if inlist(year_pair, 2015, 2019)
replace period_type = "mixed_stay"   if inlist(year_pair, 2010, 2011, 2017)

sort hh_id_num year_revised
by hh_id_num: gen hp_dif_prior  = hp_dif[_n-1]
by hh_id_num: gen DeltaD_prior  = DeltaD[_n-1]
by hh_id_num: gen year_pair_lag = year_pair[_n-1]

tab year_pair in_ter1, summarize(erate_alt)   // sanity check: confirm ΔD structure

tab year_revised in_ter1, summarize(DeltaD)



*-------------------------------------------------------------------------------
* STEP 2: Parametric WAOSS estimator, by income group
*
* Model: E[ΔY | D1=d1, ΔD=δ, transition=τ] = α_τ + λ2*D1 + λ3*ΔD + λ4*(D1*ΔD)
*
*   α_τ         = year-pair FE: common outcome trend per transition
*                 (absorbs macro shocks, weather, etc.)
*   λ2*D1       = baseline-price-dependent trend: areas starting at
*                 higher prices may trend differently regardless of change
*   λ3*ΔD       = main adoption response to price change (the slope)
*   λ4*D1*ΔD    = slope varies with starting price level
*
* g_hat(D1, 0, τ) = α_τ + λ̂2*D1   ← counterfactual ΔY if ΔD had been zero
*
* θ̂ = Σ_i S_i[ΔY_i - g_hat(D1_i, 0, τ_i)] / Σ_i|ΔD_i|
*-------------------------------------------------------------------------------

cap restore

foreach val in "ac" "ac_r" "ac_f" "ac_fr" "nc" "nc_r" "nc_f" "nc_fr" {
    cap restore   

    * --- Determine variant flags ---
    local is_rand = (substr("`val'", -1, 1) == "r")
    local is_feas = (strpos("`val'", "f") > 0)
    local is_ac   = (substr("`val'", 1, 2) == "ac")

    * --- Set inc_var, controls_a (variables to L. before bsample),
    *     controls_b (bootstrap-safe regressor list) ---
    if `is_ac' & `is_rand' {
        local inc_var    "inc_type_num_rand"
        local controls_a "new_build renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age actual_incent_rand"
        local controls_b "i.ctrl_new_build i.ctrl_renter_occupied_random ctrl_l_home_value ctrl_l_square_feet ctrl_l_stories ctrl_l_income_rand ctrl_l_bldg_age i.ctrl_actual_incent_rand renovation"
    }
    else if `is_ac' & !`is_rand' {
        local inc_var    "inc_type_num"
        local controls_a "new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age actual_incent"
        local controls_b "i.ctrl_new_build i.ctrl_renteroccupied ctrl_l_home_value ctrl_l_square_feet ctrl_l_stories ctrl_l_income ctrl_l_bldg_age i.ctrl_actual_incent renovation"
    }
    else if !`is_ac' & `is_rand' {
        local inc_var    "inc_type_num_rand"
        local controls_a ""
        local controls_b ""
    }
    else {
        local inc_var    "inc_type_num"
        local controls_a ""
        local controls_b ""
    }

    * --- Initialize results matrix ---
    matrix WAOSS_results_`val' = J(3, 7, .)
    matrix rownames WAOSS_results_`val' = "high" "low" "mid"
    matrix colnames WAOSS_results_`val' = "theta" "boot_se" "ci_l" "ci_h" "N" "N_switch" "N_stay"

    local B = 500

    foreach g in 2 3 1 {
        local glabel = cond(`g'==1, "high", cond(`g'==2, "low", "mid"))

        preserve
        qui keep if `inc_var' == `g' & in_type == 1
        if `is_feas' qui keep if at_risk == 1

        qui count if DeltaD != 0
        local N_switch = r(N)
        qui count if DeltaD == 0
        local N_stay   = r(N)
        local N_total  = _N

        di _newline "=== [`val'] `glabel' (g=`g') ==="
        di "  Switchers: `N_switch'  Stayers: `N_stay'  Total: `N_total'"

        if `N_total' < 50 {
            di "  Insufficient obs — skipping"
            restore
            continue
        }

        * Pre-compute lagged controls as ctrl_ variables.
        foreach v in `controls_a' {
            cap drop ctrl_`v'
            qui gen ctrl_`v' = L.`v'
        }

        *--- Step 2a: estimate λ₀ (parametric g) ---
        qui cap reghdfe hp_dif D1 DeltaD D1_DD `controls_b', ///
            absorb(year_pair hh_id_num L_htc_num) vce(cluster area)
        if _rc != 0 {
            di "  Step 2a failed for [`val'] `glabel' — skipping"
            restore
            continue
        }

        local b_DD  = _b[DeltaD]
        local b_int = _b[D1_DD]
        cap drop yhat_full g_hat_zero
        qui predict yhat_full, xb
        * g_hat_zero = g(D1, 0): fitted value with ΔD set to zero
        qui gen g_hat_zero = yhat_full - `b_DD'*DeltaD - `b_int'*D1_DD

        *--- Step 2b: WAOSS θ̂ ---
        cap drop S_resid
        qui gen S_resid = S * (hp_dif - g_hat_zero)
        qui sum S_resid
        local numerator = r(mean)
        qui sum absDD
        local theta_g = `numerator' / r(mean)
        di "  θ̂ = " %9.6f `theta_g'

        *--- Save group data to tempfile (avoids nested preserve in bootstrap) ---
        tempfile data_g
        qui save `data_g'

        *--- Step 2c: Bootstrap SE ---
        * failure kills the forval entirely, leaving btheta all missing → SE = .
        tempname btheta
        matrix `btheta' = J(`B', 1, .)

        forval b = 1/`B' {
            qui use `data_g', clear
            cap drop new_hh_id_num
            qui bsample, cluster(hh_id_num) idcluster(new_hh_id_num)

            if mod(`b', 100) == 0 di "  bootstrap: `b' / `B'"

            cap qui reghdfe hp_dif D1 DeltaD D1_DD `controls_b', ///
                absorb(year_pair new_hh_id_num L_htc_num)
            if _rc != 0 continue   // skip failed draws; don't abort forval

            cap drop yhat_b g0_b sr_b
            qui predict yhat_b, xb
            qui gen g0_b = yhat_b - _b[DeltaD]*DeltaD - _b[D1_DD]*D1_DD
            qui gen sr_b = S * (hp_dif - g0_b)
            qui sum sr_b
            local num_b = r(mean)
            qui sum absDD
            if r(mean) != 0 matrix `btheta'[`b', 1] = `num_b' / r(mean)
        }

        * Reload clean data and extract bootstrap SD
        qui use `data_g', clear
        cap drop _btheta1
        qui svmat `btheta', name(_btheta)
        qui sum _btheta1
        local boot_se = r(sd)
        qui drop _btheta1

        local ci_l = `theta_g' - 1.96*`boot_se'
        local ci_h = `theta_g' + 1.96*`boot_se'
        di "  SE = " %9.6f `boot_se' "  95% CI: [" %9.6f `ci_l' ", " %9.6f `ci_h' "]"

        matrix WAOSS_results_`val'[`g', 1] = `theta_g'
        matrix WAOSS_results_`val'[`g', 2] = `boot_se'
        matrix WAOSS_results_`val'[`g', 3] = `ci_l'
        matrix WAOSS_results_`val'[`g', 4] = `ci_h'
        matrix WAOSS_results_`val'[`g', 5] = `N_total'
        matrix WAOSS_results_`val'[`g', 6] = `N_switch'
        matrix WAOSS_results_`val'[`g', 7] = `N_stay'

        restore
    }
}

foreach val in "ac" "ac_r" "nc" "nc_r" "ac_f" "ac_fr" "nc_f" "nc_fr" {
    di _newline "=== WAOSS_results_`val' ==="
    matrix list WAOSS_results_`val', format(%9.6f)
}

	
*=========================================================
* Energy - Subsidy Effect Comparisons
*=========================================================

foreach var in eui_l eui_h lowkwh highkwh lownewkwh highnewkwh lowsave highsave ll_dif lh_dif hl_dif hh_dif ll_dif_part lh_dif_part hl_dif_part hh_dif_part {
    cap drop `var'
}

* low and high EUI estimated as 25th and 75th percentile of single-family homes in WA state in 2020 RECS 
* single family = category 2 and 3. Total heating BTU multiplied by 0.293071 before entry for kBTU -> kWh 
* total heated square feet divided by toal heating kWh dropping any that are 0 or NA
* efficiency for heat pump based on minimum SEER2 for Energy Star 

scalar eui_l = 0.11924140716520854 
scalar eui_h = 0.2621352388785604

gen lowkwh = live_square_feet * `=eui_l' 
gen highkwh = live_square_feet * `=eui_h'
gen lownewkwh = lowkwh / 3.897 // Heat Pump assumed efficiency COP
gen highnewkwh = highkwh / 3.897 // Heat Pump assumed efficiency COP
gen lowsave = lowkwh - lownewkwh
gen highsave = highkwh - highnewkwh

summarize lowkwh 
summarize highkwh
summarize lownewkwh
summarize highnewkwh
summarize lowsave
summarize highsave

local ldscnt = (1-(1+0.02)^(-15))/0.02 // fed value
local hdscnt = (1-(1+0.11)^(-15))/0.11 // research on EE value 

* estimate a `1% change' in contemporaneous energy prices

gen ll_dif = lowsave * `ldscnt' * erate_alt
gen lh_dif = lowsave * `hdscnt' * erate_alt // lower bound
gen hl_dif = highsave * `ldscnt' * erate_alt // upper bound
gen hh_dif = highsave * `hdscnt' * erate_alt
gen ll_dif_part = lowsave * `ldscnt' 
gen lh_dif_part = lowsave * `hdscnt' 
gen hl_dif_part = highsave * `ldscnt'
gen hh_dif_part = highsave * `hdscnt'

* extract average incentives: 
summarize actual_incent if low_inc_qual  == 1 & in_type == 1
scalar mean_incent_l = r(mean)
summarize actual_incent if mid_inc_qual  == 1 & in_type == 1
scalar mean_incent_m = r(mean)
summarize actual_incent if high_inc_qual == 1 & in_type == 1
scalar mean_incent_h = r(mean)
summarize actual_incent if low_inc_qual_rand  == 1 & in_type == 1
scalar mean_incent_lr = r(mean)
summarize actual_incent if mid_inc_qual_rand  == 1 & in_type == 1
scalar mean_incent_mr = r(mean)
summarize actual_incent if high_inc_qual_rand == 1 & in_type == 1
scalar mean_incent_hr = r(mean)

* extract average NPVs by group 
foreach val in ll lh hl hh { 
	summarize `val'_dif if low_inc_qual  == 1 & in_type == 1
	scalar mean_npv_`val'_l = r(mean)
	summarize `val'_dif if mid_inc_qual  == 1 & in_type == 1
	scalar mean_npv_`val'_m = r(mean)
	summarize `val'_dif if high_inc_qual == 1 & in_type == 1
	scalar mean_npv_`val'_h = r(mean)
	summarize `val'_dif if low_inc_qual_rand == 1 & in_type == 1
	scalar mean_npv_`val'_lr = r(mean)
	summarize `val'_dif if mid_inc_qual_rand  == 1 & in_type == 1
	scalar mean_npv_`val'_mr = r(mean)
	summarize `val'_dif if high_inc_qual_rand == 1 & in_type == 1
	scalar mean_npv_`val'_hr = r(mean)
	summarize `val'_dif_part if low_inc_qual  == 1 & in_type == 1
	scalar mean_npv_part_`val'_l = r(mean)
	summarize `val'_dif_part if mid_inc_qual  == 1 & in_type == 1
	scalar mean_npv_part_`val'_m = r(mean)
	summarize `val'_dif_part if high_inc_qual == 1 & in_type == 1
	scalar mean_npv_part_`val'_h = r(mean)
	summarize `val'_dif_part if low_inc_qual_rand == 1 & in_type == 1
	scalar mean_npv_`part_val'_lr = r(mean)
	summarize `val'_dif_part if mid_inc_qual_rand  == 1 & in_type == 1
	scalar mean_npv_`part_val'_mr = r(mean)
	summarize `val'_dif_part if high_inc_qual_rand == 1 & in_type == 1
	scalar mean_npv_part_`val'_hr = r(mean)
}

* Restore Coefficients 
* --- ac_f (ordered, feasible) ---
scalar lb    = 1.0586 // WAOSS_results_ac_f[2, 1]   
scalar se_lb = 0.2271 // WAOSS_results_ac_f[2, 2]   
scalar mb    = 1.1565 // WAOSS_results_ac_f[3, 1]   
scalar se_mb = 0.4425 // WAOSS_results_ac_f[3, 2]   
scalar hb    = -0.1442 // WAOSS_results_ac_f[1, 1]   
scalar se_hb = 0.0172 // WAOSS_results_ac_f[1, 2]   

* --- ac_fr (random, feasible) ---
scalar lbr    = 0.6787 // WAOSS_results_ac_fr[2, 1]
scalar se_lbr = 0.3019 // WAOSS_results_ac_fr[2, 2]
scalar mbr    = 0.5561 // WAOSS_results_ac_fr[3, 1]
scalar se_mbr = 0.3093 // WAOSS_results_ac_fr[3, 2]
scalar hbr    = -0.1415 // WAOSS_results_ac_fr[1, 1]
scalar se_hbr = 0.0187 // WAOSS_results_ac_fr[1, 2]

estimates restore i_ivfe_risk2_ac
scalar bi_l = _b[L.l_actual_incent]
scalar sei_l = _se[L.l_actual_incent]
estimates restore i_ivfe_risk3_ac
scalar bi_m = _b[L.l_actual_incent]
scalar sei_m = _se[L.l_actual_incent]
estimates restore i_ivfe_risk1_ac
scalar bi_h = _b[L.l_actual_incent]
scalar sei_h = _se[L.l_actual_incent]

estimates restore i_ivfe_risk2_ac_r
scalar bi_lr = _b[L.l_actual_incent_rand]
scalar sei_lr = _se[L.l_actual_incent_rand]
estimates restore i_ivfe_risk3_ac_r
scalar bi_mr = _b[L.l_actual_incent_rand]
scalar sei_mr = _se[L.l_actual_incent_rand]
estimates restore i_ivfe_risk1_ac_r
scalar bi_hr = _b[L.l_actual_incent_rand]
scalar sei_hr = _se[L.l_actual_incent_rand]

* Estimate equivalent change in incentive to equal change in NPV --------------
scalar ipernpv_ll_l = (mean_incent_l * lb)/(mean_npv_ll_l * bi_l)
scalar ipernpv_ll_m = (mean_incent_m * mb)/(mean_npv_ll_m * bi_m)
scalar ipernpv_ll_h = (mean_incent_h * hb)/(mean_npv_ll_h * bi_h)
scalar ipernpv_ll_lr = (mean_incent_lr * lbr)/(mean_npv_ll_lr * bi_lr)
scalar ipernpv_ll_mr = (mean_incent_mr * mbr)/(mean_npv_ll_mr * bi_mr)
scalar ipernpv_ll_hr = (mean_incent_hr * hbr)/(mean_npv_ll_hr * bi_hr)

scalar ipernpv_lh_l = (mean_incent_l * lb)/(mean_npv_lh_l * bi_l)
scalar ipernpv_lh_m = (mean_incent_m * mb)/(mean_npv_lh_m * bi_m)
scalar ipernpv_lh_h = (mean_incent_h * hb)/(mean_npv_lh_h * bi_h)
scalar ipernpv_lh_lr = (mean_incent_lr * lbr)/(mean_npv_lh_lr * bi_lr)
scalar ipernpv_lh_mr = (mean_incent_mr * mbr)/(mean_npv_lh_mr * bi_mr)
scalar ipernpv_lh_hr = (mean_incent_hr * hbr)/(mean_npv_lh_hr * bi_hr)

scalar ipernpv_hl_l = (mean_incent_l * lb)/(mean_npv_hl_l * bi_l)
scalar ipernpv_hl_m = (mean_incent_m * mb)/(mean_npv_hl_m * bi_m)
scalar ipernpv_hl_h = (mean_incent_h * hb)/(mean_npv_hl_h * bi_h)
scalar ipernpv_hl_lr = (mean_incent_lr * lbr)/(mean_npv_hl_lr * bi_lr)
scalar ipernpv_hl_mr = (mean_incent_mr * mbr)/(mean_npv_hl_mr * bi_mr)
scalar ipernpv_hl_hr = (mean_incent_hr * hbr)/(mean_npv_hl_hr * bi_hr)

scalar ipernpv_hh_l = (mean_incent_l * lb)/(mean_npv_hh_l * bi_l)
scalar ipernpv_hh_m = (mean_incent_m * mb)/(mean_npv_hh_m * bi_m)
scalar ipernpv_hh_h = (mean_incent_h * hb)/(mean_npv_hh_h * bi_h)
scalar ipernpv_hh_lr = (mean_incent_lr * lbr)/(mean_npv_hh_lr * bi_lr)
scalar ipernpv_hh_mr = (mean_incent_mr * mbr)/(mean_npv_hh_mr * bi_mr)
scalar ipernpv_hh_hr = (mean_incent_hr * hbr)/(mean_npv_hh_hr * bi_hr)

matrix ipernpv = J(4, 6, .)
matrix rownames ipernpv = "Low-Low" "Low-High" "High-Low" "High-High"
matrix colnames ipernpv = "Low_Ord" "Low_Rand" "Mid_Ord" "Mid_Rand" "High_Ord" "High_Rand"

matrix ipernpv[1,1] = ipernpv_ll_l
matrix ipernpv[1,2] = ipernpv_ll_lr
matrix ipernpv[1,3] = ipernpv_ll_m
matrix ipernpv[1,4] = ipernpv_ll_mr
matrix ipernpv[1,5] = ipernpv_ll_h
matrix ipernpv[1,6] = ipernpv_ll_hr

matrix ipernpv[2,1] = ipernpv_lh_l
matrix ipernpv[2,2] = ipernpv_lh_lr
matrix ipernpv[2,3] = ipernpv_lh_m
matrix ipernpv[2,4] = ipernpv_lh_mr
matrix ipernpv[2,5] = ipernpv_lh_h
matrix ipernpv[2,6] = ipernpv_lh_hr

matrix ipernpv[3,1] = ipernpv_hl_l
matrix ipernpv[3,2] = ipernpv_hl_lr
matrix ipernpv[3,3] = ipernpv_hl_m
matrix ipernpv[3,4] = ipernpv_hl_mr
matrix ipernpv[3,5] = ipernpv_hl_h
matrix ipernpv[3,6] = ipernpv_hl_hr

matrix ipernpv[4,1] = ipernpv_hh_l
matrix ipernpv[4,2] = ipernpv_hh_lr
matrix ipernpv[4,3] = ipernpv_hh_m
matrix ipernpv[4,4] = ipernpv_hh_mr
matrix ipernpv[4,5] = ipernpv_hh_h
matrix ipernpv[4,6] = ipernpv_hh_hr

* ---- Delta method SEs ------------------------------------------------------
* Low-Low row
scalar se_ipernpv_ll_l  = abs(ipernpv_ll_l)  * sqrt((se_lb/lb)^2   + (sei_l/bi_l)^2)
scalar se_ipernpv_ll_m  = abs(ipernpv_ll_m)  * sqrt((se_mb/mb)^2   + (sei_m/bi_m)^2)
scalar se_ipernpv_ll_h  = abs(ipernpv_ll_h)  * sqrt((se_hb/hb)^2   + (sei_h/bi_h)^2)
scalar se_ipernpv_ll_lr = abs(ipernpv_ll_lr) * sqrt((se_lbr/lbr)^2 + (sei_lr/bi_lr)^2)
scalar se_ipernpv_ll_mr = abs(ipernpv_ll_mr) * sqrt((se_mbr/mbr)^2 + (sei_mr/bi_mr)^2)
scalar se_ipernpv_ll_hr = abs(ipernpv_ll_hr) * sqrt((se_hbr/hbr)^2 + (sei_hr/bi_hr)^2)

* Low-High row
scalar se_ipernpv_lh_l  = abs(ipernpv_lh_l)  * sqrt((se_lb/lb)^2   + (sei_l/bi_l)^2)
scalar se_ipernpv_lh_m  = abs(ipernpv_lh_m)  * sqrt((se_mb/mb)^2   + (sei_m/bi_m)^2)
scalar se_ipernpv_lh_h  = abs(ipernpv_lh_h)  * sqrt((se_hb/hb)^2   + (sei_h/bi_h)^2)
scalar se_ipernpv_lh_lr = abs(ipernpv_lh_lr) * sqrt((se_lbr/lbr)^2 + (sei_lr/bi_lr)^2)
scalar se_ipernpv_lh_mr = abs(ipernpv_lh_mr) * sqrt((se_mbr/mbr)^2 + (sei_mr/bi_mr)^2)
scalar se_ipernpv_lh_hr = abs(ipernpv_lh_hr) * sqrt((se_hbr/hbr)^2 + (sei_hr/bi_hr)^2)

* High-Low row
scalar se_ipernpv_hl_l  = abs(ipernpv_hl_l)  * sqrt((se_lb/lb)^2   + (sei_l/bi_l)^2)
scalar se_ipernpv_hl_m  = abs(ipernpv_hl_m)  * sqrt((se_mb/mb)^2   + (sei_m/bi_m)^2)
scalar se_ipernpv_hl_h  = abs(ipernpv_hl_h)  * sqrt((se_hb/hb)^2   + (sei_h/bi_h)^2)
scalar se_ipernpv_hl_lr = abs(ipernpv_hl_lr) * sqrt((se_lbr/lbr)^2 + (sei_lr/bi_lr)^2)
scalar se_ipernpv_hl_mr = abs(ipernpv_hl_mr) * sqrt((se_mbr/mbr)^2 + (sei_mr/bi_mr)^2)
scalar se_ipernpv_hl_hr = abs(ipernpv_hl_hr) * sqrt((se_hbr/hbr)^2 + (sei_hr/bi_hr)^2)

* High-High row
scalar se_ipernpv_hh_l  = abs(ipernpv_hh_l)  * sqrt((se_lb/lb)^2   + (sei_l/bi_l)^2)
scalar se_ipernpv_hh_m  = abs(ipernpv_hh_m)  * sqrt((se_mb/mb)^2   + (sei_m/bi_m)^2)
scalar se_ipernpv_hh_h  = abs(ipernpv_hh_h)  * sqrt((se_hb/hb)^2   + (sei_h/bi_h)^2)
scalar se_ipernpv_hh_lr = abs(ipernpv_hh_lr) * sqrt((se_lbr/lbr)^2 + (sei_lr/bi_lr)^2)
scalar se_ipernpv_hh_mr = abs(ipernpv_hh_mr) * sqrt((se_mbr/mbr)^2 + (sei_mr/bi_mr)^2)
scalar se_ipernpv_hh_hr = abs(ipernpv_hh_hr) * sqrt((se_hbr/hbr)^2 + (sei_hr/bi_hr)^2)

* ---- Matrix ----------------------------------------------------------------
matrix ipernpv_se = J(4, 6, .)
matrix rownames ipernpv_se = "Low-Low" "Low-High" "High-Low" "High-High"
matrix colnames ipernpv_se = "Low_Ord" "Low_Rand" "Mid_Ord" "Mid_Rand" "High_Ord" "High_Rand"

matrix ipernpv_se[1,1] = se_ipernpv_ll_l
matrix ipernpv_se[1,2] = se_ipernpv_ll_lr
matrix ipernpv_se[1,3] = se_ipernpv_ll_m
matrix ipernpv_se[1,4] = se_ipernpv_ll_mr
matrix ipernpv_se[1,5] = se_ipernpv_ll_h
matrix ipernpv_se[1,6] = se_ipernpv_ll_hr

matrix ipernpv_se[2,1] = se_ipernpv_lh_l
matrix ipernpv_se[2,2] = se_ipernpv_lh_lr
matrix ipernpv_se[2,3] = se_ipernpv_lh_m
matrix ipernpv_se[2,4] = se_ipernpv_lh_mr
matrix ipernpv_se[2,5] = se_ipernpv_lh_h
matrix ipernpv_se[2,6] = se_ipernpv_lh_hr

matrix ipernpv_se[3,1] = se_ipernpv_hl_l
matrix ipernpv_se[3,2] = se_ipernpv_hl_lr
matrix ipernpv_se[3,3] = se_ipernpv_hl_m
matrix ipernpv_se[3,4] = se_ipernpv_hl_mr
matrix ipernpv_se[3,5] = se_ipernpv_hl_h
matrix ipernpv_se[3,6] = se_ipernpv_hl_hr

matrix ipernpv_se[4,1] = se_ipernpv_hh_l
matrix ipernpv_se[4,2] = se_ipernpv_hh_lr
matrix ipernpv_se[4,3] = se_ipernpv_hh_m
matrix ipernpv_se[4,4] = se_ipernpv_hh_mr
matrix ipernpv_se[4,5] = se_ipernpv_hh_h
matrix ipernpv_se[4,6] = se_ipernpv_hh_hr

*----- P-values --------------------------------------------------------------
matrix ipernpv_t = J(4, 6, .)
matrix ipernpv_p = J(4, 6, .)
forvalues r = 1/4 {
    forvalues c = 1/6 {
        matrix ipernpv_t[`r',`c'] = ipernpv[`r',`c'] / ipernpv_se[`r',`c']
        matrix ipernpv_p[`r',`c'] = 2 * (1 - normal(abs(ipernpv_t[`r',`c'])))
    }
}

* note given the high number of observations, no need to leverage tiny DF 

* ---- Equivalence to $1.00 NPV in energy ------------------------------------
foreach val in ll lh hl hh { 
	summarize `val'_dif_part if low_inc_qual  == 1 & in_type == 1
	scalar ppnpv_`val'_l = 1/r(mean)
	summarize `val'_dif_part if mid_inc_qual  == 1 & in_type == 1
	scalar ppnpv_`val'_m = 1/r(mean)
	summarize `val'_dif_part if high_inc_qual == 1 & in_type == 1
	scalar ppnpv_`val'_h = 1/r(mean)
	summarize `val'_dif_part if low_inc_qual_rand == 1 & in_type == 1
	scalar ppnpv_`val'_lr = 1/r(mean)
	summarize `val'_dif_part if mid_inc_qual_rand  == 1 & in_type == 1
	scalar ppnpv_`val'_mr = 1/r(mean)
	summarize `val'_dif_part if high_inc_qual_rand == 1 & in_type == 1
	scalar ppnpv_`val'_hr = 1/r(mean)
}

matrix ppnpv = J(4, 6, .)
matrix rownames ppnpv = "Low-Low" "Low-High" "High-Low" "High-High"
matrix colnames ppnpv = "Low_Ord" "Low_Rand" "Mid_Ord" "Mid_Rand" "High_Ord" "High_Rand"

matrix ppnpv[1,1] = ppnpv_ll_l
matrix ppnpv[1,2] = ppnpv_ll_lr
matrix ppnpv[1,3] = ppnpv_ll_m
matrix ppnpv[1,4] = ppnpv_ll_mr
matrix ppnpv[1,5] = ppnpv_ll_h
matrix ppnpv[1,6] = ppnpv_ll_hr

matrix ppnpv[2,1] = ppnpv_lh_l
matrix ppnpv[2,2] = ppnpv_lh_lr
matrix ppnpv[2,3] = ppnpv_lh_m
matrix ppnpv[2,4] = ppnpv_lh_mr
matrix ppnpv[2,5] = ppnpv_lh_h
matrix ppnpv[2,6] = ppnpv_lh_hr

matrix ppnpv[3,1] = ppnpv_hl_l
matrix ppnpv[3,2] = ppnpv_hl_lr
matrix ppnpv[3,3] = ppnpv_hl_m
matrix ppnpv[3,4] = ppnpv_hl_mr
matrix ppnpv[3,5] = ppnpv_hl_h
matrix ppnpv[3,6] = ppnpv_hl_hr

matrix ppnpv[4,1] = ppnpv_hh_l
matrix ppnpv[4,2] = ppnpv_hh_lr
matrix ppnpv[4,3] = ppnpv_hh_m
matrix ppnpv[4,4] = ppnpv_hh_mr
matrix ppnpv[4,5] = ppnpv_hh_h
matrix ppnpv[4,6] = ppnpv_hh_hr

matrix list ipernpv,    format(%9.2f) // estimated equivalent change in subsidies needed given energy price effects 
matrix list ipernpv_se, format(%9.2f) // SEs for the above
matrix list ipernpv_p, format(%9.4f) // p-values for the above

matrix list ppnpv, format(%9.6f) // change in energy price per kWh needed to achieve $1 NPV lifetime energy savings


* =============================================================================
* Novelty and Awareness Effect
* =============================================================================

*------------------------------------------------------------------------
* STEP 1: Regressions
*------------------------------------------------------------------------
foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"

    xtset hh_id_num year_revised
	
* ---- Controls -----------------------------------------------
	local controls "L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation"
	local controls_rand "L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation"
		  
    * Full sample ordered
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 `controls' ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_ac

    * Full sample random
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 `controls_rand' ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_ac_r

    * At risk ordered
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 `controls' ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_risk_ac
	

    * At risk random
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 `controls_rand' ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_risk_ac_r
	
* ---- No Controls -----------------------------------------------
	    * Full sample ordered
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_nc

    * Full sample random
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_nc_r

    * At risk ordered
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_risk_nc

    * At risk random
    reghdfe hp_dif ib2015.year_revised##i.in_ter1 ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo es_g`g'_risk_nc_r
}

*------------------------------------------------------------------------
* STEP 2: Extract coefficients
*------------------------------------------------------------------------
cap postclose handl_es
tempfile es_decay
postfile handl_es year group sample rand coef se lb ub using `es_decay', replace

local years "2011 2012 2013 2015 2016 2017 2018 2019 2020 2021"

foreach g in 1 2 3 {
    foreach samp in ac risk_ac {
        local sampnum = cond("`samp'"=="ac", 1, 2)

        * Ordered
        cap estimates restore es_g`g'_`samp'
        if _rc == 0 {
            foreach y of local years {
                cap {
                    lincom `y'.year_revised#1.in_ter1
                    post handl_es (`y') (`g') (`sampnum') (0) ///
                        (r(estimate)) (r(se)) (r(lb)) (r(ub))
                }
            }
            post handl_es (2015) (`g') (`sampnum') (0) (0) (0) (0) (0)
        }
        else {
            di "Skipping ordered g=`g' samp=`samp'"
        }

        * Random
        cap estimates restore es_g`g'_`samp'_r
        if _rc == 0 {
            foreach y of local years {
                cap {
                    lincom `y'.year_revised#1.in_ter1
                    post handl_es (`y') (`g') (`sampnum') (1) ///
                        (r(estimate)) (r(se)) (r(lb)) (r(ub))
                }
            }
            post handl_es (2015) (`g') (`sampnum') (1) (0) (0) (0) (0)
        }
        else {
            di "Skipping random g=`g' samp=`samp'"
        }
    }
}

postclose handl_es

* ---- Merge ordered and random into combined estimates ---------------------
preserve
use `es_decay', clear

drop if coef==0 & se==0 & lb==0 & ub==0 & year!=2015

* Compute combined estimate per year/group/sample
bysort year group sample: egen coef_avg = mean(coef)
bysort year group sample: egen ub_max   = max(ub)
bysort year group sample: egen lb_min   = min(lb)

* Combined SE: sqrt(mean of variances) — conservative
gen var = se^2
bysort year group sample: egen var_avg = mean(var)
gen se_combined = sqrt(var_avg)

* Keep one row per year/group/sample
bysort year group sample (rand): keep if _n == 1
drop coef se lb ub rand var var_avg

rename coef_avg coef
rename se_combined se
rename ub_max ub
rename lb_min lb

sort group sample year

*------------------------------------------------------------------------
* STEP 3: Plot
*------------------------------------------------------------------------
twoway ///
    (rarea lb ub year if group==2 & sample==1, fcolor(blue%20)  lcolor(blue%20)) ///
    (rarea lb ub year if group==3 & sample==1, fcolor(red%20)   lcolor(red%20)) ///
	(rarea lb ub year if group==1 & sample==1, fcolor(green%20)  lcolor(green%20)) ///
    (line coef year if group==2 & sample==1, lcolor(blue)  lwidth(medthick)) ///
    (line coef year if group==3 & sample==1, lcolor(red)   lwidth(medthick)) ///
    (line coef year if group==1 & sample==1, lcolor(green)  lwidth(medthick)) ///
    , ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xline(2015, lpattern(solid) lcolor(black)) ///
    xlabel(2011(1)2021, angle(45) labsize(small)) ///
    yscale(range(-0.05 0.1)) ///
    ylabel(-0.05(0.02)0.1) ///
    legend(order(4 "Low Income" 5 "Mid Income" 6 "High Income") pos(11) ring(0)) ///
    ytitle("Effect on Adoption (pp)") xtitle("Year") ///
    scheme(s2color) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(es_full, replace)
graph export "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Figures/age.png", replace
restore

*------------------------------------------------------------------------
* STEP 4: Pre-Trend Estimates
*------------------------------------------------------------------------
qui estimates dir es_g*
local mods `r(names)'
foreach mod of local mods {
    estimates restore `mod'
    testparm 2011.year_revised#1.in_ter1 ///
              2012.year_revised#1.in_ter1 ///
              2013.year_revised#1.in_ter1
    estadd scalar pretrend = r(p)
}

qui estimates dir es_g*
local mods `r(names)'
esttab es_g*, ///
    keep("") ///
	mlabels(`r(names)') ///
    stats(pretrend, fmt(%9.3f) labels("Pre-trend p-value"))


* =============================================================================
* Threshold - could you increase adoption with other incentive cutoffs
* =============================================================================

*---------prep-------------------------------	
xtset hh_id_num year_revised
cap drop pov_ratio
cap drop pov_ratio_rand
cap drop pov_bucket
cap drop pov_bucket_rand
cap drop L_pov_bin
cap drop L_pov_bin_rand
cap drop Llai
cap drop pov_dec*
cap drop Llai*
cap drop Ltreat*
cap drop hp_avg_change
cap drop hp_avg_change_rand
cap drop elast
cap drop elast_rand
cap drop inc_pct
cap drop inc_pct_rand
cap drop L_inc_pct
cap drop L_inc_pct
cap drop Lpovbucket
cap drop Lpovbucket_rand
cap drop Lincome
cap drop Lincome_rand

gen inc_pct = .
gen inc_pct_rand = .
levelsof year_revised, local(years)
foreach y of local years {
    xtile temp = income/pov_limit if year_revised==`y' & in_type==1 & income/pov_limit <= 4.0, nq(40)
    replace inc_pct = temp if year_revised==`y' & in_type==1 & income/pov_limit <= 4.0
    xtile tempr = income_rand/pov_limit_rand if year_revised==`y' & in_type==1 & income_rand/pov_limit_rand <= 4.0, nq(40)
    replace inc_pct_rand = tempr if year_revised==`y' & in_type==1 & income_rand/pov_limit_rand <= 4.0
    drop temp
	drop tempr
}

xtset hh_id_num year_revised
bys hh_id_num (year_revised): gen Lpovbucket = L.inc_pct
bys hh_id_num (year_revised): gen Lpovbucket_rand = L.inc_pct_rand
bys hh_id_num (year_revised): gen Lincome = L.income
bys hh_id_num (year_revised): gen Lincome_rand = L.income_rand

bys hh_id_num (year_revised): gen L_inc_pct = L.inc_pct	
bys hh_id_num (year_revised): gen L_inc_pct_rand = L.inc_pct_rand
bys hh_id_num (year_revised): gen Llai = L.l_actual_incent
bys hh_id_num (year_revised): gen Llai_r = L.l_actual_incent_rand
bys hh_id_num (year_revised): gen Llai_c = ln(L.high_inc_incent)
replace Llai_c = Llai if in_ter1==0
bys hh_id_num (year_revised): gen Llai_cr = ln(L.high_inc_incent)
replace Llai_cr = Llai_r if in_ter1==0
bys hh_id_num (year_revised): gen Ltreat = L.treat

summarize Lpovbucket

*------------------------------------------------------------*
*   Heterogeneous IV effect of L.lai over continuous income  *
*   Fully instrumented interaction + smoothed margins plot   *
*------------------------------------------------------------*

* 1. Estimate IV with interaction 
xtset hh_id_num year_revised
ivreghdfe hp_dif ///
    (c.Llai c.Llai#ib20.Lpovbucket = Ltreat Ltreat#ib20.Lpovbucket) ///
    L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_pct<=20, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo pov_bkt_mod

xtset hh_id_num year_revised
ivreghdfe hp_dif ///
    (c.Llai_r c.Llai_r#ib20.Lpovbucket_rand = Ltreat Ltreat#ib20.Lpovbucket_rand) ///
    L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_pct_rand<=20, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo pov_bkt_mod_rand

* 2. INdividual Income Comparsions 	
forvalues b = 1/20 {
	xtset hh_id_num year_revised
ivreghdfe hp_dif ///
    (c.Llai = Ltreat) ///
    L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_pct==`b', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo pov_bkt_mod_`b'

xtset hh_id_num year_revised
ivreghdfe hp_dif ///
    (c.Llai_r = Ltreat) ///
    L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & L.inc_pct_rand==`b', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo pov_bkt_mod_rand_`b'
}
	
* 2. Get coefficients
matrix results = J(20, 10, .)
local row = 1
* Loop over buckets 1–40
forvalues b = 1/20 {
	est restore pov_bkt_mod_`b'
    lincom c.Llai 
	local lb = r(lb)
	local ub = r(ub)
    matrix results[`row', 1] = `b'
    matrix results[`row', 2] = r(estimate)
	matrix results[`row', 3] = r(lb)
	matrix results[`row', 4] = r(ub)
	est restore pov_bkt_mod_rand_`b'
    lincom c.Llai_r
	local lbr = r(lb)
	local ubr = r(ub)
	local l = min(`lbr',`lb')
	local u = max(`ubr',`ub')
    matrix results[`row', 5] = `l'
    matrix results[`row', 6] = `u'
	matrix results[`row', 7] =  r(estimate)
	matrix results[`row', 8] =  r(lb)
	matrix results[`row', 9] =  r(ub)
	local avg = (r(estimate) + results[`row', 2]) / 2
	matrix results[`row', 10] = `avg'
    local ++row
}

preserve
clear
svmat results, names(col)
rename c1 bucket
rename c2 coef
rename c3 ci_low
rename c4 ci_high
rename c5 ci_alllow
rename c6 ci_allhigh
rename c7 coef_rand
rename c8 ci_low_r
rename c9 ci_high_r
rename c10 coef_avg
sort bucket
cap drop pct
gen pct = bucket *10

twoway ///
    (bar coef_rand pct, barwidth(7) color(green%40)) ///
    (bar coef pct, barwidth(7) color(orange%40)) ///
    (rcap ci_high ci_low pct, lcolor(orange)) ///
    (rcap ci_high_r ci_low_r pct, lcolor(green)) ///
    (lpoly coef pct, degree(1) bwidth(40) lcolor(orange) lwidth(medthick) kernel(triangle)) ///
    (lpoly coef_rand pct, degree(1) bwidth(40) lcolor(green) lwidth(medthick) kernel(triangle)), ///
    ytitle("Marginal Effect of Log Incentive") ///
    xtitle("Percent Poverty") ///
    xlabel(10(10)200, labsize(vsmall) format(%2.0f) angle(45)) ///
    legend(order(5 "Ordered" 6 "Randomized") pos(6) row(1) region(lstyle(none))) ///
    xline(10(20)200, lcolor(gs12) lpattern(solid) lwidth(0.1)) ///
    graphregion(color(white)) plotregion(color(white))
	
graph export "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Figures/threshold_indv.png", replace width(2000)	

foreach v in coef coef_rand {
    forvalues b = 1/20 {
        local pct_b = `b' * 10
        quietly reg `v' pct if abs(pct - `pct_b') <= 20
        di "bucket `b': slope=" _b[pct] " p=" (2*ttail(e(df_r), abs(_b[pct]/_se[pct]))) " R2=" e(r2)
    }
}

restore


* =============================================================================
* Spillovers among neighbors
* =============================================================================

*prep
cap drop avg_hp
cap drop L_avg_hp
bys area year_revised: egen avg_hp = mean(hp)
xtset hh_id_num year_revised
sort hh_id_num year_revised
by hh_id_num: gen L_avg_hp = L.avg_hp

foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"

*-------Ordered-----------------------
*TWFE hh nocont
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp if in_type==1 & inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_nc_`g'

*TWFE hh all cont
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt l_actual_incent) renovation if in_type==1 & inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_ac_`g'

*-------Random-----------------------
*TWFE hh nocont rand
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_nc_r_`g'

*TWFE hh all cont rand
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt l_actual_incent_rand) renovation if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_ac_r_`g'

*----------------------------------------
* TWFE RISK
*----------------------------------------

*-------Ordered-----------------------
*TWFE hh nocont
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp if in_type==1 & at_risk==1 & inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_risk_nc_`g'

*TWFE hh all cont
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp L.(i.actual_incent ib3.htc_num i.new_build i.renteroccupied l_home_value l_square_feet l_stories treat l_income l_bldg_age l_erate_alt l_actual_incent) renovation if in_type==1 & at_risk==1 & inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_risk_ac_`g'

*-------Random------------------------
*TWFE hh nocont rand
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp if in_type==1 & at_risk==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_risk_nc_r_`g'
	
*TWFE hh all cont rand
	xtset hh_id_num year_revised
	reghdfe hp_dif L_avg_hp L.(i.actual_incent_rand ib3.htc_num i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories treat ib1.inc_type_num_rand l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & at_risk==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
	eststo s_twfe_risk_ac_r_`g'
}
*----------------------------------------
* IVFE 
*----------------------------------------

foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"
*-------Ordered-----------------------
*IVFE hh nocont
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_nc_`g'

*IVFE hh all cont
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) L.(i.actual_incent i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num==`g', absorb(year_revised hh_id_num L_htc_num) vce(cluster area) nocons 
eststo s_ivfe_rh_ac_`g'

*-------Random------------------------
*IVFE hh nocont rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_nc_r_`g'

*IVFE hh all cont rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) L.(i.actual_incent_rand i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_ac_r_`g'

*----------------------------------------
* IVFE Risk
*----------------------------------------

*-------Ordered-----------------------
*IVFE hh nocont
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_risk_nc_`g'

*IVFE hh all cont
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) L.(i.actual_incent i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num==`g' & at_risk==1 , absorb(year_revised hh_id_num L_htc_num) vce(cluster area) nocons 
eststo s_ivfe_rh_risk_ac_`g'

*-------Random------------------------
*IVFE hh nocont rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num_rand==`g' & at_risk ==1 , absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_risk_nc_r_`g'

*IVFE hh all cont rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (L_avg_hp=L_treat) L.(i.actual_incent_rand i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num_rand==`g' & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo s_ivfe_rh_risk_ac_r_`g'
}

			
estimates dir s_twfe_* s_ivfe_*
local mlist = r(names)
local mtlist ""
foreach m of local mlist {
    local mtlist `"`mtlist' "`m'""'
}


esttab s_twfe_* s_ivfe_*, /// 	
	keep(L_avg_hp) nonumbers mtitles(`mtlist') ///
	b(%9.4fc) se(%9.4fc)
	
	esttab s_twfe_* s_ivfe_* using "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Tables/11_spill.tex", replace /// 	
	keep(L_avg_hp) nonumbers mtitles(`mtlist')	///
	b(%9.4fc) se(%9.4fc) 


* ------- First stage for comparisons---------------------------------------
	
foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"
*-------Ordered-----------------------
*IVFE hh nocont
xtset hh_id_num year_revised
reghdfe L_avg_hp L_treat if in_type==1 &inc_type_num==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo sf_ivfe_nc_`g'

*IVFE hh all cont
xtset hh_id_num year_revised
reghdfe L_avg_hp L_treat L.(i.actual_incent i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num==`g', absorb(year_revised hh_id_num L_htc_num) vce(cluster area) nocons 
eststo sf_ivfe_ac_`g'

*-------Random------------------------
*IVFE hh nocont rand
xtset hh_id_num year_revised
reghdfe L_avg_hp L_treat if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo sf_ivfe_nc_r_`g'

*IVFE hh all cont rand
xtset hh_id_num year_revised
reghdfe L_avg_hp L_treat L.(i.actual_incent_rand i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & inc_type_num_rand==`g', absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo sf_ivfe_ac_r_`g'
}

estimates dir sf_ivfe_*
local mlist = r(names)
local mtlist ""
foreach m of local mlist {
    local mtlist `"`mtlist' "`m'""'
}

esttab sf_ivfe_*, ///
b(%9.4fc) se(%9.4fc) ///
keep(L_treat) nonumbers mtitles (`mtlist')	

*----------NLCOM------------------------


local specs nc ac nc_r ac_r

foreach g in 1 2 3 {

    *--- Second stage (s_ivfe_rh) ---
    xtset hh_id_num year_revised
    ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo s_ivfe_rh_nc_`g'_s

    xtset hh_id_num year_revised
    ivreghdfe hp_dif (L_avg_hp=L_treat) ///
        L.(i.actual_incent i.new_build i.renteroccupied l_home_value ///
        l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & inc_type_num==`g', ///
        absorb(year_revised hh_id_num L_htc_num) nocons
    eststo s_ivfe_rh_ac_`g'_s

    xtset hh_id_num year_revised
    ivreghdfe hp_dif (L_avg_hp=L_treat) if in_type==1 & inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo s_ivfe_rh_nc_r_`g'_s

    xtset hh_id_num year_revised
    ivreghdfe hp_dif (L_avg_hp=L_treat) ///
        L.(i.actual_incent_rand i.new_build i.renter_occupied_random l_home_value ///
        l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo s_ivfe_rh_ac_r_`g'_s

    *--- First stage (sf_ivfe) ---
    xtset hh_id_num year_revised
    reghdfe L_avg_hp L_treat if in_type==1 & inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo sf_ivfe_nc_`g'_s

    xtset hh_id_num year_revised
    reghdfe L_avg_hp L_treat ///
        L.(i.actual_incent i.new_build i.renteroccupied l_home_value ///
        l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & inc_type_num==`g', ///
        absorb(year_revised hh_id_num L_htc_num) nocons
    eststo sf_ivfe_ac_`g'_s

    xtset hh_id_num year_revised
    reghdfe L_avg_hp L_treat if in_type==1 & inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo sf_ivfe_nc_r_`g'_s

    xtset hh_id_num year_revised
    reghdfe L_avg_hp L_treat ///
        L.(i.actual_incent_rand i.new_build i.renter_occupied_random l_home_value ///
        l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) nocons
    eststo sf_ivfe_ac_r_`g'_s
}

* ---- Tabulate -----------------
foreach g in 1 2 3 {
    if `g'==1 local glabel "High Income"
    if `g'==2 local glabel "Low Income"
    if `g'==3 local glabel "Mid Income"

    local rowb  ""
    local rowse ""

    foreach spec in nc nc_r ac ac_r {

        * Pull second stage: L_avg_hp coef from s_ivfe_rh
        quietly estimates restore s_ivfe_rh_`spec'_`g'
        scalar a     = _b[L_avg_hp]
        scalar var_a = _se[L_avg_hp]^2

        * Pull first stage: L_treat coef from sf_ivfe
        quietly estimates restore sf_ivfe_`spec'_`g'
        scalar b     = _b[L_treat]
        scalar var_b = _se[L_treat]^2

        * Delta method for product
        scalar prod   = a * b
        scalar var_ab = (b^2) * var_a + (a^2) * var_b
        scalar se_ab  = sqrt(var_ab)
        scalar t_ab   = prod / se_ab
        scalar p_ab   = 2 * (1 - normal(abs(t_ab)))

        local stars ""
        if p_ab < 0.001 local stars "***"
        else if p_ab < 0.01  local stars "**"
        else if p_ab < 0.05  local stars "*"

        local b_fmt  : display %9.4f prod
        local se_fmt : display %9.4f se_ab

        local rowb  `"`rowb' & `b_fmt'\sym{`stars'}"'
        local rowse `"`rowse' & (`se_fmt')"'
    }

    di "`glabel'"
    di "`rowb' \\"
    di "`rowse' \\"
    di "[0.5em]"
}
	
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
* =============================================================================
	

* =============================================================================
* sandbox
* =============================================================================

* Logit
bysort area year_revised: egen l_inc_avg = mean(l_income)
bysort area year_revised: egen l_inc_mdn = pctile(l_income), p(50)
bysort area year_revised: egen hp_avg = mean(hp)

xtset hh_id_num year_revised
xtlogit hp i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_ii 

xtlogit hp i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_inc_avg l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_ia

xtlogit hp i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_inc_mdn l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_im

xtreg hp_avg i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_ai

xtlogit hp_avg i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_inc_avg l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_aa

xtlogit hp_avg i.post##i.in_ter1 L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_inc_mdn l_bldg_age l_erate_alt i.htc_num) renovation if in_type==1, fe
eststo l_fe_am


*----------------------------------------
* SIMPLE TREATMENT EFFECTS TWFE POOLED
*----------------------------------------

*-------Ordered-----------------------
*TWFE hh nocont
xtset hh_id_num year_revised
reghdfe hp_dif i.post##i.in_ter1##Lib1.inc_type_num if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo t_twfe_nc

*TWFE hh cont
xtset hh_id_num year_revised
reghdfe hp_dif i.post##i.in_ter1##Lib1.inc_type_num L.(i.renteroccupied i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo t_twfe_ac

*-------Random-----------------------
*TWFE hh nocont rand
xtset hh_id_num year_revised
reghdfe hp_dif i.post##i.in_ter1##Lib1.inc_type_num_rand if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo t_twfe_nc_r

*TWFE hh all cont rand
xtset hh_id_num year_revised
reghdfe hp_dif i.post##i.in_ter1##Lib1.inc_type_num_rand L.(i.renter_occupied_random i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo t_twfe_ac_r

*----------------------------------------
* Lincoms
*----------------------------------------
foreach m in t_twfe_nc t_twfe_nc_r t_twfe_ac t_twfe_ac_r ///
             t_twfe_risk_nc t_twfe_risk_nc_r t_twfe_risk_ac t_twfe_risk_ac_r ///
             t_twfe_riskage_nc t_twfe_riskage_nc_r t_twfe_riskage_ac t_twfe_riskage_ac_r {

	estimates restore `m'
   
    if strpos("`m'", "c_r") {
        local low_var "1.post#1.in_ter1#2L.inc_type_num_rand"
        local mid_var "1.post#1.in_ter1#3L.inc_type_num_rand"
    }
    else {
        local low_var "1.post#1.in_ter1#2L.inc_type_num"
        local mid_var "1.post#1.in_ter1#3L.inc_type_num"
    }

    lincom 1.post#1.in_ter1 + `low_var'
    estadd scalar b_low  = r(estimate), replace
    estadd scalar se_low = r(se),       replace
	estadd scalar p_low = r(p), 		replace

    lincom 1.post#1.in_ter1 + `mid_var'
    estadd scalar b_mid  = r(estimate), replace
    estadd scalar se_mid = r(se),       replace
	estadd scalar p_mid = r(p), 		replace

	lincom 1.post#1.in_ter1
    estadd scalar b_high  = r(estimate),  	replace
    estadd scalar se_high = r(se), 			replace
	estadd scalar p_high = r(p), 			replace

    estimates store `m'
}

*----------------------------------------

* -------
	
esttab t_twfe_nc t_twfe_nc_r t_twfe_ac t_twfe_ac_r ///
       t_twfe_risk_nc t_twfe_risk_nc_r t_twfe_risk_ac t_twfe_risk_ac_r ///
       t_twfe_riskage_nc t_twfe_riskage_nc_r t_twfe_riskage_ac t_twfe_riskage_ac_r using /// 
	   "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/1. Current Draft/Tables/6_HP_DID.tex", replace ///
    stats(b_low se_low b_mid se_mid b_high se_high N, ///
          labels("Low Income" "" "Mid Income" "" "High Income" "" "Observations") ///
          fmt(%9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %12.0fc)) ///
    mtitles("TWFE no con" "TWFE no con rand" "TWFE all con" "TWFE all con rand" ///
            "TWFE Avail no con" "TWFE Avail no con rand" "TWFE Avail all con" "TWFE Avail all con rand" ///
            "TWFE Avail-Age no con" "TWFE Avail-Age no con rand" "TWFE Avail-Age all con" "TWFE Avail-Age all con rand") ///
    noobs b(%9.3fc) se(%9.3fc)

			
* =============================================================================
* Incentive Effects
* =============================================================================

* Pooled Estimation ===========================================================

*----------------------------------------
* TWFE
*----------------------------------------

*-------Ordered--------------------------
* TWFE no con
xtset hh_id_num year_revised
reghdfe hp_dif Lc.l_actual_incent##Lib1.inc_type_num if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo i_twfe_nc

* TWFE all con
xtset hh_id_num year_revised
reghdfe hp_dif Lc.l_actual_incent##Lib1.inc_type_num L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo i_twfe_ac

*-------Random--------------------------
* TWFE no con rand
xtset hh_id_num year_revised
reghdfe hp_dif Lc.l_actual_incent_rand##Lib1.inc_type_num_rand if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo i_twfe_nc_r

* TWFE all con rand
xtset hh_id_num year_revised
reghdfe hp_dif Lc.l_actual_incent_rand##Lib1.inc_type_num_rand L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo i_twfe_ac_r

*----------------------------------------
* IVFE
*----------------------------------------
* prep
foreach var in Llai Llai_r Litn Litn_r Llincent_1 Llincent_2 Llincent_3 Llincent_r1 Llincent_r2 Llincent_r3 Ltreat Ltreat_1 Ltreat_2 Ltreat_3 Ltreat_r1 Ltreat_r2 Ltreat_r3 {
	cap drop `var'
	}
xtset hh_id_num year_revised
bys hh_id_num (year_revised): gen Llai = L.l_actual_incent
bys hh_id_num (year_revised): gen Llai_r = L.l_actual_incent_rand
bys hh_id_num (year_revised): gen Litn = L.inc_type_num
bys hh_id_num (year_revised): gen Litn_r = L.inc_type_num_rand
bys hh_id_num (year_revised): gen Ltreat = L.treat
gen Llincent_1 = Llai * (Litn==1)
gen Llincent_2 = Llai * (Litn==2)
gen Llincent_3 = Llai * (Litn==3)
gen Llincent_r1 = Llai_r * (Litn_r==1)
gen Llincent_r2 = Llai_r * (Litn_r==2)
gen Llincent_r3 = Llai_r * (Litn_r==3)
gen Ltreat_1 = Ltreat * (Litn==1)
gen Ltreat_2 = Ltreat * (Litn==2)
gen Ltreat_3 = Ltreat * (Litn==3)
gen Ltreat_r1 = Ltreat * (Litn_r==1)
gen Ltreat_r2 = Ltreat * (Litn_r==2)
gen Ltreat_r3 = Ltreat * (Litn_r==3)

* note that 3 = mid, 2 = low, 1 = high 

*-------Ordered--------------------------
* IVFE no con
ivreghdfe hp_dif (Llincent_1 Llincent_2 Llincent_3 = Ltreat_1 Ltreat_2 Ltreat_3) if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) first
eststo i_ivfe_nc

* IVFE all con
xtset hh_id_num year_revised
ivreghdfe hp_dif (Llincent_1 Llincent_2 Llincent_3= Ltreat_1 Ltreat_2 Ltreat_3) L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo i_ivfe_ac

*-------Random--------------------------
* IVFE no con rand
ivreghdfe hp_dif (Llincent_r1 Llincent_r2 Llincent_r3 = Ltreat_r1 Ltreat_r2 Ltreat_r3) if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) first
eststo i_ivfe_nc_r

* IVFE all con rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (Llincent_r1 Llincent_r2 Llincent_r3 = Ltreat_r1 Ltreat_r2 Ltreat_r3) L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons first
eststo i_ivfe_ac_r

*----------------------------------------
* IVFE Risk
*----------------------------------------

*-------Ordered--------------------------
* IVFE no con
ivreghdfe hp_dif (Llincent_1 Llincent_2 Llincent_3 = Ltreat_1 Ltreat_2 Ltreat_3) if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) cluster(area) first 
eststo i_ivfe_risk_nc

* IVFE all con
xtset hh_id_num year_revised
ivreghdfe hp_dif (Llincent_1 Llincent_2 Llincent_3 = Ltreat_1 Ltreat_2 Ltreat_3) L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) renovation if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons first savefprefix(fs_)
eststo i_ivfe_risk_ac

*-------Random--------------------------
* IVFE no con rand
ivreghdfe hp_dif (Llincent_r1 Llincent_r2 Llincent_r3 = Ltreat_r1 Ltreat_r2 Ltreat_r3) if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) first savefprefix(fs_)
eststo i_ivfe_risk_nc_r

* IVFE all con rand
xtset hh_id_num year_revised
ivreghdfe hp_dif (Llincent_r1 Llincent_r2 Llincent_r3 = Ltreat_r1 Ltreat_r2 Ltreat_r3) L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age l_erate_alt) renovation if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons first savefprefix(fs_)
eststo i_ivfe_risk_ac_r
	
* =============================================================================
* Changes in Energy Prices 
* =============================================================================

* Pooled Estimation ===========================================================

*----------------------------------------
* TWFE
*----------------------------------------

*-----Ordered----------------------------
*TWFE no con
xtset hh_id_num year_revised 
reghdfe hp_dif L.i.inc_type_num##cL.l_erate_alt if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_nc

*TWFE all con
xtset hh_id_num year_revised 
reghdfe hp_dif L.i.inc_type_num##cL.l_erate_alt L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age i.actual_incent) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_ac

*-----Random----------------------------
*TWFE no con rand
xtset hh_id_num year_revised 
reghdfe hp_dif L.i.inc_type_num_rand##cL.l_erate_alt if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_nc_r

*TWFE all con rand
xtset hh_id_num year_revised 
reghdfe hp_dif L.i.inc_type_num_rand##cL.l_erate_alt L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age i.actual_incent_rand) renovation if in_type==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_ac_r

*----------------------------------------
* TWFE RISK
*----------------------------------------

*-------Ordered-----------------------
*TWFE hh nocont
xtset hh_id_num year_revised
reghdfe hp_dif L.i.inc_type_num##cL.l_erate_alt if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_risk_nc

*TWFE hh all cont
xtset hh_id_num year_revised
reghdfe hp_dif L.i.inc_type_num##cL.l_erate_alt L.(i.new_build i.renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age i.actual_incent) renovation if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_risk_ac

*-------Random------------------------
*TWFE hh nocont rand
xtset hh_id_num year_revised
reghdfe hp_dif L.i.inc_type_num_rand##cL.l_erate_alt if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
eststo e_twfe_risk_nc_r

*TWFE hh all cont rand
xtset hh_id_num year_revised
reghdfe hp_dif L.i.inc_type_num_rand##cL.l_erate_alt L.(i.new_build i.renter_occupied_random l_home_value l_square_feet l_stories l_income_rand l_bldg_age i.actual_incent_rand) renovation if in_type==1 & at_risk==1, absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons 
eststo e_twfe_risk_ac_r

*----------------------------------------
* Lincoms
*----------------------------------------
foreach m in e_twfe_nc e_twfe_ac e_twfe_nc_r e_twfe_ac_r e_twfe_risk_nc e_twfe_risk_ac e_twfe_risk_nc_r e_twfe_risk_ac_r {
    estimates restore `m'

    if strpos("`m'", "c_r") {
        lincom cL.l_erate_alt + 2L.inc_type_num_rand#cL.l_erate_alt
        estadd scalar b_low  = r(estimate)		, replace
        estadd scalar se_low = r(se), replace
		estadd scalar p_low = r(p), replace

        lincom cL.l_erate_alt + 3L.inc_type_num_rand#cL.l_erate_alt
        estadd scalar b_mid  = r(estimate), replace
        estadd scalar se_mid = r(se), replace
		estadd scalar p_mid = r(p), replace

		lincom cL.l_erate_alt
        estadd scalar b_high  = r(estimate), replace
        estadd scalar se_high = r(se), replace
		estadd scalar p_high = r(p), replace
	}
    else {
        lincom cL.l_erate_alt + 2L.inc_type_num#cL.l_erate_alt
        estadd scalar b_low  = r(estimate), replace
        estadd scalar se_low = r(se), replace
		estadd scalar p_low = r(p), replace

        lincom cL.l_erate_alt + 3L.inc_type_num#cL.l_erate_alt
        estadd scalar b_mid  = r(estimate), replace
        estadd scalar se_mid = r(se), replace
		estadd scalar p_mid = r(p), replace

		lincom cL.l_erate_alt
        estadd scalar b_high  = r(estimate), replace
        estadd scalar se_high = r(se), replace
		estadd scalar p_high = r(p), replace
    }

    estimates store `m'
}

	

* Lifespan comparison energy --------------------------------------------------


* ------------ set assumed values ----------
scalar drop _all
scalar cval = 4998.09667 // Average electricity usage to heat an electrically-heated home in WA climate zone 5B in 2020 per RECS 2020.
scalar cse = 566.708128 // SE of the same
scalar rval = .0411 // 10-year treasury bond 11/2025 is 4.11%
scalar tval = 15 // general lifetime 
scalar fval = 1.5 // winter COP for design temp of -5 is 1.2 - 1.5, using upper end given extreme cold assumption
scalar p_1 = 0.0684 // 2015 zone 1 price
scalar p_0 = 0.0616 // 2015 zone 0 price

// We see prices increase from about 0.0605 to 0.0741
// That's the equivalent of increasing the NPV cost savings from switching from 2224.21 to 2724.20: Just $500

scalar NPV_1 = cval*(1/fval)*p_1*(1-(1+rval)^(-tval))/rval
scalar NPV_0 = cval*(1/fval)*p_0*(1-(1+rval)^(-tval))/rval

scalar s_1 = (cval*(1-1/fval)*p_1*(1-(1+rval)^(-tval)))/rval
scalar s_0 = (cval*(1-1/fval)*p_0*(1-(1+rval)^(-tval)))/rval

* ---------- sensitivity analysis ----------
// derivative of 1/(C*(1-1/f)(1-1/(r+1)^T)) to get differences for erate

scalar dsdc1 = p_1*(1-1/fval)*(1-(1+rval)^(-tval))/rval
scalar dsdc0 = p_0*(1-1/fval)*(1-(1+rval)^(-tval))/rval
scalar dsdp1 = cval*(1-1/fval)*(1-(1+rval)^(-tval))/rval
scalar dsdp0 = cval*(1-1/fval)*(1-(1+rval)^(-tval))/rval
scalar dsdf1 = cval*p_1*(1-(1+rval)^(-tval))/(fval^2*rval)
scalar dsdf0 = cval*p_0*(1-(1+rval)^(-tval))/(fval^2*rval)
scalar dsdt1 = cval*p_1*(fval-1)*ln(rval+1)/(rval*fval*(rval+1)^tval)
scalar dsdt0 = cval*p_0*(fval-1)*ln(rval+1)/(rval*fval*(rval+1)^tval)
scalar dsdr1 = -cval*(fval-1)*p_1*(rval+1)^((-tval)-1)*((rval+1)^(tval+1)+((-tval)-1)*rval-1)/(fval*rval^2)
scalar dsdr0 = -cval*(fval-1)*p_0*(rval+1)^((-tval)-1)*((rval+1)^(tval+1)+((-tval)-1)*rval-1)/(fval*rval^2)

scalar eq_1h = (3600 - s_1)/dsdp1+p_1
scalar eq_1l = (2800 - s_1)/dsdp1+p_1

scalar list eq_1h eq_1l


* ---------------------------------------------
* Monte Carlo
* ---------------------------------------------

preserve
scalar drop _all
set more off

*------- Constraints --------------------------

scalar cnum = 4998.09667
scalar cse  = 566.708128

scalar rnum = 0.0411
scalar rse = 0.24194485 // SE of .24194485% https://fred.stlouisfed.org/series/DGS10

scalar tnum = 15 
scalar tsd = 5 // SD assumed to vary up or down by 5 years (https://www.trane.com/residential/en/resources/troubleshooting/heat-pumps/how-long-do-heat-pumps-last/)
scalar fnum = 2.0 //  Assumed cold climate system
scalar fsd = .8 // SD assumed to vary up or down 0.3 

scalar p_1  = 0.0684
scalar p_0  = 0.0616

* number of simulations
local M = 10000

*------- Coefficients -------------------

* MODEL 1: price elasticity model 
estimates restore e_ivfe_pc
scalar beta_e1 = _b[Le_1]
scalar se_e1 = _se[Le_1]
scalar beta_e2 = _b[Le_2]
scalar se_e2 = _se[Le_2]
scalar beta_e2 = _b[Le_3]
scalar se_e2 = _se[Le_3]

* MODEL 1r: price elasticity model rand
estimates restore e_ivfe_pc_r
scalar beta_e1r = _b[Le_1r]
scalar se_e1r = _se[Le_1r]
scalar beta_e2r = _b[Le_2r]
scalar se_e2r = _se[Le_2r]
scalar beta_e2r = _b[Le_3r]
scalar se_e2r = _se[Le_3r]

* MODEL 2: incentive models
estimates restore i_ivfe_pc
scalar beta_i1 = _b[Llincent_1]
scalar se_i1 = _se[Llincent_1]
scalar beta_i2 = _b[Llincent_2]
scalar se_i2 = _se[Llincent_2]
scalar beta_i3 = _b[Llincent_3]
scalar se_i3 = _se[Llincent_3]

* MODEL 2r: incentive models
estimates restore i_ivfe_pc_r
scalar beta_i1r = _b[Llincent_r1]
scalar se_i1r = _se[Llincent_r1]
scalar beta_i2r = _b[Llincent_r2]
scalar se_i2r = _se[Llincent_r2]
scalar beta_i3r = _b[Llincent_r3]
scalar se_i3r = _se[Llincent_r3]

*------- Postfile for storage -------------------
tempname handle
postfile `handle' ///
    s1 eq1h eq1l ///
	Be1h Be1hr Be1l Be1lr ///
	Be2h Be2hr Be2l Be2lr ///
	Be3h Be3hr Be3l Be3lr ///
	B2h B2hr B2l B2lr ///
	B3h B3hr B3l B3lr ///
	using mc_results.dta, replace

*------- Monte Carlo Loop -------------------

forvalues i = 1/`M' {

	*------- Draw Parameters -------------------

    * draw consumption
    scalar cval = rnormal(cnum, cse)
	scalar rval = rnormal(rnum, rse)
	scalar tval = rnormal(tnum, tsd)
	scalar fval = rnormal(fnum, fsd)
	
	*------- Draw Betas (Monte Carlo coeff) -------
	scalar beta_e1d   = rnormal(beta_e1,   se_e1)
	scalar beta_e1rd  = rnormal(beta_e1r,  se_e1r)
	scalar beta_e2d   = rnormal(beta_e2,   se_e2)
	scalar beta_e2rd  = rnormal(beta_e2r,  se_e2r)
	scalar beta_e3d   = rnormal(beta_e3,   se_e3)
	scalar beta_e3rd  = rnormal(beta_e3r,  se_e3r)

	scalar beta_i1d  = rnormal(beta_i1,  se_i1)
	scalar beta_i2d  = rnormal(beta_i2,  se_i2)
	scalar beta_i3d  = rnormal(beta_i3,  se_i3)

	scalar beta_i1rd = rnormal(beta_i1r, se_i1r)
	scalar beta_i2rd = rnormal(beta_i2r, se_i2r)
	scalar beta_i3rd = rnormal(beta_i3r, se_i3r)
	
	* constrain
	if (rval <= 0) continue
    if (tval <= 0) continue
    if (fval <= 1) continue 
	
	*------- Formulas --------------------------
	scalar A = (1 - (1+rval)^(-tval)) / rval // annuity formula
    scalar s1 = cval*(1-1/fval)*p_1*A

	*------- Derivatives --------------------------
    scalar dsdp1 = cval*(1-1/fval)*A
	if (dsdp1 == 0) continue
	
	*------- Equating Prices --------------------------
    scalar eq1h = (3600 - s1)/dsdp1 + p_1
    scalar eq1l = (2800 - s1)/dsdp1 + p_1
	if (eq1h <= 0 | eq1l <= 0) continue
    if (eq1h == . | eq1l == .) continue

	*------- Transform Data --------------------------
	
    * price elasticity transformed through log-price map
    scalar Be1h = beta_e1d * ( ln(eq1h) - ln(p_1) )
    scalar Be1l = beta_e1d * ( ln(eq1l) - ln(p_1) )
    scalar Be1hr = beta_e1rd * ( ln(eq1h) - ln(p_1) )
    scalar Be1lr = beta_e1rd * ( ln(eq1l) - ln(p_1) )
    scalar Be2h = beta_e2d * ( ln(eq1h) - ln(p_1) )
    scalar Be2l = beta_e2d * ( ln(eq1l) - ln(p_1) )
    scalar Be2hr = beta_e2rd * ( ln(eq1h) - ln(p_1) )
    scalar Be2lr = beta_e2rd * ( ln(eq1l) - ln(p_1) )
    scalar Be3h = beta_e3d * ( ln(eq1h) - ln(p_1) )
    scalar Be3l = beta_e3d * ( ln(eq1l) - ln(p_1) )
    scalar Be3hr = beta_e3rd * ( ln(eq1h) - ln(p_1) )
    scalar Be3lr = beta_e3rd * ( ln(eq1l) - ln(p_1) )

    * incentive betas
    scalar B2h = beta_i2d * ( ln(3800) - ln(200) )
    scalar B2l = beta_i2d * ( ln(3800) - ln(1000) )
    scalar B3h = beta_i3d * ( ln(3800) - ln(200) )
    scalar B3l = beta_i3d * ( ln(3800) - ln(1000) )
    scalar B2hr = beta_i2rd * ( ln(3800) - ln(200) )
    scalar B2lr = beta_i2rd * ( ln(3800) - ln(1000) )
    scalar B3hr = beta_i3rd * ( ln(3800) - ln(200) )
    scalar B3lr = beta_i3rd * ( ln(3800) - ln(1000) )

	*------- Store Data --------------------------
    post `handle' ///
        (s1) (eq1h) (eq1l) ///
		(Be1h) (Be1hr) (Be1l) (Be1lr) ///
		(Be2h) (Be2hr) (Be2l) (Be2lr) ///
		(Be3h) (Be3hr) (Be3l) (Be3lr) ///
        (B2h) (B2hr) (B2l) (B2lr) ///
        (B3h) (B3hr) (B3l) (B3lr)
}
	
postclose `handle'

*------- Summarize --------------------------
use mc_results.dta, clear
summarize

di _newline(2) "95% CIs + tests of mean = 0"

foreach v of varlist s1 eq1h eq1l Be1h Be1hr Be1l Be1lr ///
	Be2h Be2hr Be2l Be2lrBe3h Be3hr Be3l Be3lr ///
    B2h B2hr B2l B2lr B3h B3hr B3l B3lr {

    di "----------------------------------------"
    di "`v'"

    quietly summarize `v'
    scalar mu = r(mean)
    scalar sd = r(sd)
    scalar n  = r(N)
    scalar se = sd / sqrt(n)

    * 95% MC CI
    quietly centile `v', centile(2.5 97.5)
    scalar lo = r(c_1)
    scalar hi = r(c_2)

    * z-test of H0: mean(`v') = 0
    scalar z = mu / se
    scalar p = 2 * (1 - normal(abs(z)))

    di "Estimate: " %9.4f mu
    di "95% CI:   [" %9.4f lo " , " %9.4f hi "]"
    di "z-test:   z = " %9.3f z "   p = " %9.4f p
}

*--------Output -------------------------------

tempname outf
postfile `outf' str12 varname mu lo hi z p using mc_summary.dta, replace

foreach v of varlist  s1 eq1h eq1l Be1h Be1hr Be1l Be1lr ///
	Be2h Be2hr Be2l Be2lrBe3h Be3hr Be3l Be3lr ///
    B2h B2hr B2l B2lr B3h B3hr B3l B3lr {
    quietly summarize `v'
    scalar mu = r(mean)
    scalar sd = r(sd)
    scalar n  = r(N)
    scalar se = sd / sqrt(n)
    quietly centile `v', centile(2.5 97.5)
    scalar lo = r(c_1)
    scalar hi = r(c_2)
    scalar z = mu / se
    scalar p = 2*(1 - normal(abs(z)))
    post `outf' ("`v'") (mu) (lo) (hi) (z) (p)
}

postclose `outf'

use mc_summary.dta, clear

* Format numbers for readability
format mu lo hi z p %9.4f

esttab using mc_results.tex, ///
    cells("mu(fmt(4)) lo(fmt(4)) hi(fmt(4)) z(fmt(3)) p(fmt(4))") ///
    noobs label nonumber booktabs replace ///
    title("Monte Carlo Simulation Results") ///
    collabels("Estimate" "2.5\%" "97.5\%" "z" "p-value")
restore

* ENERGY PRICES
* Income-Specific Estimation =================================================

foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"

* Ordered ---------------------------------------------------------------
    xtset hh_id_num year_revised	
	
    reghdfe hp_dif L.l_erate_alt ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_nc

    reghdfe hp_dif L.l_erate_alt ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
		l_stories l_income l_bldg_age i.actual_incent) renovation ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_ac

* Ordered At Risk --------------------------------------------------------

    reghdfe hp_dif L.l_erate_alt ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_risk_nc

    reghdfe hp_dif L.l_erate_alt ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
		l_stories l_income l_bldg_age i.actual_incent) renovation ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_risk_ac

* Random ---------------------------------------------------------------
    xtset hh_id_num year_revised

    reghdfe hp_dif L.l_erate_alt ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_nc_r

    reghdfe hp_dif L.l_erate_alt ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
		l_stories l_income_rand l_bldg_age i.actual_incent) renovation ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_ac_r

* Random At Risk ----------------------------------------------------------

    reghdfe hp_dif L.l_erate_alt ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_risk_nc_r

    reghdfe hp_dif L.l_erate_alt ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
		l_stories l_income_rand l_bldg_age i.actual_incent) renovation ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo e_g`g'_risk_ac_r
}


*----------------------------------------
* Tabulate
*----------------------------------------

esttab ///
    e_twfe_nc e_twfe_nc_r e_twfe_ac e_twfe_ac_r ///
    e_twfe_risk_nc e_twfe_risk_nc_r e_twfe_risk_ac e_twfe_risk_ac_r, ///
		rename(L.l_erate_alt "High" 2L.inc_type_num#cL.l_erate_alt "Low" 3L.inc_type_num#cL.l_erate_alt "Mid" ///
	2L.inc_type_num_rand#cL.l_erate_alt "Low" 3L.inc_type_num_rand#cL.l_erate_alt "Mid") ///
	keep("Low" "Mid" "High") ///
    b(%9.4fc) se(%9.4fc) ///
		stats(b_low se_low p_low b_mid se_mid p_mid b_high se_high p_high N, ///
        labels("Low Income" "" "" "Mid Income" "" "" "High Income" "" "" "Observations") ///
          fmt(%9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %12.0fc)) ///
    mtitles("TWFE no con" "TWFE no con rand" ///
            "TWFE all con" "TWFE all con rand" ///
            "TWFE (risk) no con" "TWFE (risk) no con rand" ///
            "TWFE (risk) all con" "TWFE (risk) all con rand") ///
    title("Comparative Marginal Effect of Lagged Log Electric Prices")
	

esttab ///
    e_twfe_nc e_twfe_nc_r e_twfe_ac e_twfe_ac_r ///
    e_twfe_risk_nc e_twfe_risk_nc_r e_twfe_risk_ac e_twfe_risk_ac_r using "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Tables/10_electric_rate.tex", replace ///
	rename(L.l_erate_alt "High" 2L.inc_type_num#cL.l_erate_alt "Low" 3L.inc_type_num#cL.l_erate_alt "Mid" ///
	2L.inc_type_num_rand#cL.l_erate_alt "Low" 3L.inc_type_num_rand#cL.l_erate_alt "Mid") ///
	keep("Low" "Mid" "High") ///
    b(%9.4fc) se(%9.4fc) ///
    mtitles("TWFE no con" "TWFE no con rand" ///
            "TWFE all con" "TWFE all con rand" ///
            "TWFE (risk) no con" "TWFE (risk) no con rand" ///
            "TWFE (risk) all con" "TWFE (risk) all con rand") ///
    title("Comparative Marginal Effect of Lagged Log Electric Prices")

esttab e_g2_nc e_g2_ac e_g2_nc_r e_g2_ac_r ///
       e_g3_nc e_g3_ac e_g3_nc_r e_g3_ac_r ///
       e_g1_nc e_g1_ac e_g1_nc_r e_g1_ac_r ///
    , keep(L.l_erate_alt) ///
    coeflabels(L.l_erate_alt "Log Price") ///
    mtitles("Low NC" "Low AC" "Low NC R" "Low AC R" ///
            "Mid NC" "Mid AC" "Mid NC R" "Mid AC R" ///
            "High NC" "High AC" "High NC R" "High AC R") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    title("Within-Group Energy Price Effects — Full Sample") ///
    nonumbers


* At-risk sample
esttab e_g2_risk_nc e_g2_risk_ac e_g2_risk_nc_r e_g2_risk_ac_r ///
       e_g3_risk_nc e_g3_risk_ac e_g3_risk_nc_r e_g3_risk_ac_r ///
       e_g1_risk_nc e_g1_risk_ac e_g1_risk_nc_r e_g1_risk_ac_r ///
    , keep(L.l_erate_alt) ///
    coeflabels(L.l_erate_alt "Log Price") ///
    mtitles("Low NC" "Low AC" "Low NC R" "Low AC R" ///
            "Mid NC" "Mid AC" "Mid NC R" "Mid AC R" ///
            "High NC" "High AC" "High NC R" "High AC R") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    title("Within-Group Energy Price Effects — At Risk Sample") ///
    nonumbers


// Given we're working with 0.01 ∆ in rates, multiply this by a 0.01 to get the typical movement: 
// Given that we're working with a 0.1 ∆ in f, multiply this by 0.1 to get the typical movement. 
// All shows that relative to the 0.0001-2 findings, these sensitivities are an order of magnitude smaller. 






* Propensity score matching ---------------------------------------------------

cap drop pscore
cap drop L_htc_num 
xtset hh_id_num year_revised
bysort hh_id_num (year_revised): gen L_htc_num = L.htc_num
logit treat ib3.L_htc_num i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1
predict pscore, pr

psmatch2 treat ib3.L_htc_num i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1, ///
    outcome(hp_dif) ///
    neighbor(1) ///         // 1-to-1 nearest neighbor
    caliper(0.01) ///      // optional caliper width
    common      // restrict to common support and matching with replacment 

pstest ib3.L_htc_num i.new_build l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1, both

* Makes it worse! 

* Proof of correlation in income and housing prices ---------------------------

xtset hh_id_num year_revised
reghdfe home_value income, absorb(tract_fips year_revised)
reghdfe home_value income_rand, absorb(tract_fips year_revised)


* Income discontinuity graphs -------------------------------------------------

*----------------------------------------
* 1. Cutoff a
*----------------------------------------
rdbwselect hp_dif inc_cent_a if in_type==1 & inc_cent_a<=79280, p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
scalar bwl = e(h_msetwo_l)
scalar bwr = e(h_msetwo_r)

* given poverty limit maximum of 39640 in 2022, kept data bounded to +/- 79280
	
twoway ///
    (lpolyci hp_dif inc_cent_a if inc_cent_a<0 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwl') clcolor(blue) clwidth(medthick) fcolor(blue%25)) ///
    (lpolyci hp_dif inc_cent_a if inc_cent_a>=0 & inc_cent_a<=79280  & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwr') clcolor(red) clwidth(medthick) fcolor(red%25)), ///
    xtitle("Income") ytitle("Fraction of Households") ///
    legend(order(2 "Below" 4 "Above") cols(1) region(lstyle(none))) ///
    graphregion(color(white)) 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/rdd_inc_oo_post.png", replace

*----------------------------------------
* 2. Cutoff b
*----------------------------------------
rdbwselect hp_dif inc_cent_b if in_type==1 & inc_cent_b<=79280, p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
scalar bwl = e(h_msetwo_l)
scalar bwr = e(h_msetwo_r)

* given poverty limit maximum of 39640 in 2022, kept data bounded to +/- 79280
	
twoway ///
    (lpolyci hp_dif inc_cent_b if inc_cent_b<0 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwl') clcolor(blue) clwidth(medthick) fcolor(blue%25)) ///
    (lpolyci hp_dif inc_cent_b if inc_cent_b>=0 & inc_cent_b<=79280 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwr') clcolor(red) clwidth(medthick) fcolor(red%25)), ///
    xtitle("Income") ytitle("Fraction of Households") ///
    legend(order(2 "Below" 4 "Above") cols(1) region(lstyle(none))) ///
    graphregion(color(white)) 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/rdd_inc_or_post.png", replace

*----------------------------------------
* 3. Cutoff c
*----------------------------------------
rdbwselect hp_dif inc_cent_c if in_type==1 & inc_cent_c<=79280, p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
scalar bwl = e(h_msetwo_l)
scalar bwr = e(h_msetwo_r)

* given poverty limit maximum of 39640 in 2022, kept data bounded to +/- 79280
	
twoway ///
    (lpolyci hp_dif inc_cent_c if inc_cent_c<0 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwl') clcolor(blue) clwidth(medthick) fcolor(blue%25)) ///
    (lpolyci hp_dif inc_cent_c if inc_cent_c>=0 & inc_cent_c<=79280 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwr') clcolor(red) clwidth(medthick) fcolor(red%25)), ///
    xtitle("Income") ytitle("Fraction of Households") ///
    legend(order(2 "Below" 4 "Above") cols(1) region(lstyle(none))) ///
    graphregion(color(white)) 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/rdd_inc_ro_post.png", replace

*----------------------------------------
* 4. Cutoff d
*----------------------------------------
rdbwselect hp_dif inc_cent_d if in_type==1 & inc_cent_d<=79280, p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
scalar bwl = e(h_msetwo_l)
scalar bwr = e(h_msetwo_r)

* given poverty limit maximum of 39640 in 2022, kept data bounded to +/- 79280
	
twoway ///
    (lpolyci hp_dif inc_cent_d if inc_cent_d<0 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwl') clcolor(blue) clwidth(medthick) fcolor(blue%25)) ///
    (lpolyci hp_dif inc_cent_d if inc_cent_d>=0 & inc_cent_d<=79280 & in_type==1, ///
        degree(1) kernel(epanechnikov) bw(`=bwr') clcolor(red) clwidth(medthick) fcolor(red%25)), ///
    xtitle("Income") ytitle("Fraction of Households") ///
    legend(order(2 "Below" 4 "Above") cols(1) region(lstyle(none))) ///
    graphregion(color(white)) 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/rdd_inc_rr_post.png", replace



* -----------------------------------------------------------------------------
preserve
collapse (mean) prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1, by(treat)
list
mkmat prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if treat==0, matrix(X0)
mkmat prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if treat==1, matrix(X1)
matrix list X0
matrix list X1
restore

preserve
collapse (mean) prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1
list
mkmat prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation, matrix(X)
matrix list X
restore

xtset hh_id_num year_revised
reghdfe hp_dif prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1, absorb( hh_id_num) vce(cluster hh_id_num) nocons
matrix b = e(b)'
matrix list b

reghdfe hp_dif prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1 & treat==0, absorb( hh_id_num) vce(cluster hh_id_num) nocons
matrix b0 = e(b)'
matrix list b0

reghdfe hp_dif prior_htc_num* new_build renteroccupied l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt renovation if in_type==1 & treat==1, absorb( hh_id_num) vce(cluster hh_id_num) nocons

matrix b1 = e(b)'
matrix list b1

matrix A = (X0 - X1) * b1
matrix list A

matrix B = X1 * (b0 - b1)
matrix list B

matrix C = (X0 - X1) * (b0 - b1)
matrix list C

cap drop eligible
cap drop treated
gen eligible = ((in_ter1==1)&(low_inc_qual==1|mid_inc_qual==1)|(in_ter1==0)&(low_inc_qual==1)) & (fuel_type !="FGA")&in_type==1
gen treated = eligible==1 & post==1 & in_ter1==1

reghdfe hp_dif l_actual_incent L.(l_home_value l_square_feet l_stories l_income l_bldg_age l_erate_alt) if eligible==1 & treated==1, absorb(new_build renovation renteroccupied year_revised hh_id_num) vce(cluster hh_id_num) nocons

* Non-Incentive Effects within Treatment

xtset hh_id_num year_revised

***Ordered***
cap drop L_treat 
cap drop L_actual_incent
cap drop L_inc_type_num
bysort hh_id_num (year_revised): gen L_treat = L.treat
bysort hh_id_num (year_revised): gen L_actual_incent = L.actual_incent
bysort hh_id_num (year_revised): gen L_inc_type_num = L.inc_type_num

* IV for conditionally exogenous change
xtset hh_id_num year_revised
ivreghdfe hp_dif (ib0.L_treat#ib1.L_inc_type_num=ib0.in_ter1#ib0.L_actual_incent#ib1.L_inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons resid
eststo ni_ivfe_mod
cap drop resid
predict double resid, resid

* TWFE on remaining variation
reghdfe resid ib0.L_treat#ib1.L_inc_type_num ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo ni_fe_resid_mod

* ivreg gives the explained variation attriubtable to change in incentive
* reghdfe give all variation, holding incentives constant (partialling out their effect)
* see there is still a lot of variation: given the use of household and year fixed effects, the variation captured by treat in this instance is describing largely a time-varying within-household effect that significantly alters the liklihood of adoption and is not meaningfully correlated with incentive levels, income or prior heating technology. 

estimates restore ni_fe_mod
local A1 = _b[1.L_treat#1.L_inc_type_num]
local A2 = _b[1.L_treat#2.L_inc_type_num]
local A3 = _b[1.L_treat#3.L_inc_type_num]
di `A1' `A2' `A3'

estimates restore ni_ivfe_mod
local B1 = _b[1.L_treat#1.L_inc_type_num]
local B2 = _b[1.L_treat#2.L_inc_type_num]
local B3 = _b[1.L_treat#3.L_inc_type_num]
di `B1' `B2' `B3'

scalar C1 = `A1'-`B1'
scalar C2 = `A2'-`B2'
scalar C3 = `A3'-`B3'
di C1 C2 C3

***Random***
cap drop L_treat_rand 
cap drop L_actual_incent_rand
cap drop L_inc_type_num_rand
bysort hh_id_num (year_revised): gen L_treat = L.treat
bysort hh_id_num (year_revised): gen L_actual_incent_rand = L.actual_incent_rand
bysort hh_id_num (year_revised): gen L_inc_type_num_rand = L.inc_type_num_rand

* IV for conditionally exogenous change
xtset hh_id_num year_revised
ivreghdfe hp_dif (ib0.L_treat#ib1.L_inc_type_num_rand=ib0.in_ter1#ib0.L_actual_incent_rand#ib1.L_inc_type_num_rand) ib1.L_inc_type_num_rand##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income_rand l_bldg_age renter_occupied_random l_erate_alt) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons resid
eststo ni_ivfe_mod_rand
cap drop resid
predict double resid, resid

* TWFE on remaining variation
reghdfe resid ib0.L_treat#ib1.L_inc_type_num_rand ib1.L_inc_type_num_rand##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income_rand l_bldg_age renter_occupied_random l_erate_alt) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo ni_fe_resid_mod_rand

estimates restore ni_fe_mod_rand
local D1 = _b[1.L_treat#1.L_inc_type_num_rand]
local D2 = _b[1.L_treat#2.L_inc_type_num_rand]
local D3 = _b[1.L_treat#3.L_inc_type_num_rand]
di `D1' `D2' `D3'

estimates restore ni_ivfe_mod_rand
local E1 = _b[1.L_treat#1.L_inc_type_num_rand]
local E2 = _b[1.L_treat#2.L_inc_type_num_rand]
local E3 = _b[1.L_treat#3.L_inc_type_num_rand]
di `E1' `E2' `E3'

scalar F1 = `D1'-`E1'
scalar F2 = `D2'-`E2'
scalar f3 = `D3'-`E3'
di F1 F2 F3




* ==============================================
* ROBUSTNESS FOR IDENTIFICATION OF INCENTIVE EFFECTS
* ==============================================

cap drop at_risk
cap drop switch
cap drop everswitch
cap drop at_risk_age
gen switch = 0
xtset hh_id_num year_revised
bys hh_id_num (year_revised): replace switch = 1 if htc_num!=L.htc_num // switch if htc_num!=htc_num prior
bys hh_id_num (year_revised): replace switch = 0 if year_revised == year_revised[1] // first year can't count as switching
bys hh_id_num: egen everswitch = max(switch)
gen at_risk = 1
bys hh_id_num (year_revised): replace at_risk = 0 if L.switch==1
bys hh_id_num: replace at_risk = 0 if year_built==year_revised | year_built == year // new houses don't need new systems
bys hh_id_num (year_revised): replace at_risk = 0 if L.at_risk == 0
gen at_risk_age = at_risk
bys hh_id_num (year_revised): replace at_risk_age = 0 if year_revised - year_built<=15  // households under 15 years won't need new systems

xtset hh_id_num year_revised
ivreghdfe hp_dif (Lc.l_actual_incent#Lib1.inc_type_num=L.treat#L.inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo incent_mod

ivreghdfe hp_dif (Lc.l_actual_incent#Lib1.inc_type_num=L.treat#L.inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1 & everswitch==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo incent_everswitch

ivreghdfe hp_dif (Lc.l_actual_incent#Lib1.inc_type_num=L.treat#L.inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1 & at_risk==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo incent_risk

ivreghdfe hp_dif (Lc.l_actual_incent#Lib1.inc_type_num=L.treat#L.inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1 & at_risk_age==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo incent_riskage

ivreghdfe hp_dif (Lc.l_actual_incent#Lib1.inc_type_num=L.treat#L.inc_type_num) ib1.L_inc_type_num##Lib3.htc_num L.(i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt) renovation if in_type==1 & at_risk_age==1 & everswitch==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo incent_riskage_switcher

esttab incent_mod incent_everswitch incent_risk incent_riskage incent_riskage_switcher, ///
keep(*inc_type_num*) ///
stat(widstat cd idp r2c r2_a N, label("F.S. F-stat" "F.S. Weak ID F-stat" "F.S. KP p-val" "F.S. R-val" "S.S. R-val" "Observ."))


* EXPLORING IVTWFE

xtset hh_id_num year_revised 
ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo e1

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) L.(ib1.inc_type_num##ib3.htc_num l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied i.actual_incent) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num) nocons
eststo e2

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) if in_type==1, absorb(area year_revised) vce(cluster area) nocons
eststo e3

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) L.(ib1.inc_type_num##ib3.htc_num l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied i.actual_incent) renovation if in_type==1, absorb(area year_revised) vce(cluster area) nocons
eststo e4

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) if in_type==1, absorb(area year_revised) vce(cluster hh_id_num) nocons
eststo e5

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) L.(ib1.inc_type_num##ib3.htc_num l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied i.actual_incent) renovation if in_type==1, absorb(area year_revised) vce(cluster hh_id_num) nocons
eststo e6

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) if in_type==1, absorb(hh_id_num year_revised) vce(cluster area) nocons
eststo e7

ivreghdfe hp_dif (L.l_e_rate=L.l_erate_alt) L.(ib1.inc_type_num##ib3.htc_num l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied i.actual_incent) renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster area) nocons
eststo e8

esttab e1 e2 e3 e4 e5 e6 e7 e8, ///
keep(L.l_e_rate) ///
b(%9.3fc) se(%9.3fc) ///
coeflabels(L.l_e_rate "Prior Electric Cost") ///
mlabels("HH-HH" "HH-HH cont" "Area-Area" "Area-Area cont" "Area-HH" "Area-HH cont")

boottest l_e_rate, reps(100)
  

*==================================================

forvalues var = 10(10)300 {
    display `var'
	foreach v in set_flag set_flag_rand changeval changeval_rand l_sim_incent l_sim_incent_rand sim_incent sim_incent_rand yhat_old_* yhat_new_* shift_* adopt_old_a adopt_old_b adopt_new_a adopt_new_b adopt_old_a_rand adopt_old_b_rand adopt_new_a_rand adopt_new_b_rand change change_a change_b change_rand change_a_rand change_b_rand incent_adder incent_adder_rand {
    cap drop `v'
	}
		
    // Define flags
    gen changeval = 0
	gen changeval_rand = 0
	gen set_flag = 3
	replace set_flag = 1 if income <= `var'/100 * pov_limit & actual_incent == qual_inc_incent
	replace set_flag = 2 if income > `var'/100 * pov_limit & actual_incent == high_inc_incent
	gen set_flag_rand = 3
	replace set_flag_rand = 1 if income_rand <= `var'/100 * pov_limit_rand & actual_incent_rand == qual_inc_incent
	replace set_flag_rand = 2 if income_rand >  (`var'/100)*pov_limit_rand & actual_incent_rand == high_inc_incent

	// Initial settings = real incentives
	gen L_l_sim_incent = L_l_actual_incent
	gen L_l_sim_incent_rand = L_l_actual_incent_rand



    // Get baseline adoption totals
    summarize yhat_old_`var' if set_flag == 2 & in_ter1 == 1, meanonly
	scalar adopt_old_a = r(sum)
    summarize yhat_old_`var' if set_flag == 1 & in_ter1 == 1, meanonly
	scalar adopt_old_b = r(sum)
	
	// Get baseline random adoption totals
    summarize yhat_old_`var'_rand if set_flag_rand == 2 & in_ter1 == 1, meanonly
	scalar adopt_old_a_rand = r(sum)
    summarize yhat_old_`var'_rand if set_flag_rand == 1 & in_ter1 == 1, meanonly
	scalar adopt_old_b_rand = r(sum)

	// Set incentives for new set
	replace L_l_sim_incent = ln(high_inc_incent) if income > (`var'/100)*pov_limit 
	replace L_l_sim_incent_rand = ln(high_inc_incent) if income_rand > (`var'/100)*pov_limit_rand
	gen sim_incent = (qual_inc_incent)
	replace sim_incent = (high_inc_incent) if income > (`var'/100)*pov_limit 
	gen sim_incent_rand = (qual_inc_incent)
	replace sim_incent_rand = (high_inc_incent) if income_rand > (`var'/100)*pov_limit_rand
	
	// Estimate updated adoption figures
	est restore reg_th_`var'
	predict yhat_new_`var', xb
	est restore reg_th_`var'_rand
	predict yhat_new_`var'_rand, xb
	
	// Get updated adoption totals for above the line
	summarize yhat_new_`var' if set_flag == 2 & in_ter1==1, meanonly
	scalar adopt_new_a = r(sum)
	
	// Get updated adoption totals for above the line
	summarize yhat_new_`var'_rand if set_flag_rand == 2 & in_ter1==1, meanonly
	scalar adopt_new_a_rand = r(sum)
	
	// Compute change value
    replace changeval = ///
        yhat_old_`var' * actual_incent - yhat_new_`var' * sim_incent ///
        if set_flag == 2 & in_ter1 == 1
	summarize changeval if set_flag == 2 & in_ter1==1, meanonly
	scalar changeval_`var' = r(sum)
	display changeval_`var'
	scalar adopt_new_0 = adopt_old_b
	
	// Compute random change value
    replace changeval_rand = ///
        yhat_old_`var'_rand * actual_incent_rand - yhat_new_`var'_rand * actual_incent_rand ///
        if set_flag_rand == 2 & in_ter1 == 2
	summarize changeval_rand if set_flag_rand == 2 & in_ter1==1, meanonly
	scalar changeval_`var'_rand = r(sum)
	display changeval_`var'_rand
	scalar adopt_new_0_rand = adopt_old_b_rand
	
	// Iterate to convergence 
	forvalues i = 0/8{
		local j=`i'+1
		scalar incent_adder = changeval_`var'/adopt_new_`i'
		replace sim_incent = incent_adder + actual_incent if set_flag==1 & in_ter1==1
		summarize sim_incent if set_flag==1 & in_ter1==1
		scalar incent_`var' = round(r(max),0.01)
		scalar num_`var'= round(r(N),1.0)
		replace l_sim_incent = log(sim_incent)
		est restore reg_th_`var'
		predict yhat_new_`var'_`j', xb
		summarize yhat_new_`var'_`j' if set_flag==1 & in_ter1==1, meanonly
		scalar adopt_new_`j' = r(sum)
	}
	scalar adopt_new_b = adopt_new_9
	
	// Iterate to convergence for random
	forvalues i = 0/8{
		local j=`i'+1
		scalar incent_adder_rand = changeval_`var'_rand/adopt_new_`i'_rand
		replace sim_incent_rand = incent_adder_rand + actual_incent_rand if set_flag_rand==1 & in_ter1==1
		summarize sim_incent_rand if set_flag==1 & in_ter1==1
		scalar incent_`var'_rand = round(r(max),0.01)
		scalar num_`var'_rand = round(r(N),1.0)
		replace l_sim_incent_rand = log(sim_incent_rand)
		est restore reg_th_`var'_rand
		predict yhat_new_`var'_`j'_rand, xb
		summarize yhat_new_`var'_`j'_rand if set_flag_rand==1 & in_ter1==1, meanonly
		scalar adopt_new_`j'_rand = r(sum)
	}
	scalar adopt_new_b_rand = adopt_new_9_rand
	
	// Effect estimation
    scalar change_a = adopt_old_a - adopt_new_a
    scalar change_b = adopt_new_b - adopt_old_b
    gen shift_`var' = change_b - change_a
    display shift_`var'
	
	// Effect random estimation
    scalar change_a_rand = adopt_old_a_rand - adopt_new_a_rand
    scalar change_b_rand = adopt_new_b_rand - adopt_old_b_rand
    gen shift_`var'_rand = change_b_rand - change_a_rand
    display shift_`var'_rand
}

preserve

tempname memhold
tempfile shifts
postfile `memhold' percent Incentive Count Shift Incentive_rand Count_rand Shift_rand using `shifts'

forvalues var = 10(10)300 {
    post `memhold' (`var') (incent_`var') (num_`var') (shift_`var') (incent_`var'_rand) (num_`var'_rand) (shift_`var'_rand)
}

postclose `memhold'
use `shifts', clear

* Format for display
gen str8 Percent = string(percent, "%9.0f") + "%"
replace Shift = round(Shift,1)
replace Shift_rand = round(Shift_rand,1)

* Display in Results window
list Percent Count Incentive Incentive_rand Shift Shift_rand, noobs sep(0)

* Create matrix for export
mkmat Count Incentive Incentive_rand Shift Shift_rand, matrix(shiftmat)

* Label rows as percentages for readability in LaTeX
matrix rownames shiftmat = 10\% 20\% 30\% 40\% 50\% 60\% 70\% 80\% 90\% 100\% 110\% 120\% 130\% 140\% 150\% 160\% 170\% 180\% 190\% 200\% 210\% 220\% 230\% 240\% 250\% 260\% 270\% 280\% 290\% 300\%
matrix colnames shiftmat = Count Incentive Random_Incentive Shift Random_Shift 

* Export to LaTeX
esttab matrix(shiftmat) using "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/tex_tables/shifts.tex", ///
    replace fragment booktabs ///
    nostar nonumber nomtitles noobs

restore

* =============================================================================
* RD Income for Qualification Discussion
* =============================================================================

*----------------------------------------
* 0. Setup
*----------------------------------------
foreach var in inc_cent_a inc_cent_b inc_cent_c inc_cent_d rchld_qual rchld_qual_r bntn_qual bntn_qual_r inc_cent{
	cap drop `var'
}
gen rchld_qual = 1.25*pov_limit
gen rchld_qual_r = 1.25*pov_limit_rand
gen bntn_qual = 2*pov_limit
gen bntn_qual_r = 2*pov_limit_rand

gen inc_cent_a = income - rchld_qual
replace inc_cent_a = income - bntn_qual if in_ter1==1
gen inc_cent_b = income - rchld_qual_r
replace inc_cent_b = income - bntn_qual_r if in_ter1==1
gen inc_cent_c = income_rand - rchld_qual 
replace inc_cent_c = income_rand - bntn_qual if in_ter1==1
gen inc_cent_d = income_rand - rchld_qual_r
replace inc_cent_d = income_rand - bntn_qual_r if in_ter1==1
gen inc_cent = (inc_cent_a + inc_cent_b + inc_cent_c + inc_cent_d)/4

sum bntn_qual
*highest centering point is 79280
sum rchld_qual
*highest centering point is 49550

*----------------------------------------
* 1. Cutoff Benton
*----------------------------------------
local params "in_type==1 & inc_cent<=79280 & in_ter1==1 & year_revised>=2015 & bldg_age>1 & system_qual==1"
    
rdrobust hp_dif inc_cent if `params', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
	eststo inc_rd_Bntn
	scalar bwl         = e(h_l)
	scalar bwr         = e(h_r)
	scalar intercept_l = e(beta_p_l)[1,1]
	scalar intercept_r = e(beta_p_r)[1,1]
cap drop lprobust_*
cap drop left_*
cap drop right_*

di intercept_l intercept_r

* --- Left: treatment ---
lprobust hp_dif inc_cent if `params' & inc_cent<0, ///
	p(1) h(`=bwl') kernel(epa) neval(100) genvars
rename lprobust_eval    left_eval
rename lprobust_gx_us   left_hat
rename lprobust_CI_l_rb left_cil
rename lprobust_CI_r_rb left_ciu
drop lprobust_*

* --- Right: treatment ---
cap drop lprobust_*
lprobust hp_dif inc_cent if `params' & inc_cent>=0, ///
	p(1) h(`=bwr') kernel(epa) neval(100) genvars
rename lprobust_eval    right_eval
rename lprobust_gx_us   right_hat
rename lprobust_CI_l_rb right_cil
rename lprobust_CI_r_rb right_ciu
drop lprobust_*

twoway ///
	(rarea left_cil left_ciu left_eval, fcolor(blue%25) lwidth(none)) ///
	(rarea right_cil right_ciu right_eval, fcolor(red%25) lwidth(none)) ///
	(line left_hat left_eval, lcolor(blue) lwidth(medthick)) ///
	(line right_hat right_eval, lcolor(red) lwidth(medthick)) ///
	(scatteri `=intercept_l' 0 `=intercept_r' 0, ///
		msymbol(circle) mcolor(black) msize(medium)), ///
	xline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
	xtitle("Income Relative to Qualification Cutoff") ytitle("Fraction of Households") ///
	legend(off) graphregion(color(white))
graph export "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Figures/rdd_inc_post_Bntn.png", replace


*----------------------------------------
* 2. Cutoff Richland
*----------------------------------------
local params "in_type==1 & inc_cent<=49550 & in_ter1==0 & bldg_age>1 & system_qual==1"

rdrobust hp_dif inc_cent if `params', p(1) bwselect(msetwo) kernel(epa) masspoints(adjust)
	eststo inc_rd_Rclnd
	scalar bwl = e(h_l)
	scalar bwr = e(h_r)
	scalar intercept_l = e(beta_p_l)[1,1]
	scalar intercept_r = e(beta_p_r)[1,1]
cap drop lprobust_*
cap drop left_*
cap drop right_*

* --- Left: treatment ---
lprobust hp_dif inc_cent if `params' & inc_cent<0, p(1) h(`=bwl') kernel(epa) neval(100) genvars
rename lprobust_eval    left_eval
rename lprobust_gx_us   left_hat
rename lprobust_CI_l_rb left_cil
rename lprobust_CI_r_rb left_ciu
drop lprobust_*

* --- Right: treatment ---
cap drop lprobust_*
lprobust hp_dif inc_cent if `params' & inc_cent>=0, p(1) h(`=bwr') kernel(epa) neval(100) genvars
rename lprobust_eval    right_eval
rename lprobust_gx_us   right_hat
rename lprobust_CI_l_rb right_cil
rename lprobust_CI_r_rb right_ciu
drop lprobust_*

twoway ///
	(rarea left_cil left_ciu left_eval, fcolor(blue%25) lwidth(none)) ///
	(rarea right_cil right_ciu right_eval, fcolor(red%25) lwidth(none)) ///
	(line left_hat left_eval, lcolor(blue) lwidth(medthick)) ///
	(line right_hat right_eval, lcolor(red) lwidth(medthick)) ///
	(scatteri `=intercept_l' 0 `=intercept_r' 0, ///
		msymbol(circle) mcolor(black) msize(medium)), ///
	xline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
	xtitle("Distance") ytitle("Fraction of Households") ///
	legend(off) graphregion(color(white))
graph export "/Users/jake/Documents/PhD/Projects/Masters 2nd Year/1. Current Draft/Figures/rdd_inc_post_Rchld.png", replace

* =============================================================================
* Counterfactual Policy Simulation
* =============================================================================

*----------------------------------------
* 0. Setup 
*----------------------------------------
cap drop l_cf_incent
cap drop l_cf_incent_rand
gen l_cf_incent = log(high_inc_incent)

reghdfe hp cL.l_actual_incent##ib1.inc_type_num##ib3L.htc_num i.in_ter1##new_build l_home_value l_square_feet l_stories l_income l_bldg_age renteroccupied l_erate_alt renovation if in_type==1, absorb(hh_id_num year_revised) vce(cluster hh_id_num)
cap drop hp_hat
predict hp_hat, xb
replace l_actual_incent = l_cf_incent if year_revised>=2015
cap drop hp_cf_1
predict hp_cf_1, xb
replace l_actual_incent = ln(actual_incent)

reghdfe hp cL.l_actual_incent_rand##ib1.inc_type_num_rand##ib3L.htc_num i.in_ter1##new_build l_home_value l_square_feet l_stories l_income_rand l_bldg_age renter_occupied_random l_erate_alt renovation if in_type==1, absorb(hh_id_num year_revised) vce(clust hh_id_num)
cap drop hp_hat_r
predict hp_hat_r, xb
replace l_actual_incent_rand = l_cf_incent if year_revised>=2015
cap drop hp_cf_1_r
predict hp_cf_1_r, xb
replace l_actual_incent_rand = ln(actual_incent_rand)

*----------------------------------------
* 1. Overall 
*----------------------------------------
preserve
collapse (mean) mean_hp=hp (mean) mean_hp_hat=hp_hat (mean) mean_hp_cf_1=hp_cf_1 (mean) mean_hp_hat_r=hp_hat_r (mean) mean_hp_cf_1_r=hp_cf_1_r if in_type == 1, by(in_ter2 year_revised)
twoway ///
		(line mean_hp year_revised if in_ter2 == 1, lcolor(red) lpattern(solid)) /// 
	(line mean_hp_hat year_revised if in_ter2 == 1, lcolor(red) lpattern(dash)) /// 
	(line mean_hp_cf_1 year_revised if in_ter2 == 1, lcolor(red) lpattern(dot)) /// 
	(line mean_hp year_revised if in_ter2 == 0, lcolor(blue) lpattern(solid)) ///
	(line mean_hp_hat year_revised if in_ter2 == 0, lcolor(blue) lpattern(dash)) ///
	(line mean_hp_cf_1 year_revised if in_ter2 == 0, lcolor(blue) lpattern(dot)), ///
    xlabel(2010(1)2021, angle(45)) ylabel(, angle(horizontal)) ///
	ylabel(0(0.1)0.3, angle(horizontal)) /// 
  legend(order(1 "Richland" 2 "Richland Pred" 3 "Richland CF" 4 "Benton" 5 "Benton Pred" 6 "Benton CF") cols(3)) /// 
  xtitle("Year") ytitle("Fraction Using Heat Pumps") 
graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_use_sim.png", replace
restore
** Note: randomization doesn't do enough to be worth including: there's basically no difference. 

*----------------------------------------
* 2. Income-Specific Heat Pump Adoption
*----------------------------------------
foreach inc in low mid high {
	preserve
	collapse (mean) mean_hp=hp (mean) mean_hp_hat=hp_hat (mean) mean_hp_cf_1=hp_cf_1 if in_type == 1 & `inc'_inc_qual==1, by(in_ter2 year_revised)
	twoway ///
		(line mean_hp year_revised if in_ter2 == 1, lcolor(red) lpattern(solid)) /// 
		(line mean_hp_hat year_revised if in_ter2 == 1, lcolor(red) lpattern(dash)) /// 
		(line mean_hp_cf_1 year_revised if in_ter2 == 1, lcolor(red) lpattern(dot)) /// 
		(line mean_hp year_revised if in_ter2 == 0, lcolor(blue) lpattern(solid)) ///
		(line mean_hp_hat year_revised if in_ter2 == 0, lcolor(blue) lpattern(dash)) ///
		(line mean_hp_cf_1 year_revised if in_ter2 == 0, lcolor(blue) lpattern(dot)), ///
		xlabel(2010(1)2021, angle(45)) ylabel(, angle(horizontal)) ///
		ylabel(0(0.1)0.3, angle(horizontal)) /// 
	  legend(order(1 "Richland" 2 "Richland Pred" 3 "Richland CF" 4 "Benton" 5 "Benton Pred" 6 "Benton CF") cols(3)) /// 
	  xtitle("Year") ytitle("Fraction of `=proper("`inc'")' Income Households Using Heat Pumps") 
	graph export "/Users/jake/Documents/PhD/Projects/Masters:2nd Year/cases/Benton vs Richland/figures/heat_pump_use_sim_`inc'.png", replace
	restore
}

* ==============================================================================

* ==============================================================================

* ==============================================================================



* ==============================================================================
* DECOUPLED INCOME GROUP EFFECTS 
* ==============================================================================

*========================================================================
* WITHIN-GROUP TREATMENT EFFECTS
*========================================================================

*------------------------------------------------------------------------
* PART 1.1: TWFE BINARY TREATMENT BY INCOME GROUP 
*------------------------------------------------------------------------
foreach g in 1 2 3 {
    if `g'==1 local glabel "high"
    if `g'==2 local glabel "low"
    if `g'==3 local glabel "mid"

* Ordered ---------------------------------------------------------------
    xtset hh_id_num year_revised

    reghdfe hp_dif i.post##i.in_ter1 ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_nc

    reghdfe hp_dif i.post##i.in_ter1 ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
           l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & L.inc_type_num==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_ac

    reghdfe hp_dif i.post##i.in_ter1 ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_risk_nc

    reghdfe hp_dif i.post##i.in_ter1 ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
           l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & L.inc_type_num==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_risk_ac

* Random ---------------------------------------------------------------
    xtset hh_id_num year_revised

    reghdfe hp_dif i.post##i.in_ter1 ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_nc_r

    reghdfe hp_dif i.post##i.in_ter1 ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
           l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & L.inc_type_num_rand==`g', ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_ac_r

    reghdfe hp_dif i.post##i.in_ter1 ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_risk_nc_r

    reghdfe hp_dif i.post##i.in_ter1 ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
           l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & L.inc_type_num_rand==`g' & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_g`g'_risk_ac_r
}
* Tabulate ---------------------------------------------------------------

* Full sample
esttab t_g2_nc t_g2_nc_r t_g2_ac t_g2_ac_r ///
       t_g3_nc t_g3_nc_r t_g3_ac t_g3_ac_r ///
       t_g1_nc t_g1_nc_r t_g1_ac t_g1_ac_r ///
    , keep(1.post#1.in_ter1) ///
    coeflabels(1.post#1.in_ter1 "Treatment Effect") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    mtitles("NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand") ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    scalars("N Observations") sfmt(%12.0fc) ///
    title("Within-Group Binary Treatment Effects — Full Sample") ///
    nonumbers

* At-risk sample
esttab t_g2_risk_nc t_g2_risk_nc_r t_g2_risk_ac t_g2_risk_ac_r ///
       t_g3_risk_nc t_g3_risk_nc_r t_g3_risk_ac t_g3_risk_ac_r ///
       t_g1_risk_nc t_g1_risk_nc_r t_g1_risk_ac t_g1_risk_ac_r ///
    , keep(1.post#1.in_ter1) ///
    coeflabels(1.post#1.in_ter1 "Treatment Effect") ///
    mgroups("Low Income" "Mid Income" "High Income", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0)) ///
    mtitles("NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand" ///
            "NC" "NC Rand" "AC" "AC Rand") ///
    b(%9.4fc) se(%9.4fc) star(* 0.05 ** 0.01 *** 0.001) ///
    scalars("N Observations") sfmt(%12.0fc) ///
    title("Within-Group Binary Treatment Effects — At Risk Sample") ///
    nonumbers

*------------------------------------------------------------------------
* PART 1.2: TWFE BINARY TREATMENT INITIAL INCOME
*------------------------------------------------------------------------
* Ordered ---------------------------------------------------------------
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_nc_b
	
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
           l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_ac_b
	
* Random ---------------------------------------------------------------
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc_rand ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_nc_b_r
	
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc_rand ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
           l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_ac_b_r

* Risk Ordered ---------------------------------------------------------
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_nc_risk_b
	
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc ///
        L.(i.new_build i.renteroccupied l_home_value l_square_feet ///
           l_stories l_income l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_ac_risk_b
	
* Risk Random ----------------------------------------------------------
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc_rand ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_nc_risk_b_r
	
reghdfe hp_dif i.post##i.in_ter1##i.baseline_inc_rand ///
        L.(i.new_build i.renter_occupied_random l_home_value l_square_feet ///
           l_stories l_income_rand l_bldg_age l_erate_alt) renovation ///
        if in_type==1 & at_risk==1, ///
        absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
    eststo t_ac_risk_b_r

* Tabulate ---------------------------------------------------------------
foreach m in t_nc_b t_ac_b t_nc_risk_b t_ac_risk_b {
    cap estimates restore `m'
    if _rc == 0 {

    lincom 1.post#1.in_ter1 + 1.post#1.in_ter1#2.baseline_inc
    estadd scalar b_low  = r(estimate), replace
    estadd scalar se_low = r(se),       replace
    estadd scalar p_low  = r(p),        replace

    lincom 1.post#1.in_ter1 + 1.post#1.in_ter1#3.baseline_inc
    estadd scalar b_mid  = r(estimate), replace
    estadd scalar se_mid = r(se),       replace
    estadd scalar p_mid  = r(p),        replace

    lincom 1.post#1.in_ter1
    estadd scalar b_high  = r(estimate), replace
    estadd scalar se_high = r(se),       replace
    estadd scalar p_high  = r(p),        replace

    estimates store `m'
}
}

foreach m in t_nc_b_r t_ac_b_r t_nc_risk_b_r t_ac_risk_b_r {
    cap estimates restore `m'
    if _rc == 0 {

    lincom 1.post#1.in_ter1 + 1.post#1.in_ter1#2.baseline_inc_rand
    estadd scalar b_low  = r(estimate), replace
    estadd scalar se_low = r(se),       replace
    estadd scalar p_low  = r(p),        replace

    lincom 1.post#1.in_ter1 + 1.post#1.in_ter1#3.baseline_inc_rand
    estadd scalar b_mid  = r(estimate), replace
    estadd scalar se_mid = r(se),       replace
    estadd scalar p_mid  = r(p),        replace

    lincom 1.post#1.in_ter1
    estadd scalar b_high  = r(estimate), replace
    estadd scalar se_high = r(se),       replace
    estadd scalar p_high  = r(p),        replace

    estimates store `m'
}
}

esttab t_nc_b t_nc_b_r t_ac_b t_ac_b_r ///
       t_nc_risk_b t_nc_risk_b_r t_ac_risk_b t_ac_risk_b_r ///
    , stats(b_low se_low p_low b_mid se_mid p_mid b_high se_high p_high N, ///
            labels("Low Income" "" "" "Mid Income" "" "" "High Income" "" "" "Observations") ///
            fmt(%9.3fc %9.3fc %9.4fc %9.3fc %9.3fc %9.4fc %9.3fc %9.3fc %9.4fc %12.0fc)) ///
    mtitles("NC" "NC Rand" "AC" "AC Rand" ///
            "NC Risk" "NC Risk Rand" "AC Risk" "AC Risk Rand") ///
    noobs nonumbers



*========================================================================
* PART 2.1: TWFE ENERGY PRICE BY INCOME GROUP VALIDATION
*========================================================================


* 1. Check if the sign difference is driven by the control group composition
*    Run within-group but include high-income as additional control
xtset hh_id_num year_revised
reghdfe hp_dif L.l_erate_alt ///
    if in_type==1 & (inc_type_num==2 | inc_type_num==1), ///
    absorb(L_htc_num hh_id_num year_revised) vce(cluster area) nocons
* If sign flips back toward pooled → control group composition is the driver

* 2. Check the raw correlation within each group
bysort inc_type_num: corr hp_dif l_erate_alt

* 3. Check if prices and income are correlated within groups
bysort inc_type_num: corr l_erate_alt l_income

* 4. Plot average adoption by price quartile within each income group
cap drop price_q
cap drop mean_adopt
xtile price_q = l_erate_alt, nq(4)
bysort inc_type_num price_q: egen mean_adopt = mean(hp_dif)
twoway (line mean_adopt price_q if inc_type_num==1) ///
       (line mean_adopt price_q if inc_type_num==2) ///
       (line mean_adopt price_q if inc_type_num==3) ///
       , legend(order(1 "High" 2 "Low" 3 "Mid"))
	   
	   

