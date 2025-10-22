# Prerequisites

## Quality-of-Life
1. Get the [Container Tools](https://code.visualstudio.com/docs/containers/overview) extension in Visual Studio Code.

## Ubuntu
1. Install [Docker Engine](https://docs.docker.com/engine/install/ubuntu/).
2. Hardware acceleration. If you have NVIDIA GPU, install 
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). Apparently, there is a similar toolkit for AMD GPUs: 
[AMD Container Toolkit](https://instinct.docs.amd.com/projects/container-toolkit/en/latest/index.html) (not tested).

3. Run the test containers (both docker and GPU, if present) to make sure the system is setup correctly.
4. Follow the Quick Start instructions on the main [README](../README.md) page.

## Windows
There are two common approaches:

* **WSL2 approach** (recommended): Run Docker inside a WSL2 Linux distribution (e.g. Ubuntu 24.04).
This uses the Windows Subsystem for Linux, potentially with WSLg for GUI and audio.

* **Docker Desktop approach**: Run Docker natively via Docker Desktop for Windows 
(Hyper-V or WSL2 backend), using Windows paths and services.

### Windows 10 with WSL2
