#DEM=srtm_local_filled
#DEM=ASTGTM2_S12W075_dem
DEM=DEM
accumulation=accumulation_tmp
streams=streams_tmp
streams_onebasin=${streams}_onebasin
basins=basins_tmp
basins_onebasin=${basins}_onebasin
segments=segments_tmp
reaches=reaches_tmp
threshold=1000000 #m2 - drainage area
#grid_res=150 #m2 - for MODFLOW
grid_res=150 #m2 - for MODFLOW
grid=grid_tmp
slope=slope_tmp
aspect=aspect_tmp
HRUs=HRUs_tmp
gravity_reservoirs=gravity_reservoirs_tmp
basin_mask=basin_mask_tmp
basin_mask_out=basin_mask
pour_point=pp_tmp

# Set region
g.region -p rast=$DEM

# Build flow accumulation with only fully on-map flow
r.cell.area output=cellArea_meters2 units=m2 --o
r.watershed elevation=$DEM flow=cellArea_meters2 accumulation=$accumulation -s --o
r.mapcalc "${accumulation}_pos = $accumulation * ($accumulation > 0)" --o
r.null map=${accumulation}_pos setnull=0
r.mapcalc "${DEM}_pos_accum = $DEM * (isnull(${accumulation}_pos) == 0)" --o
r.null map=${DEM}_pos_accum setnull=0
r.mapcalc "${accumulation}_pos = ${accumulation}_pos * ($DEM > 0)" --o
r.null map=${accumulation}_pos setnull=0
# Repeat is sometimes needed
r.mapcalc "${DEM}_pos_accum = $DEM * (isnull(${accumulation}_pos) == 0)" --o
r.null map=${DEM}_pos_accum setnull=0
r.mapcalc "${accumulation}_pos = ${accumulation}_pos * ($DEM > 0)" --o
r.null map=${accumulation}_pos setnull=0

# Build streams and sub-basins
r.stream.extract elevation=${DEM}_pos_accum accumulation=${accumulation}_pos stream_raster=$streams stream_vector=$streams threshold=$threshold direction=draindir_tmp d8cut=0 --o
r.stream.basins direction=draindir_tmp stream_rast=$streams basins=$basins --o
r.to.vect input=$basins output=$basins type=area -v --o

# Build stream network
v.stream.network map=$streams

# Restrict to a single basin
basin_outlet_cat=2485 #2762 #144 # You must find and define this after building the stream network
v.stream.inbasin input_streams=$streams input_basins=$basins output_streams=$streams_onebasin output_basin=$basins_onebasin cat=$basin_outlet_cat output_pour_point=$pour_point --o

# GSFLOW segments: sections of stream that define subbasins
v.gsflow.segments input=$streams_onebasin output=$segments --o

# MODFLOW grid & basin mask (1s where basin exists and 0 where it doesn't)
v.gsflow.grid basin=$basins_onebasin dx=$grid_res dy=$grid_res output=$grid mask_output=$basin_mask pour_point=$pour_point --o

# GSFLOW reaches: intersection of segments and grid
v.gsflow.reaches segment_input=$segments grid_input=$grid elevation=$DEM output=$reaches --o

# GSFLOW HRU parameters
r.slope.aspect elevation=$DEM slope=$slope aspect=$aspect format=percent zscale=0.01 --o
v.gsflow.hruparams input=$basins_onebasin elevation=$DEM output=$HRUs slope=$slope aspect=$aspect --o

# GSFLOW gravity reservoirs
v.gsflow.gravres hru_input=$HRUs grid_input=$grid output=$gravity_reservoirs --o

# Export DEM with MODFLOW resolution
# Also export basin mask -- 1s where basin exists and 0 where it doesn't
g.region rast=$basin_mask res=$grid_res
r.out.ascii input=$DEM output=$DEM.asc null_value=0 --o
r.out.ascii input=$basin_mask output=$basin_mask_out.asc null_value=0 --o
g.region rast=$DEM
g.region vect=$basins_onebasin

# Export tables and discharge point
v.gsflow.export reaches_input=$reaches segments_input=$segments gravres_input=$gravity_reservoirs hru_input=$HRUs pour_point_input=$pour_point reaches_output=$reaches segments_output=$segments gravres_output=$gravity_reservoirs hru_output=$HRUs pour_point_output=$pour_point --o

g.region vect=$basin_vect_name res=$grid_res
r.out.ascii in=$DEM out=$DEM.out
