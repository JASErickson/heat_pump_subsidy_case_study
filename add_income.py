def main(config):

    import os
    import requests
    import re
    from bs4 import BeautifulSoup
    from requests.adapters import HTTPAdapter
    from requests.packages.urllib3.util.retry import Retry # type: ignore
    from urllib.parse import urljoin
    import zipfile
    from scipy.stats import gaussian_kde
    from scipy.integrate import simpson
    import pandas as pd
    import numpy as np
    import geopandas as gpd
    import requests
    from shapely.geometry import Point
    from pyproj import Transformer
    from shapely import wkt
    import logging as log
    import function_definition as func
    import tracemalloc
    import config_Benton_Richland as config
    import time

    tracemalloc.start()

    #Set up logging
    log.basicConfig(filename=config.loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    j = pd.read_csv(config.file_3)
    log.info(f"length of initial dataframe:{len(j)}")
    j['LUse_clean'] = pd.to_numeric(j['LUse_clean'], errors='coerce')
    joint = j[j['LUse_clean']<200]
    joint['TRACT_FIPS'] = joint['TRACT_FIPS'].astype(str).str.zfill(6)
    log.info(np.unique(joint['TRACT_FIPS']))
    log.info(f"length of residential dataframe: {len(joint)}")

    # Record memory usage at the start
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage with data loaded: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")
    
    log.info("loading complete")
    log.info(len(joint))

    joint2=pd.DataFrame()
    log.info(len(joint))
    for y in np.unique(joint['Year'].astype(int)):
        joint_sub = joint[joint['Year']==y]
        log.info(f"in year {y}, subset of joint is {len(joint_sub)}")
        joint1 = pd.DataFrame()
        result = func.census_extract(config.level, y, config.dataset, config.table_1, config.key, config.sID, config.part_1, config.cID)
        if result is None: 
            log.info("None")
            continue
        df = pd.DataFrame(result)
        df['TRACT_FIPS'] = df['Geography'].str[-6:].str.zfill(6).astype(str)
        log.info(f"in {y} unique FIPS are: {np.unique(df['TRACT_FIPS'])}")
        for tract in np.unique(joint_sub['TRACT_FIPS']):
            joint_sub_t = joint_sub[joint_sub['TRACT_FIPS'] == tract].copy().sort_values(by=['Home_Value'], ascending=True)
            if joint_sub_t.empty:
                continue
            num = len(joint_sub_t[joint_sub_t['Home_Value'].notna()])
            numall = len(joint_sub_t)
            log.info(f"the number of records in {y} for tract {tract} is {num}")
            subset_d = df[df['TRACT_FIPS'] == tract].copy()
            if subset_d.empty:
                out = pd.DataFrame({'income': [np.nan] * numall, 
                                    'income_rand': [np.nan] * numall})
                temp = pd.concat([joint_sub_t.reset_index(drop=True), out.reset_index(drop=True)], axis=1)            
                joint1 = pd.concat([joint1, temp], axis=0, ignore_index=True)
                log.info(f"as of tract {tract} in {y}, joint1 is length {len(joint1)}")
                log.info(f"we added {len(out)} rows")
                continue
            
            else:
                mean_value = subset_d['Mean_income_(dollars)'].iloc[0]
                mean_value = float(mean_value)
                # get the columns that contain data
                percentage_columns = [col for col in subset_d.columns if '$' in col]
                # set columns not to convert
                ex_cols = ['Geography','TRACT_FIPS']
            
                # Convert the column to numeric, setting invalid values to NaN
                for col in subset_d.columns: 
                    if col not in ex_cols:
                        subset_d[col] = pd.to_numeric(subset_d[col], errors='coerce')
                # Combine the values from those columns into a single Series
                percents = subset_d[percentage_columns].stack()
            
                if percents.sum() == 0:
                    probabilities = np.zeros_like(percents)
                else:
                    probabilities = percents / percents.sum()
                # Extract total count
                total_value = float(subset_d['Total'].iloc[0]) if 'Total' in subset_d.columns else 0
                # Develop counts
            
                counts = probabilities * total_value
                # get the brackets for each column
                brackets=func.get_brackets(percentage_columns)
                # get the max bracket value assuming uniformity in the top bracket
                max_val = round(func.find_max(counts,brackets,mean_value),0)
                brackets[-1] = max_val
                buckets = np.array(brackets)
            
                # Generate the random samples and store in a DataFrame
                samples = np.array(func.generate_random_samples(buckets, probabilities, num, numall)).flatten()
                nan_indices = np.isnan(samples)
                non_nan_samples = samples[~nan_indices]
                shuffled_non_nan = np.random.permutation(non_nan_samples)
                samples_rand = np.full(samples.shape, np.nan)
                samples_rand[~nan_indices] = shuffled_non_nan
                samples_rand = np.array(samples_rand.copy()).flatten()
            
                if num>0: 
                    # Create a DataFrame for the samples
                    out = pd.DataFrame({'income': samples,
                                        'income_rand': samples_rand})
                    # Append to the main DataFrame
                    temp = pd.concat([joint_sub_t.reset_index(drop=True), out.reset_index(drop=True)], axis=1)            
                    joint1 = pd.concat([joint1, temp], axis=0, ignore_index=True)
                    log.info(f"as of tract {tract} in {y}, joint1 is length {len(joint1)}")
                    log.info(f"we added {len(out)} rows")

                else:
                    log.info(f"length of joint for tract {tract} and year {y} = 0")
        
                    continue
        joint2 = pd.concat([joint2,joint1],axis=0,ignore_index=True)
        log.info(f"as of year {y}, joint2 is length {len(joint2)}")

    joint2[['income','income_rand']]=joint2[['income','income_rand']].round(2)

    joint2.sort_values(by=['Home_Value'],ascending=True,inplace=True)
    log.info(f'columns in dataset after adding income: {joint2.columns}')
    log.info(f'dataset length: {len(joint2)}')
    
    # Record memory usage at the start
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage at end of income addition: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    joint3 = joint2[['indexa', 'FIPS CODE', 'Property_ID', 'GEOID', 'SITUS STATE', 'SITUS COUNTY',
         'Home_Price', 'Home_Value', 'Year_Built', 'Eff_Yr_Built', 'Stories', 'Rooms', 'Unit_Count', 'Square_Feet', 'Live_Square_Feet',
         'TAXROLL CERTIFICATION DATE', 'Month', 'Year', 'Year_Revised',
         'Parcel_Lat_clean', 'Parcel_Long_clean', 'geometry', 'in_ter1', 'in_ter2', 'in_zone', 'distance',
         'Electric Utility ID', 'Electric Utility Name', 'Electric Year', 'Utility Number', 'Utility Name', 'Thousand Dollars', 'Megawatthours', 'e_Rate',
         'Gas Year', 'g_Rate',
         'LUse', 'LUse_clean', 'LUse_Type_clean', 'LUse_Type', 'LUse_res_all', 'LUse_res_sing_fam', 'LUse_trailer_home', 'LUse_mult_fam',
         'HEATING TYPE CODE', 'HEAT INDC', 'htc2', 'heating_type', 'HP',
         'ac_code', 'ac', 'ac_type',
         'fuel_type', 'ftc2', 'fuel_name',
         'STATEFP', 'COUNTYFP','TRACT_FIPS',
         'income', 'income_rand']].copy()
    
    joint3.to_csv(config.file_3, compression='gzip')

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)