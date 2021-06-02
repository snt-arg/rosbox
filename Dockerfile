FROM maven AS xsdcache

# install schema-fetcher
RUN microdnf install git && \
    git clone --depth=1 https://github.com/mfalaize/schema-fetcher.git && \
    cd schema-fetcher && \
    mvn install

# fetch XSD file for package.xml
RUN mkdir -p /opt/xsd/package.xml && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/package.xml http://download.ros.org/schema/package_format2.xsd

# fetch XSD file for roslaunch
RUN mkdir -p /opt/xsd/roslaunch && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/roslaunch https://gist.githubusercontent.com/nalt/dfa2abc9d2e3ae4feb82ca5608090387/raw/roslaunch.xsd

# fetch XSD files for SDF
RUN mkdir -p /opt/xsd/sdf && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/sdf http://sdformat.org/schemas/root.xsd && \
    sed -i 's|http://sdformat.org/schemas/||g' /opt/xsd/sdf/*

# fetch XSD file for URDF
RUN mkdir -p /opt/xsd/urdf && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/urdf https://raw.githubusercontent.com/devrt/urdfdom/xsd-with-xacro/xsd/urdf.xsd

# ----------------------------------------------------------

FROM node:12 AS novnc

RUN git clone https://github.com/noVNC/noVNC.git /novnc

RUN cd /novnc && \
    npm install && \
    ./utils/use_require.js --clean

# ----------------------------------------------------------

FROM osrf/ros:noetic-desktop-full

LABEL maintainer="eduardo.schmidt@uni.lu"

SHELL ["/bin/bash", "-c"]

ENV DISPLAY ":2"
ENV USERNAME rosbox
ENV DEBIAN_FRONTEND noninteractive

# See https://answers.ros.org/question/379190/apt-update-signatures-were-invalid-f42ed6fbab17c654/
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -

# Install apt packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y vim && \
    apt-get install -y git && \
    apt-get install -y nano && \
    apt-get install -y curl && \
    apt-get install -y wget && \
    apt-get install -y sudo && \
    apt-get install -y libtool && \
    apt-get install -y python3 && \
    apt-get install -y virtualenv && \
    apt-get install -y supervisor && \
    apt-get install -y python3-pip && \ 
    apt-get install -y iputils-ping && \ 
    apt-get install -y python3-wstool && \
    apt-get install -y python3-catkin-tools

# Install vcstool
RUN curl -s https://packagecloud.io/install/repositories/dirk-thomas/vcstool/script.deb.sh | sudo bash && \
    apt-get update && \
    apt-get install python3-vcstool

# Install Python modules
RUN pip3 install -U setuptools wheel && \
    pip3 install -U websockify

RUN apt-get update && \
    apt-get install --no-install-recommends -y curl ca-certificates fluxbox eterm xterm xfonts-base xauth x11-xkb-utils xkb-data python3-dbus dbus-x11

# Get TigerVNC
RUN cd / && wget -q -O - https://sourceforge.net/projects/tigervnc/files/stable/1.11.0/tigervnc-1.11.0.x86_64.tar.gz | tar --strip-components 1 -xzvf -

COPY --from=novnc /novnc /opt/novnc
COPY .rosbox/xserver/index.html /opt/novnc

# Python modules
RUN pip3 install --upgrade --ignore-installed --no-cache-dir supervisor supervisor_twiddler argcomplete osrf-pycommon

# Node
RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

# Add rosbox user
RUN useradd --create-home $USERNAME && \
        echo "$USERNAME:$USERNAME" | chpasswd && \
        usermod --shell /bin/bash $USERNAME && \
        usermod -aG sudo $USERNAME && \
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
        chmod 0440 /etc/sudoers.d/$USERNAME && \
        usermod  --uid 1000 $USERNAME && \
        groupmod --gid 1000 $USERNAME

WORKDIR /home/${USERNAME}

ENV SHELL /bin/bash
ENV HOME /home/rosbox

# Autocomplete
RUN git clone --depth=1 https://github.com/Bash-it/bash-it.git /opt/bash-it && \
    /opt/bash-it/install.sh --silent

RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
    /opt/fzf/install --all

RUN git clone --depth 1 https://github.com/b4b4r07/enhancd.git /opt/enhancd && \
    echo "source /opt/enhancd/init.sh" >> ~/.bashrc

# Theia IDE
ENV THEIA_PREFIX /opt/theia

COPY .rosbox/theia/package.json ${THEIA_PREFIX}/package.json

RUN yarn --cwd ${THEIA_PREFIX} --cache-folder ./ycache && rm -rf ${THEIA_PREFIX}/ycache && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn --cwd ${THEIA_PREFIX} theia build && \
    yarn --cwd ${THEIA_PREFIX} theia download:plugins && \
    yarn --cwd ${THEIA_PREFIX} --production && \
    yarn --cwd ${THEIA_PREFIX} autoclean --init && \
    echo *.ts >> ${THEIA_PREFIX}/.yarnclean && \
    echo *.ts.map >> ${THEIA_PREFIX}/.yarnclean && \
    echo *.spec.* >> ${THEIA_PREFIX}/.yarnclean && \
    yarn --cwd ${THEIA_PREFIX} autoclean --force && \
    yarn --cwd ${THEIA_PREFIX} cache clean

COPY .rosbox/theia/plugins/auchenberg.vscode-browser-preview-0.7.1.vsix ${THEIA_PREFIX}/plugins/auchenberg.vscode-browser-preview-0.7.1.vsix
COPY .rosbox/theia/plugins/ms-iot.vscode-ros-0.6.7.vsix ${THEIA_PREFIX}/plugins/ms-iot.vscode-ros-0.6.7.vsix

ADD .rosbox/vscode /home/rosbox/.vscode
ADD .rosbox/vscode /home/rosbox/.theia

# Supervisord
ENV SUPERVISOR_CONFIG_DIR /etc/supervisor
ENV SUPERVISORD_DATA_DIR /var/supervisord

RUN mkdir -p ${SUPERVISOR_CONFIG_DIR}
COPY .rosbox/supervisor/supervisord.conf ${SUPERVISOR_CONFIG_DIR}/supervisord.conf

RUN mkdir -p ${SUPERVISOR_CONFIG_DIR}/conf.d
COPY .rosbox/theia/theia.conf ${SUPERVISOR_CONFIG_DIR}/conf.d/theia.conf

RUN mkdir -p ${SUPERVISOR_CONFIG_DIR}/conf.d
COPY .rosbox/xserver/xserver.conf ${SUPERVISOR_CONFIG_DIR}/conf.d/xserver.conf
COPY .rosbox/xserver/websockify.conf ${SUPERVISOR_CONFIG_DIR}/conf.d/websockify.conf
COPY .rosbox/xserver/xsession.conf ${SUPERVISOR_CONFIG_DIR}/conf.d/xsession.conf
COPY .rosbox/xserver/xvnc.conf ${SUPERVISOR_CONFIG_DIR}/conf.d/xvnc.conf

RUN sudo mkdir -p ${SUPERVISORD_DATA_DIR} && \
    sudo chown rosbox ${SUPERVISORD_DATA_DIR} && \
    sudo chmod 600 ${SUPERVISORD_DATA_DIR}

# Entrypoint
ADD .rosbox/entrypoint.sh /.entrypoint.sh

# XSD Schemas
COPY --from=xsdcache /opt/xsd /opt/xsd

USER ${USERNAME}

# Source ROS installation
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc

RUN rosdep update

VOLUME /tmp/.X11-unix

EXPOSE 3000 8888 9001 9876 8080 11301

ENTRYPOINT [ "/.entrypoint.sh" ]
CMD [ "sudo", "-E", "/usr/local/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]