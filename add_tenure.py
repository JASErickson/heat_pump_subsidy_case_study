def main(config):

    from urllib.parse import urljoin
    from scipy.stats import gaussian_kde
    from scipy.integrate import simpson
    import pandas as pd
    import numpy as np
    import logging as log
    import function_definition as func

    loggingfile = config.loggingfile

    #Set up logging
    log.basicConfig(filename=loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    joint = pd.read_csv(config.file_3, low_memory=False)
    joint['TRACT_FIPS'] = joint['TRACT_FIPS'].astype(str).str.zfill(6)
    log.info("loading complete")
    log.info(len(joint))

    level = config.level
    sID = config.sID
    county = config.cID
    dataset = config.dataset
    part = config.part_2
    table = config.table_2
    key = config.key

    out_df = pd.DataFrame()

    for y in np.unique(joint['Year'].astype(int)):
        log.info(f"Processing year: {y}, part: {part}")
        result = func.census_extract(level, y, dataset, table, key, sID, part, county)
        if result is None: 
            continue
        df = pd.DataFrame(result)
        df['Total'] = df['Renter_occupied']+df['Owner_occupied']
        log.info(df.columns)
        df['TRACT_FIPS'] = df['Geography'].str[-6:]
        for t in np.unique(joint['TRACT_FIPS']):
            subset = joint[(joint['TRACT_FIPS']==t)&(joint['Year'].astype(int)==y)&(joint['Home_Value'].notna())].copy()
            subset_n = joint[(joint['TRACT_FIPS']==t)&(joint['Year'].astype(int)==y)&(joint['Home_Value'].isna())].copy()
            if subset.empty:
                continue
            else: 
                log.info(f"Processing tract {t} for year {y}, length: {len(subset)}")
                num = len(subset)
                subset['renter occupied'] = 0
                subset['renter_occupied_random'] = 0

                subset_d = df[df['TRACT_FIPS']==t].copy()

                if subset_d.empty:
                    continue
                elif float(subset_d['Total'].iloc[0]) <= 1e-9:
                    continue
                else:  
                    subset_d['renter_pct'] =float(subset_d['Renter_occupied'].iloc[0])/float(subset_d['Total'].iloc[0])
                    log.info(subset_d['renter_pct'].loc[0])
                    rentlen = int(round(subset_d['renter_pct'].iloc[0] * num,0))
                    log.info(f"rentlen:{rentlen}")
                    subset = subset.sort_values(by=['Home_Value'], ascending=True)

                    subset.loc[subset.index[:rentlen], 'renter occupied'] = 1  
                    subset.loc[subset.sample(n=rentlen, random_state=42).index, 'renter_occupied_random'] = 1

                    out_df = pd.concat([out_df,subset],axis=0,ignore_index=True)
                 
                    subset_n['renter occupied']=np.NaN
                    subset_n['renter_occupied_random']=np.NaN
                    out_df = pd.concat([out_df,subset_n],axis=0,ignore_index=True)

    log.info(f'columns in dataframe after adding retner occupancy probabilities: {out_df.columns}')
    log.info(f'dataframe length: {len(out_df)}')

    out_df2 = out_df[['indexa', 'FIPS CODE', 'Property_ID', 'GEOID', 'SITUS STATE', 'SITUS COUNTY',
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
         'income', 'income_rand',
         'renter occupied', 'renter_occupied_random']].copy()

    out_df2.to_csv(config.file_4,compression='gzip')
    log.info("Add Tenure complete")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)