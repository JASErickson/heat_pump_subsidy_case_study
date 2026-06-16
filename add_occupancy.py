def main(config):
    import numpy as np
    import pandas as pd
    import function_definition as func
    import logging as log

    #Set up logging
    log.basicConfig(filename=config.loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    pd.set_option('display.max_columns', None)

    out_df = pd.read_csv(config.file_4)
    out_df['TRACT_FIPS'] = out_df['TRACT_FIPS'].astype(str).str.zfill(6)

    df_out=pd.DataFrame()

    for y in np.unique(out_df['Year']):
        out_y = out_df[out_df['Year'].astype(int)==y]
        log.info(f"working on year {y}")

        result=func.census_extract(config.level, y, config.dataset, config.table_4, config.key, config.sID, config.part_4, config.cID)
        if result is None:
            log.info("No result from census")
        else:
            d = pd.DataFrame(result)
            d['TRACT_FIPS'] = d['Geography'].str[-6:].str.zfill(6).astype(str)

        if d.columns[0]=='Geography':
            da = pd.concat([d.iloc[:, :16], d.iloc[:, -2:]], axis=1)
        else:
            da = pd.concat([d.iloc[:, :15], d.iloc[:, -3:]], axis=1)

        column_tracker = {}
        columns_to_rename = []

        for col in da.columns:
            # Check if the column name starts with a number
            if col[0].isdigit():
                # Count occurrences
                if col not in column_tracker:
                    column_tracker[col] = 0
                column_tracker[col] += 1

                # For repeated columns, append '_a' to the first occurrence
                if column_tracker[col] == 2:
                    columns_to_rename.append(col + "_a")
                else:
                    columns_to_rename.append(col)
            else:
                # For non-number starting columns, keep them unchanged
                columns_to_rename.append(col)

        # Rename the columns
        da.columns = columns_to_rename

        db = da.sort_values(by=['Geography', 'Geographic_Area_Name', 'TRACT_FIPS'])
        db['year'] = y

        colset = ['1-person_household','2-person_household','3-person_household','4-person_household',
                    '5-person_household','6-person_household','7-or-more_person_household','2-person_household_a',
                    '3-person_household_a','4-person_household_a','5-person_household_a','6-person_household_a',
                    '7-or-more_person_household_a']

        db[colset]=db[colset].apply(pd.to_numeric, errors='coerce')

        # Find total
        db['Total'] = db['Family_households'].astype(float) + db['Nonfamily_households'].astype(float)

        # Get tract-specific counts
        for t in np.unique(out_y['TRACT_FIPS']):
            out_yt = out_y[out_y['TRACT_FIPS']==t].copy()
            log.info(f"length of tract {t} in year {y}: {len(out_yt)}")
            df = db[db['TRACT_FIPS']==t].copy()

            num = len(out_yt[out_yt['Square_Feet'].notna()])
            numall = len(out_yt)

            df['1'] = np.where(df['Total'] == 0, 0, round(num * (df['1-person_household'].astype(float)) / df['Total'], 0))
            df['2'] = np.where(df['Total'] == 0, 0, round(num * (df['2-person_household'].astype(float)+df['2-person_household_a'].astype(float)) / df['Total'], 0))
            df['3'] = np.where(df['Total'] == 0, 0, round(num * (df['3-person_household'].astype(float)+df['3-person_household_a'].astype(float)) / df['Total'], 0))
            df['4'] = np.where(df['Total'] == 0, 0, round(num * (df['4-person_household'].astype(float)+df['4-person_household_a'].astype(float)) / df['Total'], 0))
            df['5'] = np.where(df['Total'] == 0, 0, round(num * (df['5-person_household'].astype(float)+df['5-person_household_a'].astype(float)) / df['Total'], 0))
            df['6'] = np.where(df['Total'] == 0, 0, round(num * (df['6-person_household'].astype(float)+df['6-person_household_a'].astype(float)) / df['Total'], 0))
            df['7'] = np.where(df['Total'] == 0, 0, round(num * (df['7-or-more_person_household'].astype(float)+df['7-or-more_person_household_a'].astype(float)) / df['Total'], 0))

            # Correct for miss-rounding by adding to or subtracting from the most common
            dif = num - df.loc[:, '1':'7'].sum(axis=1)
            max_col = df.loc[:, '1':'7'].idxmax(axis=1)

            # Iterate over each row and update the correct column
            for i in df.index:
                df.loc[i, max_col[i]] += dif[i]  # Add 'dif' to the max column
            df = df.reset_index()  # Reset index back

            # Limit the dataset to necessary only
            dc = df[['TRACT_FIPS','year', '1','2','3','4','5','6','7']]

            # Reformat to be a long-form dataframed
            df_melted = dc.melt(id_vars=['TRACT_FIPS', 'year'], var_name='residents', value_name='count')        # Melt the dataframe to convert wide format to long format
            df_expanded = df_melted.loc[df_melted.index.repeat(df_melted['count'])].drop(columns=['count'])        # Repeat rows based on 'count' values
            df_expanded['residents'] = df_expanded['residents'].astype(int)        # Convert 'residents' column to integer

            # Random sampling
            df_expanded['residents_rand']=df_expanded['residents'].sample(n=num, random_state=42).reset_index(drop=True).values
            df_expanded.sort_values(by=['residents'],ascending=True,inplace=True)
            df_expanded = df_expanded[['residents','residents_rand']]

            nullset = pd.DataFrame({
                'residents': [np.NaN] * (numall-num),
                'residents_rand': [np.NaN] * (numall-num) })

            out_yt = out_yt.sort_values(by=['Rooms','Live_Square_Feet','Square_Feet','Home_Value'],ascending=[True,True,True,True],ignore_index=True)

            # Component check
            log.info(f"rows,columns of the dataframe out_yt: {out_yt.shape}")

            # Merging
            df_merge = pd.concat([df_expanded,nullset],axis=0,ignore_index=True)
            log.info(f"rows,columns of the dataset to add: {df_merge.shape}")

            outdata = pd.concat([out_yt, df_merge], axis=1)
            log.info(f"rows,columns of the dataset with the original data: {outdata.shape}")

            df_out = pd.concat([df_out,outdata],axis=0).reset_index(drop=True)
            log.info(f"df_out: {df_out.shape}")

    log.info(f"starting length: {len(out_df)}")
    log.info(f"ending length: {len(df_out)}")

    log.info(df_out.columns)
    log.info(np.unique(df_out['Year']))

    df_out.to_csv(config.file_5)

    log.info("occupancy addition complete")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)