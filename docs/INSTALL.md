# Installing MiRo Docker
>Note: Follow the linked instructions provided at each step precisely.

## Quality-of-Life
- Get the [Container Tools](https://code.visualstudio.com/docs/containers/overview) extension in Visual Studio Code.

## Ubuntu
1. Install [Docker Engine](https://docs.docker.com/engine/install/ubuntu/).
2. Hardware acceleration (optional). Depending on your graphics card, install one of the following:
    - [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
    - [AMD Container Toolkit](https://instinct.docs.amd.com/projects/container-toolkit/en/latest/index.html) (not tested).
3. Run the test containers (both docker and GPU, if present) to make sure the system is setup correctly.
4. Follow the *Quick Start* instructions on the main [README](../README.md) page.

## Windows
### Option 1.1: *Docker Desktop on Windows with WSL2 backend* (recommended)
1. Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) (WSL2 further on will be referred to as 'WSL' for simplicity).
2. Get Ubuntu 24.04 for WSL either directly from [Canonical](https://ubuntu.com/desktop/wsl) or from [Windows Store](https://apps.microsoft.com/detail/9NZ3KLHXDJP5?hl=en-us&gl=GB&ocid=pdpshare).
3. Launch Ubuntu via WSL and set up your UNIX account and password. Run update-upgrade: `sudo apt update && sudo apt upgrade`. 
4. Install [Docker Desktop](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers) on Windows.
5. In Docker Desktop settings, enable both "Use the WSL 2 based engine" and WSL integration with your Ubuntu distro.
6. Follow the *Quick Start* instructions on the main [README](../README.md) page.

### Option 1.2: *Windows with WSL2* (without Docker Desktop)
1. Follow the steps 1-3 described in option 1.1
2. Then, follow the steps in the *Ubuntu* section inside your WSL Ubuntu distro.

### GUI Support (X11 or WSLg)
...

### GPU Passthrough
...

### Sound
...

## Mac
