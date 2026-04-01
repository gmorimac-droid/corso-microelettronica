#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../sim"
make fir_impulse
make decim
make smoke
make spi_reg
make bypass
