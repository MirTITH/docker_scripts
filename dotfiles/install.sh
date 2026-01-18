#!/bin/bash
set -euo pipefail
script_dir=$(cd $(dirname $0); pwd)

echo sudo cp -a "${script_dir}/home/." ~/
sudo cp -a "${script_dir}/home/." ~/
