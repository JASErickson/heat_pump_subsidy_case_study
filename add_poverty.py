def main(config):
    import numpy as np
    import pandas as pd
    import requests
    import logging as log

    #Set up logging
    log.basicConfig(filename=config.loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    pd.set_option('display.max_columns', None)  

    out_df = pd.read_csv(config.file_5)
    
    log.info("starting work")

    pov = pd. DataFrame()
    for num in range(1,9):
        for year in np.unique(out_df['Year'].dropna()):
            if pd.isna(year):
                continue
            if num <2: 
                url = f"https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/{year}/us/1"
            else: 
                url = f"https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/{year}/us/{num}"
            response = requests.get(url)
            response.raise_for_status()  
            data = response.json()
            po = pd.DataFrame([data['data']])
            po = po[['year', 'household_size', 'income']]
            po.rename(columns={'income': 'pov_limit','year':'Year','household_size':'residents'}, inplace=True)
            pov = pd.concat([pov, po], ignore_index=True)

    log.info(f"length of pov dataset: {len(pov)}")

    out_df[['Year','residents','residents_rand']]=out_df[['Year','residents','residents_rand']].astype(float)
    pov[['Year','residents']]=pov[['Year','residents']].astype(float)

    out_df2 = pd.merge(out_df,pov,how='left',on=['Year','residents'])
    out_df3 = pd.merge(out_df2,pov,how='left',left_on=['Year','residents_rand'],right_on=['Year','residents'],suffixes=('', '_rand'))

    out_df3['income'] = pd.to_numeric(out_df3['income'], errors='coerce')
    out_df3['income_rand'] = pd.to_numeric(out_df3['income_rand'], errors='coerce')
    out_df3['pov_limit'] = pd.to_numeric(out_df3['pov_limit'], errors='coerce')
    out_df3['pov_limit_rand'] = pd.to_numeric(out_df3['pov_limit_rand'], errors='coerce')

    log.info(out_df3[['income', 'income_rand', 'pov_limit','pov_limit_rand']].describe())
 
    out_df3['pov_125_a'] = np.where(out_df3['income']<=out_df3['pov_limit']*1.25,1,0)
    out_df3['pov_200_a'] = np.where(out_df3['income']<=out_df3['pov_limit']*2.00,1,0)
    out_df3['low_inc_qual_a'] = out_df3['pov_125_a']
    out_df3['mid_inc_qual_a'] = np.where((out_df3['pov_200_a']==1) & (out_df3['pov_125_a']==0),1,0)
    out_df3['pov_125_b'] = np.where(out_df3['income']<=out_df3['pov_limit_rand']*1.25,1,0)
    out_df3['pov_200_b'] = np.where(out_df3['income']<=out_df3['pov_limit_rand']*2.00,1,0)
    out_df3['low_inc_qual_b'] = out_df3['pov_125_b']
    out_df3['mid_inc_qual_b'] = np.where((out_df3['pov_200_b']==1)&(out_df3['pov_125_b']==0),1,0)
    out_df3['pov_125_c'] = np.where(out_df3['income_rand']<=out_df3['pov_limit']*1.25,1,0)
    out_df3['pov_200_c'] = np.where(out_df3['income_rand']<=out_df3['pov_limit']*2.00,1,0)
    out_df3['low_inc_qual_c'] = out_df3['pov_125_c']
    out_df3['mid_inc_qual_c'] = np.where((out_df3['pov_200_c']==1)&(out_df3['pov_125_c']==0),1,0)
    out_df3['pov_125_d'] = np.where(out_df3['income_rand']<=out_df3['pov_limit_rand']*1.25,1,0)
    out_df3['pov_200_d'] = np.where(out_df3['income_rand']<=out_df3['pov_limit_rand']*2.00,1,0)
    out_df3['low_inc_qual_d'] = out_df3['pov_125_d']
    out_df3['mid_inc_qual_d'] = np.where((out_df3['pov_200_d']==1)&(out_df3['pov_125_d']==0),1,0)
    out_df3['low_inc_qual_max'] = max('low_inc_qual_a','low_inc_qual_b','low_inc_qual_c','low_inc_qual_d')
    out_df3['low_inc_qual_min'] = min('low_inc_qual_a','low_inc_qual_b','low_inc_qual_c','low_inc_qual_d')
    out_df3['mid_inc_qual_max'] = max('mid_inc_qual_a','mid_inc_qual_b','mid_inc_qual_c','mid_inc_qual_d')
    out_df3['mid_inc_qual_min'] = min('mid_inc_qual_a','mid_inc_qual_b','mid_inc_qual_c','mid_inc_qual_d')

    log.info("merging complete")

    out_df3.to_csv(config.file_6,compression='gzip')

    log.info("writing complete")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)