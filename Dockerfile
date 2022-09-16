ARG BUILD_STAGE="hobbit00378/opensips:build-x64-latest"
ARG BASE_DISTRO="debian:buster"


FROM amd64/${BASE_DISTRO} as opensips-build-x64

LABEL maintainer="Matthias Wetzel (hobbit378 at gmail dot com)"

### Set defaults
ARG OPENSIPS_VERSION=3.2.8 \
    OPENSIPS_REPO_URL="https://github.com/OpenSIPS/opensips.git" \
    OPENSIPS_BUILD_TOOLS='build-essential bison flex' \
    OPENSIPS_BUILD_LIBS='default-libmysqlclient-dev \
        dpkg-dev  libconfuse-dev  libcurl4-gnutls-dev  libdb-dev  libfreediameter-dev   libexpat1-dev  libmaxminddb-dev  libgeoip-dev  libhiredis-dev  libjson-c-dev  libjwt-dev  librdkafka-dev  libldap2-dev  liblua5.1-0-dev  libmemcached-dev  libmicrohttpd-dev  libbson-dev  libmongoc-dev  libncurses5-dev  libpcre3-dev  libperl-dev  libpq-dev  librabbitmq-dev  libradcli-dev  libsctp-dev  libsnmp-dev  libsqlite3-dev  libssl-dev  uuid-dev  libxml2-dev  pkg-config  python-dev  unixodbc-dev  zlib1g-dev' \
    OPENSIPS_BUILD_LIBS_EXTRA="" \
    OPENSIPS_RUNT_DEPS='ca-certificates  coreutils  curl  git  lsb-release  m4  make  tar  vim  wget  xsltproc'

### Update base image and install dependencies
RUN set -x && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
                    ${OPENSIPS_RUNT_DEPS} \ 
                    ${OPENSIPS_BUILD_TOOLS} \
                    ${OPENSIPS_BUILD_LIBS}  ${OPENSIPS_BUILD_LIBS_EXTRA} ; \
    \    
    ### Prepare OpenSIPS source code
    cd /usr/src && \
    git clone --depth 1 --branch ${OPENSIPS_VERSION} ${OPENSIPS_REPO_URL} opensips 

### Compile
RUN cd /usr/src/opensips ; \
    make && \
    make modules && \
    make bin && \
    make install ; \
    /usr/local/sbin/opensips -C && echo "Runing test SUCCESS" || echo "Runing test FAILURE"

ENTRYPOINT [ "/bin/bash" ]


FROM amd64/${BASE_DISTRO} as opensips-xbuild-arm

LABEL maintainer="Matthias Wetzel (hobbit378 at gmail dot com)"

### Set defaults
ARG OPENSIPS_VERSION=3.2.8 \
    OPENSIPS_REPO_URL="https://github.com/OpenSIPS/opensips.git" \
    OPENSIPS_BUILD_TOOLS='crossbuild-essential-armhf bison flex' \
    OPENSIPS_BUILD_LIBS='default-libmysqlclient-dev:armhf \
        dpkg-dev:armhf  libconfuse-dev:armhf  libcurl4-gnutls-dev:armhf  libdb-dev:armhf  libfreediameter-dev:armhf   libexpat1-dev:armhf  libmaxminddb-dev:armhf  libgeoip-dev:armhf  libhiredis-dev:armhf  libjson-c-dev:armhf  libjwt-dev:armhf  librdkafka-dev:armhf  libldap2-dev:armhf  liblua5.1-0-dev:armhf  libmemcached-dev:armhf  libmicrohttpd-dev:armhf  libbson-dev:armhf  libmongoc-dev:armhf  libncurses5-dev:armhf  libpcre3-dev:armhf  libperl-dev:armhf  libpq-dev:armhf  librabbitmq-dev:armhf  libradcli-dev:armhf  libsctp-dev:armhf  libsnmp-dev:armhf  libsqlite3-dev:armhf  libssl-dev:armhf  uuid-dev:armhf  libxml2-dev:armhf  pkg-config:armhf  python-dev:armhf  unixodbc-dev:armhf  zlib1g-dev:armhf' \
    OPENSIPS_BUILD_LIBS_EXTRA="" \
    OPENSIPS_RUNT_DEPS='ca-certificates  coreutils  curl  git  lsb-release  m4  make  tar  vim  wget  xsltproc'


### Provide OpenSIPS source code patches
ADD /patchset /usr/src/opensips-patchset

### Update base image and install dependencies
RUN set -x && \
    export DEBIAN_FRONTEND=noninteractive && \
    dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
                    ${OPENSIPS_RUNT_DEPS} \ 
                    ${OPENSIPS_BUILD_TOOLS} \
                    ${OPENSIPS_BUILD_LIBS}  ${OPENSIPS_BUILD_LIBS_EXTRA} ; \
    \
### Prepare OpenSIPS source code
    cd /usr/src && \
    git clone --depth 1 --branch ${OPENSIPS_VERSION} ${OPENSIPS_REPO_URL} opensips && \
    cd opensips && \
    find /usr/src/opensips-patchset/armv7 -type f -name '*.patch' -print -exec git apply '{}' \; 

### Compile
RUN export CC=arm-linux-gnueabihf-gcc ; \
    export CC_EXTRA_OPTS="-march=armv7-a -mthumb-interwork -mfloat-abi=hard -mfpu=neon -marm" ; \
    cd /usr/src/opensips ; \
    make && \
    make modules && \
    make bin ;

ENTRYPOINT [ "/bin/bash" ]


FROM ${BUILD_STAGE} as opensips-build-stage 


FROM ${BASE_DISTRO} as opensips

LABEL maintainer="Matthias Wetzel (hobbit378 at gmail dot com)"

### Set defaults
ARG OPENSIPS_RUNT_DEPS='ca-certificates  \
        coreutils  curl  git  lsb-release  m4  make  tar  vim  wget  xsltproc' \
    OPENSIPS_RUNT_DEPS_EXTRA="" \
    OPENSIPSCLI_REPO_URL="https://github.com/OpenSIPS/opensips-cli.git" \
    OPENSIPSCLI_VERSION="master" \
    OPENSIPSCLI_BUILD_LIBS='python3 \
        python3-pip python3-dev gcc default-libmysqlclient-dev python3-mysqldb python3-sqlalchemy python3-sqlalchemy-utils python3-openssl'

ENV OPENSIPS_UID="999" \
    OPENSIPS_GID="999" \
    OPENSIPS_START_OPTS="-D"

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=bind,from="opensips-build-stage",target=/xbuild \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    \
    ### Add user
    groupadd --gid ${OPENSIPS_GID} opensips && \
    useradd --uid ${OPENSIPS_UID} --gid ${OPENSIPS_GID} -rM opensips && \
    \
    ### Update base image and install dependencies
    set -x ; \
    DEBIAN_FRONTEND=noninteractive ; \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
            ${OPENSIPS_RUNT_DEPS} ${OPENSIPS_RUNT_DEPS_EXTRA} && \
    \
    ### Install pre-compiled opensips arm binaries
    tar -xzvf /xbuild/usr/src/opensips*.tar.gz -C / ; \
    \
    ### Install OpenSIPS-CLI
    if [ -z ${NO_OPENSIPSCLI} ] ; then \
        apt-get install --no-install-recommends -y \
             ${OPENSIPSCLI_BUILD_LIBS} ; \
        cd /usr/src ; \
        git clone --depth 1 --branch ${OPENSIPSCLI_VERSION} ${OPENSIPSCLI_REPO_URL} opensips-cli ; \
        cd opensips-cli ; \
        python3 setup.py install clean ; \
    fi && \
    \
    ### Run config test
    /usr/local/sbin/opensips -C || echo "RUN CHECK FAILED" ; \
    \
    ### Cleanup
    rm -rf /usr/src/* /tmp/* /etc/cron* && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* 

### Files add
ADD /install /

VOLUME [ "/usr/local/etc/opensips" ]

ENTRYPOINT /usr/local/sbin/opensips -u ${OPENSIPS_UID} -g ${OPENSIPS_GID} ${OPENSIPS_START_OPTS}