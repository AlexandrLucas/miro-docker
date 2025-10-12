# ---- Dockerfile: MiRo Developer Kit ----

# ---- Build parameters ----
ARG GIT_BRANCH=master

# ---- Start with bare-bones Ubuntu 20.04 image ----
FROM ubuntu:focal

# ---- Set environment variables ----
ENV DEBIAN_FRONTEND=noninteractive \
    EDITOR='nano -w' \
    NO_AT_BRIDGE=1
# Set USER to anything to avoid breaking mdk/setup.bash
ENV USER=miro

# ---- Set up basics for interactive use ----
RUN apt-get update && apt-get install -y \
    apt-utils \
    locales \
    ca-certificates \
    gnupg2 \
    curl \
    wget \
    git \
    build-essential \
    bash-completion \
    cmake \
    tzdata \
    nano \
    vim \
    tmux \
    xorg-dev \
    eog \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    net-tools \
    iproute2 \
    tree \
    dos2unix \
    psmisc \
    ffmpeg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# ---- Set locale ----
RUN locale-gen en_GB.UTF-8
RUN update-locale LANG=en_GB.UTF-8 LC_ALL=en_GB.UTF-8
ENV LANG=en_GB.UTF-8 \
    LC_ALL=en_GB.UTF-8

# Try to install starship, but don't fail if it doesn't work
RUN curl -sS 'https://starship.rs/install.sh' | sh -s -- --yes || true

# ---- Use bash for what's below ----
SHELL ["/bin/bash", "-c"]

# ---- ROS 1 & friends ----
RUN curl -s 'https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc' | \
    apt-key add - && \
    echo "deb http://packages.ros.org/ros/ubuntu focal main" > \
    /etc/apt/sources.list.d/ros.list
RUN apt-get update && apt-get install -y \
    ros-noetic-desktop-full \
    ros-noetic-rqt* \
    ros-noetic-gazebo* \
    ros-noetic-joy \
    ros-noetic-teleop-twist-joy \
    ros-noetic-teleop-twist-keyboard \
    ros-noetic-turtlebot3* \
    ros-noetic-dynamixel-sdk \
    ros-noetic-laser-proc \
    ros-noetic-rgbd-launch \
    ros-noetic-amcl \
    ros-noetic-map-server \
    ros-noetic-move-base \
    ros-noetic-gmapping \
    ros-noetic-navigation \
    ros-noetic-rosserial-arduino \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-catkin-tools \
    python3-pip \
    python3-wstool \
    python3-pydantic \
    python3-rosdep \
    python3-gi \
    python3-cairo \
    gir1.2-gtk-3.0 \
    libcairo2-dev \
    libgirepository1.0-dev \
    && rm -rf /var/lib/apt/lists/*

# ---- Download and install MDK ----
RUN mkdir -p ~/pkgs && cd ~/pkgs/ && wget --no-check-certificate \
    'https://docs.google.com/uc?export=\
download&id=1vNODaenljocVWalM4cOW4Kax-RB4U3nh' -O mdk_2-230105.tgz && \
    tar -xvzf mdk_2-230105.tgz && \
    cd ~/pkgs/mdk-230105/bin/deb64 && \
    ./install_mdk.sh

# ---- Add extra MDK scripts ----
RUN wget -O ~/mdk/sim/launch_full.sh \
    'https://gist.githubusercontent.com/AlexandrLucas/\
703831843f9b46edc2e2032bcd08651f/raw/launch_full.sh' && \
    chmod +x ~/mdk/sim/launch_full.sh
RUN cd ~/mdk/share/python/miro2/ && git clone --branch miro-docker \
    --single-branch 'https://github.com/MiRo-projects/dashboard.git'
RUN cd ~/mdk/catkin_ws/src && git clone 'https://github.com/AlexandrLucas/COM3528'
COPY --chmod=0755 ./tools/miro /usr/local/bin/miro
COPY --chmod=0755 ./tools/miro-completion /etc/bash_completion.d/miro-completion
RUN echo "192.168.138.101" > "/root/.miro2/config/miro-robot-ip"
RUN echo "sim" > "/root/.miro2/config/miro-mode"

# ---- Update .bashrc ----
RUN sed -i '/# MDK/d; /source ~\/mdk\/setup\.bash/d' ~/.bashrc && \
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' -e 's/\n\{2,\}/\n\n/g' ~/.bashrc
# Add Starship prompt if installed
RUN <<'EOT'
if [ -f "/usr/local/bin/starship" ]; then
  cat <<'EOF' >> ~/.bashrc

# Initialise Starship prompt
eval "$(starship init bash)"
EOF
fi
EOT
RUN cat <<'EOF' > ~/.bashrc_miro
# MDK
if [ ! -f ~/.miro2/config/miro-mode ]; then
    echo "sim" > ~/.miro2/config/miro-mode
elif grep -qi "robot" ~/.miro2/config/miro-mode; then
    export MIRO_ROBOT_IP=$(cat ~/.miro2/config/miro-robot-ip || echo "")
else
    unset MIRO_ROBOT_IP
    export MIRO_LOCAL_IP=127.0.0.1
fi
source ~/mdk/setup.bash
source ~/mdk/catkin_ws/devel/setup.bash
source /etc/bash_completion.d/miro-completion
EOF
RUN cat <<'EOF' >> ~/.bashrc

# MDK
. ~/.bashrc_miro
EOF

# ---- PIP ----
RUN pip install \
    apriltag \
    dash \
    dash-daq \
    dash-bootstrap-components

# ---- Fix for Cairo introspection ----
RUN pip install --force-reinstall pycairo pygobject

# ---- Get help (when in production) ----
RUN if [ "${GIT_BRANCH}" = "master" ]; then \
        yes | unminimize; \
    fi

# ---- Final cleanup ----
RUN source ~/mdk/setup.bash && cd ~/mdk/catkin_ws && \
catkin build && catkin clean -y && catkin build && \
cd ~/mdk/catkin_ws/build/miro2_msg && make install
RUN rm -rf  \
    ~/.wget-hsts \
    /var/lib/apt/lists/* \
    /tmp/* \
    ~/.ssh
RUN touch ~/.hushlogin

WORKDIR /root
CMD ["bash", "-l"]
