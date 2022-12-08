# ED-SBS: ECCO-Darwin Mackenzie Delta configuration

Find below the instructions to compile and run ED-SBS model

## 1. Build executable
Note: Message Passing Interface (MPI) needs to be installed to lauch parrallel computing.
More informations can be fin at https://darwin3.readthedocs.io/en/latest/getting_started/getting_started.html#building-with-mpi

```
cd darwin3_v67x
mkdir build run
cd build
export MPI_INC_DIR=path_toward_MPI_files
ln -s ../../setup_files/code_darwin/packages.conf ../../code
../tools/genmake2 -mpi -mo '../../setup_files/code_darwin ../../setup_files/code'
make depend
make -j 16
```

## 2. Prepare the simulation
Note: You need to download the forcing files on ECCO data portal (see open reaserch statement)

```
cd ../run
mkdir diags diags/daily diags/budget
-- Link to the executable --
ln -sf ../build/mitgcmuv .
-- Link to atmospheric forcing --
ln -sf ../../Forcing/era_xx .
-- Link to Freswater runnoff --
ln -sf /../../Forcing/river_runoff/Freswater/AGRO_interan .
ln -sf /../../Forcing/river_runoff/Temperature/Tokuda_Mac270modif .
-- Link to Biogeochemical runoff --
ln -sf /../../Forcing/river_runoff/Nutrients/Bertin_etal_21/Interannual/L50_R50/tDOCl .
ln -sf /../../Forcing/river_runoff/Nutrients/Bertin_etal_21/Interannual/L50_R50/tDOCr .
ln -sf /../../Forcing/river_runoff/Nutrients/Tank_etal_12/Interannual/tAlk .
ln -sf /../../Forcing/river_runoff/Nutrients/Tank_etal_12/Interannual/tDIC .
ln -sf /../../Forcing/river_runoff/Nutrients/GNW2_NutCim/tDON .
ln -sf /../../Forcing/river_runoff/Nutrients/GNW2_NutCim/tDOP .
ln -sf /../../Forcing/river_runoff/Nutrients/GNW2_NutCim/tDSi .
-- Link to Initial and Boundary conditions -- 
ln -sf /../../Forcing/run_template/* .
-- Copy setup files -- 
cp ../../setup_files/input/* .
```
## 3. Run the code

```
mpirun -np 8 ./mitgsmuv &
```
