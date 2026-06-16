def main(config):
    import pandas as pd
    import numpy as np
    import logging as log
    import geopandas as gpd
    from scipy.spatial import cKDTree
    import function_definition as func
    import tracemalloc

    #Set up logging
    log.basicConfig(filename=config.loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    pd.set_option('display.max_rows', None)  # Show all rows
    pd.set_option('display.max_columns', None)  # Show all columns
    pd.set_option('display.expand_frame_repr', False)  # Prevent column wrapping

    log.info('Running Stata Setup')

    tracemalloc.start()

    # Record memory usage at the start
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage at start: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

#Open last file
    df = pd.read_csv(config.file_7)
# Get numeric UID back
    df['hh_id'] = df['indexa'].str.split(' ',n=1).str[0]
    df['hh_id_num'] = pd.factorize(df['hh_id'])[0]+1
# get gas access indicator
    df['g_acc'] = df['g_Rate'].notna().astype(int)
# clean up property ID
    df['Property_ID'] = df['Property_ID'].str.replace(r'[A-Za-z]', "", regex=True).str.replace(" ", "").str[:-4]
# turn property id into a number
    df['property_id_num'] = df['Property_ID'].astype(float)
# get building age
    df['bldg_age'] = df['Year_Revised']- df['Year_Built']
# get new_build indicator
    df['new_build'] = (df['bldg_age']<=1).astype(int)
# clean numerical heating type code
    df['heatingtypecode_numeric'], unique_values = pd.factorize(df['HEATING TYPE CODE'])
# Sort by property_id_num and year_revised
    df.sort_values(by=['property_id_num', 'Year_Revised'], inplace=True)
# Create hp_lag column
    df['hp_lag'] = df.groupby('property_id_num')['HP'].shift(1)
    df['prior_htc'] = df.groupby('property_id_num')['HEATING TYPE CODE'].shift(1)
# Create hp_dif column
    df['hp_dif'] = (df['HP'] - df['hp_lag']).fillna(0)
# Create first_year_hp column
    df['first_year_hp'] = df.groupby('property_id_num')['HP'].transform('first')
# Create hp_dif_cumu column
    df['hp_dif_cumu'] = np.where(df['Year_Revised'] > df.groupby('property_id_num')['Year_Revised'].transform('first'), df['HP'] - df['first_year_hp'], np.nan)
# Record memory usage 
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after dif_cumu: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")
# Create hp_2015 column
    df['hp_2015'] = np.where(df['Year_Revised'] == 2014, df['HP'], np.nan)
    df['hp_2015'] = np.where((df['Year_Built'] > 2015) & (df['Year_Revised'] > 2014), df.groupby('property_id_num')['HP'].transform('first'), df['hp_2015'])
    df['hp_2015'] = df.groupby('property_id_num')['hp_2015'].ffill()
# Create hp_dif_cumu_15 column
    df['hp_dif_cumu_15'] = np.where(df['Year_Revised'] >= 2015, df['HP'] - df['hp_2015'], df['hp_dif_cumu'])
# Create income bucket columns
    df['inc_10k'] = np.where(df['income'] < 10000,1,0)
    df['inc_10_15k'] = np.where((df['income'] >= 10000) & (df['income'] < 15000),1,0)
    df['inc_15_25k'] = np.where((df['income'] >= 15000) & (df['income'] < 25000),1,0)
    df['inc_25_35k'] = np.where((df['income'] >= 25000) & (df['income'] < 35000),1,0)
    df['inc_35_50k'] = np.where((df['income'] >= 35000) & (df['income'] < 50000),1,0)
    df['inc_50_75k'] = np.where((df['income'] >= 50000) & (df['income'] < 75000),1,0)
    df['inc_75_100k'] = np.where((df['income'] >= 75000) & (df['income'] < 100000),1,0)
    df['inc_100_150k'] = np.where((df['income'] >= 100000) & (df['income'] < 150000),1,0)
    df['inc_150_200k'] = np.where((df['income'] >= 150000) & (df['income'] < 200000),1,0)
    df['inc_200k'] = np.where(df['income'] >= 200000,1,0)
    df['inc_10k_rand'] = np.where(df['income_rand'] < 10000,1,0)
    df['inc_10_15k_rand'] = np.where((df['income_rand'] >= 10000) & (df['income_rand'] < 15000),1,0)
    df['inc_15_25k_rand'] = np.where((df['income_rand'] >= 15000) & (df['income_rand'] < 25000),1,0)
    df['inc_25_35k_rand'] = np.where((df['income_rand'] >= 25000) & (df['income_rand'] < 35000),1,0)
    df['inc_35_50k_rand'] = np.where((df['income_rand'] >= 35000) & (df['income_rand'] < 50000),1,0)
    df['inc_50_75k_rand'] = np.where((df['income_rand'] >= 50000) & (df['income_rand'] < 75000),1,0)
    df['inc_75_100k_rand'] = np.where((df['income_rand'] >= 75000) & (df['income_rand'] < 100000),1,0)
    df['inc_100_150k_rand'] = np.where((df['income_rand'] >= 100000) & (df['income_rand'] < 150000),1,0)
    df['inc_150_200k_rand'] = np.where((df['income_rand'] >= 150000) & (df['income_rand'] < 200000),1,0)
    df['inc_200k_rand'] = np.where(df['income_rand'] >= 200000,1,0)
 # Record memory usage a
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after income brackets: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")
# Add the HTC elec type for prior year's heating type
    htc = pd.read_csv(config.htc_elec)
    htc = htc.dropna(how='all').reset_index(drop=True)
    ftc = pd.read_csv(config.ftc_elec)
    ftc = ftc.dropna(how='all').reset_index(drop=True)

# Record memory before merge
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage before merge htc and ftc: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")
    df2 = df.merge(htc[['htc','htc_pass','Group','htc_pass_alt','Group_alt']],left_on='HEATING TYPE CODE',right_on='htc',how="left")
    df = df2.merge(ftc[['ftc','ftc_pass']],left_on='fuel_type',right_on='ftc',how="left")
    df['system_qual'] = df['ftc_pass'].fillna(1)*df['htc_pass'].fillna(0)
    df['system_qual_alt'] = df['ftc_pass'].fillna(1)*df['htc_pass_alt'].fillna(0)

# Record program age
    df['prog_age'] = np.where(df['in_ter1']==1,df['Year']-2015,df['Year']-1981)
    df['prog_novelty'] = np.where(df['prog_age']<0,np.NaN,df['prog_age'])
# Generate pre/post indicators
    df['post'] = np.where(df['Year_Revised']>=2015,1,0)
# Generate TWFE interaction
    df['indicator'] = df['post']*df['in_ter1']

# Add the income qualification 
    df['low_inc_qual'] = df['pov_125_a']
    df['mid_inc_qual'] = df['pov_200_a'] - df['pov_125_a']
    df['high_inc_qual'] = np.where(df['pov_200_a'].isnull(),np.nan,1-df['pov_200_a'])
    df['inc_qual'] = np.where(df['in_ter1']==1,df['pov_200_a'],df['pov_125_a'])
    df['qual_type'] = np.where(df['low_inc_qual']==1,'low',
                               np.where(df['mid_inc_qual']==1,'mid', 'high'))
    df['low_inc_qual_rand'] = df['pov_125_d']
    df['mid_inc_qual_rand'] = df['pov_200_d'] - df['pov_125_d']
    df['high_inc_qual_rand'] = np.where(df['pov_200_d'].isnull(),np.nan,1-df['pov_200_d'])
    df['inc_qual_rand'] = np.where(df['in_ter1']==1,df['pov_200_d'],df['pov_125_d'])
    df['qual_type_rand'] = np.where(df['low_inc_qual_rand']==1,'low',
                               np.where(df['mid_inc_qual_rand']==1,'mid','high'))

# Add 'what would you be eligible for if you qualified'
    df['high_inc_incent'] = np.where(df['Group']=='central',
                                config.standard_elec_central,
                            np.where(df['Group']=='ductless',
                                config.standard_elec_ductless,
                            np.where(df['Group']=='HP',
                                config.standard_hp_variable,0))
                                )*df['system_qual']
    df['qual_inc_incent'] = np.where(df['in_ter1']==1,
                                df['system_qual']*
                            np.where(df['Group']=='central',
                                config.benton_lmi,
                            np.where(df['Group']=='ductless',
                                config.benton_lmi,
                            np.where(df['Group']=='HP',
                                config.benton_lmi,0))),
                                df['system_qual']*
                            np.where(df['Group']=='central',
                                config.richland_lmi_central,
                            np.where(df['Group']=='ductless',
                                config.richland_lmi_ductless,
                            np.where(df['Group']=='HP',
                                config.richland_lmi_central,0))))
    df['qualified_incent'] = np.where((df['low_inc_qual']==1)&(df['in_ter1']==0), 
                                df['qual_inc_incent'], 
                            np.where((df['pov_200_a']==1)&(df['in_ter1']==1),
                                df['qual_inc_incent'],
                                df['high_inc_incent']))
    df['qualified_incent_rand'] = np.where((df['low_inc_qual_rand']==1)&(df['in_ter1']==0), 
                                df['qual_inc_incent'], 
                            np.where((df['pov_200_d']==1)&(df['in_ter1']==1),
                                df['qual_inc_incent'],
                                df['high_inc_incent']))
    df['actual_incent'] = np.where(df['Year']>=2015,df['qualified_incent'],
                                   np.where(df['in_ter1']==0,df['qualified_incent'],
                                    df['high_inc_incent']))
    df['actual_incent_rand'] = np.where(df['Year']>=2015,df['qualified_incent_rand'],
                                   np.where(df['in_ter1']==0,df['qualified_incent_rand'],
                                    df['high_inc_incent']))
    
    df['high_inc_incent_alt'] = np.where(df['Group_alt']=='central',
                                config.standard_elec_central,
                            np.where(df['Group_alt']=='ductless',
                                config.standard_elec_ductless,
                            np.where(df['Group_alt']=='HP',
                                config.standard_hp_variable,0))
                                )*df['system_qual']
    df['qual_inc_incent_alt'] = np.where(df['in_ter1']==1,
                                df['system_qual']*
                            np.where(df['Group_alt']=='central',
                                config.benton_lmi,
                            np.where(df['Group_alt']=='ductless',
                                config.benton_lmi,
                            np.where(df['Group_alt']=='HP',
                                config.benton_lmi,0))),
                                df['system_qual']*
                            np.where(df['Group_alt']=='central',
                                config.richland_lmi_central,
                            np.where(df['Group_alt']=='ductless',
                                config.richland_lmi_ductless,
                            np.where(df['Group_alt']=='HP',
                                config.richland_lmi_central,0))))
    df['qualified_incent_alt'] = np.where((df['low_inc_qual']==1)&(df['in_ter1']==0), 
                                df['qual_inc_incent_alt'], 
                            np.where((df['pov_200_a']==1)&(df['in_ter1']==1),
                                df['qual_inc_incent_alt'],
                                df['high_inc_incent_alt']))
    df['qualified_incent_rand_alt'] = np.where((df['low_inc_qual_rand']==1)&(df['in_ter1']==0), 
                                df['qual_inc_incent_alt'], 
                            np.where((df['pov_200_d']==1)&(df['in_ter1']==1),
                                df['qual_inc_incent_alt'],
                                df['high_inc_incent_alt']))
    df['actual_incent_alt'] = np.where(df['Year']>=2015,df['qualified_incent_alt'],
                                   np.where(df['in_ter1']==0,df['qualified_incent_alt'],
                                    df['high_inc_incent_alt']))
    df['actual_incent_rand_alt'] = np.where(df['Year']>=2015,df['qualified_incent_rand_alt'],
                                   np.where(df['in_ter1']==0,df['qualified_incent_rand_alt'],
                                    df['high_inc_incent_alt']))
    
# Add memory after income incentives
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after income incentives: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

# Save final file
    df.to_csv(config.final_file,compression='gzip')

# Summarize 
    summary = pd.DataFrame({
        "Column Name": df.columns,
        "NA Count": df.isna().sum().values/len(df),
        "Data Type": df.dtypes.values
    })
    log.info(summary)

# Mery after summary statement
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after summary statement: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    log.info("Completed")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)
