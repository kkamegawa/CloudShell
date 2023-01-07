# base.Dockerfile contains components which are large and change less frequently. 
# tools.Dockerfile contains the smaller, more frequently-updated components. 

# Within Azure, the image layers
# built from this file are cached in a number of locations to speed up container startup time. A manual
# step needs to be performed to refresh these locations when the image changes. For this reason, we explicitly
# split the base and the tools docker files into separate files and base the tools file from a version
# of the base docker file stored in a container registry. This avoids accidentally introducing a change in
# the base image

# CBL-Mariner is an internal Linux distribution for Microsoft’s cloud infrastructure and edge products and services.
# CBL-Mariner is designed to provide a consistent platform for these devices and services and will enhance Microsoft’s
# ability to stay current on Linux updates.
# https://github.com/microsoft/CBL-Mariner
FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

SHELL ["/bin/bash","-c"]

RUN tdnf update -y --refresh

COPY linux/tdnfinstall.sh .

RUN bash ./tdnfinstall.sh \
  mariner-repos-extended

RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > postgresql.gpg \
  && mv postgresql.gpg /etc/apt/trusted.gpg.d/postgresql.gpg \
  && sh -c 'echo "deb [arch=amd64] https://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/postgresql.list'

# BEGIN: provision nodejs

# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  74F12602B6F1C4E913FAA37AD3A89613643B6201 \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  108F52B48DB57BB0CC439B2997B01419BD92F80A \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
  gpg --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
  gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
  gpg --keyserver keyserver.pgp.com --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_VERSION 16.15.0
ENV NODE_ENV production
ENV NODE_OPTIONS=--tls-cipher-list='ECDHE-RSA-AES128-GCM-SHA256:!RC4'

RUN bash ./tdnfinstall.sh \
  curl \
  xz \
  git \
  gpgme \
  gnupg2 \
  autoconf \
  ansible \
  bash-completion \
  build-essential \
  binutils \
  ca-certificates \
  ca-certificates-legacy \
  chkconfig \
  cifs-utils \
  curl \
  bind-utils \
  dos2unix \
  dotnet-runtime-6.0 \
  dotnet-sdk-6.0 \
  e2fsprogs \
  emacs \
  gawk \
  glibc-lang \
  glibc-i18n \
  grep \
  gzip \
  initscripts \
  iptables \
  iputils \
  msopenjdk-11 \
  jq \
  less \
  libffi \
  libffi-devel \
  libtool \
  lz4 \
  openssl \
  openssl-libs \
  openssl-devel \
  man-db \
  moby-cli \
  moby-engine \
  msodbcsql17 \
  mssql-tools \
  mysql \
  nano \
  net-tools \
  parallel \
  patch \
  pkg-config \
  postgresql-libs \
  postgresql \
  powershell \
  python3 \
  python3-pip \
  python3-virtualenv \
  python3-libs \
  python3-devel \
  puppet \
  rpm \
  rsync \
  sed \
  sudo \
  tar \
  tmux \
  unixODBC \
  unzip \
  util-linux \
  vim \
  wget \
  which \
  zip \
  zsh \
  maven \
  jx \
  cf-cli \
  golang \
  ruby \
  rubygems \
  packer \
  dcos-cli \
  ripgrep \
  helm \
  azcopy \
  apparmor-parser \
  apparmor-utils \
  cronie \
  ebtables-legacy \
  fakeroot \
  file \
  lsb-release \
  ncompress \
  pigz \
  psmisc \
  procps \
  shared-mime-info \
  sysstat \
  xauth \
  screen \
  postgresql-devel \
  terraform \
  gh

# Install azure-functions-core-tools
RUN wget -nv -O Azure.Functions.Cli.linux-x64.4.0.3971.zip https://github.com/Azure/azure-functions-core-tools/releases/download/4.0.3971/Azure.Functions.Cli.linux-x64.4.0.3971.zip \
  && unzip -d azure-functions-cli Azure.Functions.Cli.linux-x64.4.0.3971.zip \
  && chmod +x azure-functions-cli/func \
  && chmod +x azure-functions-cli/gozip \
  && mv azure-functions-cli /opt \
  && ln -sf /opt/azure-functions-cli/func /usr/bin/func \
  && ln -sf /opt/azure-functions-cli/gozip /usr/bin/gozip \
  && rm -r Azure.Functions.Cli.linux-x64.4.0.3971.zip


# Setup locale to en_US.utf8
RUN echo en_US UTF-8 >> /etc/locale.conf && locale-gen.sh
ENV LANG="en_US.utf8"

# Update pip and Install Service Fabric CLI
# Install mssql-scripter
RUN pip3 install --upgrade sfctl \
  && pip3 install --upgrade mssql-scripter

# Install Blobxfer and Batch-Shipyard in isolated virtualenvs
COPY ./linux/blobxfer /usr/local/bin
RUN chmod 755 /usr/local/bin/blobxfer \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 blobxfer \
  && /bin/bash -c "source blobxfer/bin/activate && pip3 install blobxfer && deactivate"

# Mariner distro required patch
# mariner-batch-shipyard.patch
# python3 is default in CBL-Mariner
# Some hacks to install.sh install-tweaked.sh
RUN curl -fSsL `curl -fSsL https://api.github.com/repos/Azure/batch-shipyard/releases/latest | grep tarball_url | cut -d'"' -f4` | tar -zxvpf - \
  && mkdir /opt/batch-shipyard \
  && mv Azure-batch-shipyard-*/* /opt/batch-shipyard \
  && rm -r Azure-batch-shipyard-* \
  && cd /opt/batch-shipyard \
  && sed 's/rhel/mariner/' < install.sh > install-tweaked.sh \
  && sed -i '/$PYTHON == /s/".*"/"python3"/' install-tweaked.sh \
  && sed -i 's/rsync $PYTHON_PKGS/rsync python3-devel/' install-tweaked.sh \
  && chmod +x ./install-tweaked.sh \
  && ./install-tweaked.sh -c \
  && /bin/bash -c "source cloudshell/bin/activate && python3 -m compileall -f /opt/batch-shipyard/shipyard.py /opt/batch-shipyard/convoy && deactivate" \
  && ln -sf /opt/batch-shipyard/shipyard /usr/local/bin/shipyard

# # BEGIN: Install Ansible in isolated Virtual Environment
COPY ./linux/ansible/ansible*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/ansible* \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 install ansible && pip3 install pywinrm\>\=0\.2\.2 && deactivate" \
  && ansible-galaxy collection install azure.azcollection -p /usr/share/ansible/collections

# Install latest version of Istio
ENV ISTIO_ROOT /usr/local/istio-latest
RUN curl -sSL https://git.io/getLatestIstio | sh - \
  && mv $PWD/istio* $ISTIO_ROOT \
  && chmod -R 755 $ISTIO_ROOT
ENV PATH $PATH:$ISTIO_ROOT/bin

# Install latest version of Linkerd
RUN export INSTALLROOT=/usr/local/linkerd \
  && mkdir -p $INSTALLROOT \
  && curl -sSL https://run.linkerd.io/install | sh - 
ENV PATH $PATH:/usr/local/linkerd/bin

# Install Puppet-Bolt
#RUN wget -nv -O puppet-tools.deb https://apt.puppet.com/puppet-tools-release-buster.deb \
#  && dpkg -i puppet-tools.deb \
#  && apt-get update \
#  && bash ./aptinstall.sh puppet-bolt \
#  && rm -f puppet-tools.deb

# install go
RUN wget -nv -O go.tar.gz https://go.dev/dl/go1.18.2.linux-amd64.tar.gz \
  && echo e54bec97a1a5d230fc2f9ad0880fcbabb5888f30ed9666eca4a91c5a32e86cbc go.tar.gz | sha256sum -c \
  && tar -xf go.tar.gz \
  && mv go /usr/local \
  && rm -f go.tar.gz

ENV GOROOT="/usr/local/go"
ENV PATH="$PATH:$GOROOT/bin:/opt/mssql-tools/bin"


RUN gem install bundler --version 1.16.4 --force \
  && gem install rake --version 12.3.0 --no-document --force \
  && gem install colorize --version 0.8.1 --no-document --force \
  && gem install rspec --version 3.7.0 --no-document --force

ENV GEM_HOME=~/bundle
ENV BUNDLE_PATH=~/bundle
ENV PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Install Chef Workstation
RUN wget -nv -O chef-workstation_amd64.deb https://packages.chef.io/files/stable/chef-workstation/21.8.555/debian/10/chef-workstation_21.8.555-1_amd64.deb \
  && echo 6479afe6aca5041450e579a2147667e1e60d87970531addbc2d7c218c6d864b7 chef-workstation_amd64.deb | sha256sum -c \
  && dpkg -i chef-workstation_amd64.deb \
  && rm -f chef-workstation_amd64.deb

# Install ripgrep
RUN curl -sSLO https://github.com/BurntSushi/ripgrep/releases/download/12.1.1/ripgrep_12.1.1_amd64.deb \
  && echo 18ef498312073da55d2f2f65c6a906085c68368a23c9a45a87fcb8539be96608 ripgrep_12.1.1_amd64.deb | sha256sum -c \
  && dpkg -i ripgrep_12.1.1_amd64.deb \
  && rm -f ripgrep_12.1.1_amd64.deb

# Install docker-machine
RUN curl -sSL https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` > /tmp/docker-machine \
  && echo a7f7cbb842752b12123c5a5447d8039bf8dccf62ec2328853583e68eb4ffb097 /tmp/docker-machine | sha256sum -c \
  && chmod +x /tmp/docker-machine \
  && mv /tmp/docker-machine /usr/local/bin/docker-machine

# Copy and run the Helm install script, which fetches the latest release of Helm.
COPY ./linux/helmInstall.sh .
RUN bash ./helmInstall.sh && rm -f ./helmInstall.sh

# Copy and run the Draft install script, which fetches the latest release of Draft with
# optimizations for running inside cloud shell.
# COPY ./linux/draftInstall.sh .
# RUN bash ./draftInstall.sh && rm -f ./draftInstall.sh

# Install Yeoman Generator and predefined templates
RUN npm install -g yo \
  && npm install -g generator-az-terra-module


# Copy and run script to Install powershell modules
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && rm -rf ./powershell