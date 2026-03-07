# whereami

## Overview
This repository contains the `detect_machine.sh` Bash script for identifying the current HPC system, CPU, and GPU configuration. It supports a variety of supercomputing environments and shared runners.

## Usage
You can use the script in two ways:

### 1. Source the script
This will export environment variables describing the detected machine:

```bash
source whereami
```

### 2. Run the script directly
This will print information about the detected machine:

```bash
./whereami
```

## Exported Variables
After sourcing, the following environment variables are available:
- `MACHINE_NAME`: Name of the detected machine
- `MACHINE_HOST`: Host organization
- `CPU_VENDOR`: CPU vendor
- `CHIP`: CPU model
- `GPU_VENDOR`: GPU vendor
- `GPU_NAME`: GPU model
- `GPUS_FOUND`: Whether a GPU was detected
- `MACHINE_HOSTNAME`: System hostname

## Supported Machines
See the script for the full list of supported machine names, hosts, CPUs, and GPUs.

## Troubleshooting
- If the script fails, check the error message for unsupported values.
- For custom environments, set `GXTCUSERDEFINED` to override detection.
