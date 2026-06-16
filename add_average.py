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
    df = pd.read_csv(config.file_6)

# Find average adoption status within radius
    bw = config.bandwidth*1000
    df2=func.compute_neighbor_counts(df, bw,'Parcel_Long_clean', 'Parcel_Lat_clean', 'Year_Revised', 'in_ter1', 'HP')
    log.info(df2[['avg_in_ter1','avg_HP']].describe())

# Save final file
    df2.to_csv(config.file_7,compression='gzip')

# Summarize 
    summary = pd.DataFrame({
        "Column Name": df2.columns,
        "NA Count": df2.isna().sum().values/len(df2),
        "Data Type": df2.dtypes.values
    })
    log.info(summary)

# Memory after summary statement
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after summary statement: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    log.info("Completed")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)
