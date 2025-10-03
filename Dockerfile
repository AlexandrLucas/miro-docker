# ---- Dockerfile: MiRo Developer Kit ----

# Start with bare-bones Ubuntu 20.04 image
FROM ubuntu:focal

# ---- Set vars ----
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=miro
ENV USER=${USERNAME}
ENV EDITOR=nano
ENV USER_UID=1000
ENV USER_GID=1000
ENV NO_AT_BRIDGE=1
ENV LANG=en_GB.UTF-8
ENV LC_ALL=en_GB.UTF-8
# Set locales ahead of time
RUN echo "tzdata tzdata/Areas select Europe" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Europe select London" | debconf-set-selections

# ---- System ----
RUN apt-get update && \
apt-get install -y \
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
tree \
dos2unix \
psmisc \
ffmpeg \
&& rm -rf /var/lib/apt/lists/*

# ---- Set locale ----
RUN locale-gen en_GB.UTF-8 && update-locale LANG=en_GB.UTF-8 LC_ALL=en_GB.UTF-8

# Try to install starship, but don't fail if it doesn't work
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes || true
# Only add starship init if starship was successfully installed
RUN if [ -f "/usr/local/bin/starship" ]; then \
    echo 'eval "$(starship init bash)"' >> ~/.bashrc; \
    fi

# ---- ROS 1 & friends ----
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | \
apt-key add -
RUN echo "deb http://packages.ros.org/ros/ubuntu focal main" > \
/etc/apt/sources.list.d/ros.list
RUN apt-get update && \
apt-get install -y \
ros-noetic-desktop-full \
ros-noetic-rqt-* \
ros-noetic-gazebo-* \
ros-noetic-joy \
ros-noetic-teleop-twist-joy \
ros-noetic-teleop-twist-keyboard \
ros-noetic-laser-proc \
ros-noetic-rgbd-launch \
ros-noetic-rosserial-arduino \
ros-noetic-amcl \
ros-noetic-map-server \
ros-noetic-move-base \
ros-noetic-rqt* \
ros-noetic-gmapping \
ros-noetic-navigation \
ros-noetic-gmapping \
python3-rosdep \
python3-rosinstall \
python3-rosinstall-generator \
python3-wstool \
python3-pip \
python3-pydantic \
python3-catkin-tools \
ros-noetic-dynamixel-sdk \
ros-noetic-turtlebot3 \
ros-noetic-turtlebot3-simulations \
libcairo2-dev \
libgirepository1.0-dev \
gir1.2-gtk-3.0 \
&& rm -rf /var/lib/apt/lists/*

# ---- PIP ----
RUN pip3 install apriltag \
dash \
dash-daq \
dash-bootstrap-components \
opencv-contrib-python

# ---- MDK ----
RUN mkdir -p ~/pkgs && cd ~/pkgs/ && wget --no-check-certificate \
'https://docs.google.com/uc?export=download&id=1vNODaenljocVWalM4cOW4Kax-RB4U3nh' \
-O mdk_2-230105.tgz && \
tar -xvzf mdk_2-230105.tgz && \
cd ~/pkgs/mdk-230105/bin/deb64 && \
./install_mdk.sh
RUN wget -O ~/mdk/sim/launch_full.sh \
https://gist.githubusercontent.com/AlexandrLucas\
/703831843f9b46edc2e2032bcd08651f/raw/launch_full.sh && \
chmod +x ~/mdk/sim/launch_full.sh
RUN cd ~/mdk/share/python/miro2/ && \
git clone https://github.com/MiRo-projects/dashboard

# ---- MDK scripts ----
RUN sed -i '/# MDK/d' ~/.bashrc && sed -i '/source ~\/mdk\/setup.bash/d' ~/.bashrc
RUN cd /usr/local/bin/ && \
wget -O /usr/local/bin/robot_switch \https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/robot_switch && \
wget -O /usr/local/bin/robot_mode https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/robot_mode && \
chmod +x *
RUN mkdir -p ~/.tuos && cd ~/.tuos && \
wget -O ~/.tuos/bashrc_miro https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/bashrc_miro && \
wget -O ~/.tuos/bashrc_turtlebot3 https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/bashrc_turtlebot3 && \
wget -O ~/.tuos/bashrc_robot_switch https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/bashrc_robot_switch
RUN wget -O /tmp/.bashrc_extras https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/.bashrc_extras && \
cat /tmp/.bashrc_extras >> ~/.bashrc && rm /tmp/.bashrc_extras
RUN wget -O /tmp/.bash_aliases https://raw.githubusercontent.com/\
tom-howard/tuos_robotics/main/students/.bash_aliases && \
touch ~/.bash_aliases && set -eux; \
while IFS= read -r line; do \
    grep -qxF "$line" ~/.bash_aliases || echo "$line" >> ~/.bash_aliases; \
done < /tmp/.bash_aliases
RUN robot_switch miro && robot_mode sim

# ---- MiRo tutorials ----
RUN cd ~/mdk/catkin_ws/src && git clone https://github.com/AlexandrLucas/COM3528
RUN /bin/bash -c "source ~/mdk/setup.bash && cd ~/mdk/catkin_ws && \
catkin build && catkin clean -y && catkin build && \
cd ~/mdk/catkin_ws/build/miro2_msg && make install"

# ---- Get help ----
RUN yes | unminimize

# ---- Final cleanup ----
RUN unset ROS_HOSTNAME
RUN apt-get update && apt-get upgrade -y
RUN apt-get autoremove -y && apt-get autoclean -y
RUN rm -f ~/.wget-hsts && rm -rf /var/lib/apt/lists/* && rm -rf /tmp
RUN touch ~/.hushlogin

CMD ["bash", "-l"]
