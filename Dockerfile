FROM pardus/yirmibir

# debian based
RUN apt-get update && \
    apt-get install -y make pkg-config gcc g++ python3 libx11-dev libxkbfile-dev libsecret-1-dev

# Install Node.js, Yarn and required dependencies
RUN apt-get update
RUN apt-get -y install curl gnupg ca-certificates
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=18
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get -y install nodejs 
# # remove useless files from the current layer
#     && rm -rf /var/lib/apt/lists/* \
#     && rm -rf /var/lib/apt/lists.d/* \
#     && apt-get autoremove \
#     && apt-get clean \
#     && apt-get autoclean
RUN npm install -g npm@10.1.0
RUN apt-get update
RUN npm install -g yarn
WORKDIR /home/ide
ADD package.json ./package.json

ENV NODE_OPTIONS="--max_old_space_size=4096"
RUN yarn install

# install theia globally
RUN yarn theia build

RUN npx theia download:plugins

RUN yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean

FROM pardus/yirmibir

# Install Node.js, Yarn and required dependencies
RUN apt-get update
RUN apt-get -y install curl gnupg ca-certificates
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=18
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get -y install nodejs 
RUN npm install -g npm@10.1.0
RUN npm install -g yarn
# Env variables
ENV HOME=/root \
    SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/ide/plugins \
    USE_LOCAL_GIT=true

# Whenever possible, install tools using the distro package manager
RUN apt-get update && \
    apt-get install -y git openssh-client bash libsecret-1-0 jq curl socat

RUN mkdir -p /root/workspace && \
    mkdir -p /root/ide && \
    mkdir -p /root/.theia && \
    # Configure a nice terminal
    # format-1 is: root@6f3ecd3d6a6b:~/workspace$ 
    # echo "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /root/.bashrc && \
    # format-1 is: root ~/workspace $ 
    echo "export PS1='\[\033[01;32m\]\u \[\033[01;34m\]\w\[\033[00m\] \$ '" >> /root/.bashrc && \
    # Fake poweroff (stops the container from the inside by sending SIGHUP to PID 1)
    echo "alias poweroff='kill -1 1'" >> /root/.bashrc && \
    # Setup an initial workspace
    echo '{"recentRoots":["file:///root/workspace"]}' > /root/.theia/recentworkspace.json && \
    # Setup settings (file icons theme)
    echo '{"workbench.iconTheme": "vs-seti", "editor.mouseWheelZoom": true, "editor.fontSize": 18, "terminal.integrated.fontSize": 18 }' > /root/.theia/settings.json
    

# Copy files from previous stage 
COPY --from=0 /home/ide /root/ide

# ADD CUSTOM IMPLEMENTATION

ADD motd /root/workspace/motd

# Running environment
EXPOSE 3030
WORKDIR /root/workspace
USER root
CMD [ "node", "/root/ide/src-gen/backend/main.js", "--hostname=0.0.0.0", "--port=3030", "--plugins=local-dir:/root/ide/plugins" ]
