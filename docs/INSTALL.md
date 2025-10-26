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
### Option 1.1 (recommended): *Docker Desktop on Windows with WSL2 backend*
The following simplified diagram represents the intended layered environment:

flowchart LR
    A["Host OS <br> (Windows 10 or 11)"] --> D["Docker Desktop <br> (Docker-WSL integration)"]
    B --> C["MiRo Docker image <br> (Ubuntu 20.04)"]
    A --> B["WSL distro <br> (e.g. Ubuntu 24.04)"]
    D --> B
    D --> C

#### Host OS
1. Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) (the terms WSL2 and WSL are used interchangeably).
2. Install a Linux distro inside WSL. Ubuntu 24.04 is recommended, which you can get in a number of ways:
    - By running `wsl --install -d Ubuntu-24.04`.
    - Downloading from [Windows Store](https://apps.microsoft.com/detail/9NZ3KLHXDJP5?hl=en-us&gl=GB&ocid=pdpshare).
    - Or downloading directly from [Canonical](https://ubuntu.com/desktop/wsl).
3. Launch your chosen distro via WSL and set up your UNIX account and password.
4. Install [Docker Desktop](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers) on your host OS.
5. In Docker Desktop settings, enable both "Use the WSL 2 based engine" and WSL integration with your WSL distro.
#### WSL distro
Inside the running WSL distro, do the following:
1. `sudo apt update && sudo apt upgrade && sudo apt autoremove`.
2. `sudo apt install mesa-utils x11-xserver-utils`
3. Append `export LIBGL_ALWAYS_SOFTWARE="1"` to your `~/.bashrc` file. This will software rendering for GUI apps.
4. Unless you want to look into hardware rendering, you can now follow the *Quick Start* instructions on the main [README](../README.md) page.

#### Hardware acceleration for GUI apps
...

### Sound
...


### Option 1.2: *Windows with WSL2* (without Docker Desktop)
1. Follow the steps 1-3 described in option 1.1 under *Host OS*
2. Then, follow the steps in the *Ubuntu* section inside your WSL Ubuntu distro.
## Mac


