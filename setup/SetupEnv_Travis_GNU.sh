#!/bin/bash

CWD=`pwd`
export COMPILER_ID=GNU
export FC=mpif90
export CC=mpicc
export CXX=mpicxx
export FFTW_PATH=${HOME}/FFTW
export DECOMP_PATH=${CWD}/dependencies/2decomp_fft
export VTK_IO_PATH=${CWD}/dependencies/Lib_VTK_IO/build
export HDF5_PATH=${HOME}/HDF5
export FFTPACK_PATH=${CWD}/dependencies/fftpack
