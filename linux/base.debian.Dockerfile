FROM debian:12

SHELL ["/bin/bash","-c"]

RUN apt-get update && apt-get install -y curl wget

RUN apt-get install wget lsb-release -y
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb

# msopenjdk 21をダウンロードしてインストール
RUN wget https://aka.ms/download-jdk/microsoft-jdk-21.0.1-linux-x64.tar.gz
RUN tar xvf microsoft-jdk-21.0.1-linux-x64.tar.gz
RUN mv msopenjdk-21 /usr/lib/jvm/
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/msopenjdk-21/bin/java 1
RUN update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/msopenjdk-21/bin/javac 1

# 環境変数を設定
ENV JAVA_HOME /usr/lib/jvm/msopenjdk-21

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_ENV production
ENV NODE_OPTIONS=--tls-cipher-list='ECDHE-RSA-AES128-GCM-SHA256:!RC4'

RUN apt-get install -y \ 
  gnupg2 \
  autoconf \
  ansible \
  bash-completion \
  build-essential \
  binutils \
  ca-certificates \
  cifs-utils \
  bind9-utils \
  dos2unix \
  e2fsprogs \
  emacs \
  gawk \
  git \
  grep \
  gzip \
  initscripts \
  iptables \
  jq \
  less \
  libtool \
  lz4 \
  openssl \
  man-db \
  nano \
  net-tools \
  parallel \
  patch \
  pkg-config \
  postgresql \
  powershell \
  python3 \
  python3-pip \
  python3-virtualenv \
  puppet \
  rpm \
  rsync \
  sed \
  sudo \
  tar \
  tmux \
  unzip \
  util-linux \
  vim \
  which \
  zip \
  zsh \
  maven3 \
  jx \
  cf-cli \
  golang \
  ruby \
  rubygems \
  packer \
  dcos-cli \
  ripgrep \
  azcopy \
  apparmor-parser \
  apparmor-utils \
  cronie \
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
  gh \
  redis \
  cpio \
  gettext
