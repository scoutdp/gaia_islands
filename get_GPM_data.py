"""
Code to retrieve NASA GPM precipitation data for given location
and temporal resolution (month, day). Makes use of Google Earth Engine.
This code only downloads the data, to visualize see or build other scripts.
Before running: conda activate ee (see ee pages to build your own env)

Gaia Stucky de Quay, January 2022
"""

#Imports
import ee
import wxee
import os

# Initialize the library.
#ee.Authenticate()
ee.Initialize(project = 'ee-scoutdp')

location =          'Cape_Verde' #location of study
frequency =         'year' #temporal resolution
start_date =        2001
end_date =          2002

# Location of downloaded files
out_dir = ('/Users/scoutpainter/Desktop/gaialab/CapeVerde/NASA_GPM_Data/exported_GPM4_' + location + '_' + frequency + '/')

if not os.path.exists(out_dir):
    os.makedirs(out_dir)

# Parameters related to NASA GPM dataset
dataset = 'NASA/GPM_L3/IMERG_V06' # 30-minute precipitation @ 0.1 deg/px
band = 'precipitationCal' #Band: precipitation (mm/yr) calibrated
scale = 11132 # (meters) According to GPM EE Data Catalog (though also says 0.1 deg?)
crs = 'EPSG:4326'
# Data Source (Info):   https://developers.google.com/earth-engine/
                        #datasets/catalog/NASA_GPM_L3_IMERG_V06


region = ee.Geometry.Polygon(
                            [[
                            [14.30578, -25.82906],
                            [17.56269, -25.82906],
                            [14.30578, -22.18359],
                            [17.56269, -22.18359]
                                #[-25.82906, 14.30578],
                                #[-25.82906, 17.56269],
                                #[-22.18359, 14.30578],
                                #[-22.18359, 17.56269]
                                 ]]
                                )

print("Dowloading...")
# Download from Earth Engine

path = out_dir + "GMP_" + str(start_date) + "_" + str(end_date) +".tif"

collection = ((ee.ImageCollection(dataset).
                filterDate(str(start_date)+"-01-01",str(end_date)+"-01-01") #end=exclusive
                .select(band).filterBounds(region)))


# Convert to a time series
ts = collection.wx.to_time_series()
# Convert to desired frequency (units added up to the time scale, /hr ==> /day)
clim_mean = ts.aggregate_time(frequency=frequency, reducer=ee.Reducer.sum())
# Specify name and location

#Download locally
clim_mean.wx.to_xarray(path=path, crs=crs, scale=scale, region=region)