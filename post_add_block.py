import pandas as pd
import geopandas as gpd
import logging as log

loggingfile = "U:/Masters/cases/Benton vs Richland/outfiles/log.log" 
infile = "U:/Masters/cases/Benton vs Richland/outfiles/Benton vs Richland_Final_RDD_Dataset.csv"
outfile = "U:/Masters/cases/Benton vs Richland/outfiles/Benton vs Richland_Final_RDD_Dataset_newgeo.csv"
shapefile = "U:/Masters/Downloaded Datafiles/block20/block20.shp"
    # the shape file is downloaded from here: https://ofm.wa.gov/data-research/population-demographics/gis-data/census-geographic-files/
output_crs = 'EPSG:4326'

#Set up logging
log.basicConfig(filename=loggingfile,
                    level=log.INFO,
                    format='%(message)s',
                    filemode='w')

hh = pd.read_csv(infile, low_memory=False)
hh[['Parcel_Lat_clean', 'Parcel_Long_clean']] = hh[['Parcel_Lat_clean', 'Parcel_Long_clean']].astype(float)
h = gpd.GeoDataFrame(hh, geometry=gpd.points_from_xy(hh['Parcel_Long_clean'], hh['Parcel_Lat_clean']), crs=output_crs)
del hh
hh = h
log.info(f"household file loading complete, size: {hh.shape}")

#Pull in boundary file
b = gpd.read_file(shapefile)
b = b.to_crs(output_crs)
log.info(f"shapefile imported: length {len(b)}")
log.info(f"columns of shapefile: {b.columns.values}")
log.info(f"GEOID20: {b['GEOID20'].head(10)}")

#Merge
log.info(f"begining merge")
h_b = gpd.sjoin(h, b[['GEOID20', 'geometry']], how='left', predicate='intersects')
h_b.rename(columns={'GEOID20': 'GEOID_blk'}, inplace=True)
h_b['GEOID_blk']=h_b['GEOID_blk'].astype(str)
h_b = h_b.drop(h_b.filter(regex="^Unnamed").columns, axis=1)
log.info(f"merge complete, length {h_b.shape}")

h_b.to_csv(outfile)

