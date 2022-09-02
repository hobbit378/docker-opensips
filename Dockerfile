ARG TARGETPLATFORM

FROM debian:buster

LABEL maintainer="Matthias Wetzel (hobbit378 at gmail dot com)"

### Set defaults
ENV OPENSIPS_VERSION=3.2.8 \
    OPENSIPS_REPO_URL="https://github.com/OpenSIPS/opensips.git" \
    #NO_OPENSIPSCLI="TRUE" \
    OPENSIPSCLI_VERSION="master" \
    OPENSIPSCLI_REPO_URL="https://github.com/OpenSIPS/opensips-cli.git" 

### Add users
RUN useradd --system --no-create-home opensips && \
    #lock user password - disable password logins
    passwd -l opensips && \
\
### Runtime dependencies
    OPENSIPS_RUNT_DEPS='ca-certificates  coreutils  curl  git  lsb-release  m4  make  tar  vim  wget  xsltproc' && \
\
###  Development dependencies
    OPENSIPS_BUILD_LIBS='default-libmysqlclient-dev \
                 dpkg-dev  libconfuse-dev  libcurl4-gnutls-dev  libdb-dev  libfreediameter-dev   libexpat1-dev  libmaxminddb-dev  libgeoip-dev  libhiredis-dev  libjson-c-dev  libjwt-dev  librdkafka-dev  libldap2-dev  liblua5.1-0-dev  libmemcached-dev  libmicrohttpd-dev  libbson-dev  libmongoc-dev  libncurses5-dev  libpcre3-dev  libperl-dev  libpq-dev  librabbitmq-dev  libradcli-dev  libsctp-dev  libsnmp-dev  libsqlite3-dev  libssl-dev  uuid-dev  libxml2-dev  pkg-config  python-dev  unixodbc-dev  zlib1g-dev' && \
\
    OPENSIPS_BUILD_TOOLS='build-essential  bison  flex' && \
\
    OPENSIPS_BUILDDEPS_SATISFY='bison, \
                debhelper (>= 9), default-libmysqlclient-dev | libmysqlclient-dev, debhelper (>= 9.20160709) | dh-systemd (>= 1.5), dpkg-dev (>= 1.16.1.1), flex, libconfuse-dev, libcurl4-gnutls-dev, libdb-dev (>= 4.6.19), libfdcore6 (>= 1.2.1) | base-files, libfdproto6 (>= 1.2.1) | base-files, libfreediameter-dev (>= 1.2.1) | base-files, libexpat1-dev, libmaxminddb-dev | libgeoip-dev (>= 1.4.4), libhiredis-dev, libjson-c-dev, libjwt-dev | base-files, librdkafka-dev, libldap2-dev, liblua5.1-0-dev, libmemcached-dev, libmicrohttpd-dev, libbson-dev | base-files, libmongoc-dev | base-files, libncurses5-dev, libpcre3-dev, libperl-dev, libpq-dev, librabbitmq-dev, libradcli-dev | libfreeradius-client-dev, libsctp-dev [linux-any], libsnmp-dev, libsqlite3-dev, libssl-dev, lsb-release, uuid-dev, libxml2-dev, pkg-config, python | python-is-python3, python-dev | python-dev-is-python3, unixodbc-dev, xsltproc, zlib1g-dev' && \
\
# ### Pin libxml2 packages to Debian repositories
#     echo "Package: libxml2*" > /etc/apt/preferences.d/libxml2 && \
#     echo "Pin: release o=Debian,n=buster" >> /etc/apt/preferences.d/libxml2 && \
#     echo "Pin-Priority: 501" >> /etc/apt/preferences.d/libxml2 && \
\
### Update base image and install dependencies
    set -x && \
    export DEBIAN_FRONTEND=noninteractive && \
    export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=TRUE && \
    apt-get update && \
    apt-get -o Dpkg::Options::="--force-confold" upgrade -y && \
    apt-get install --no-install-recommends -y \
                    ${OPENSIPS_RUNT_DEPS} \ 
                    ${OPENSIPS_BUILD_LIBS} \
                    ${OPENSIPS_BUILD_TOOLS}

### Prepare OpenSIPS source code
ADD /patchset /patchset
RUN cd /usr/src && \
    git clone --depth 1 --branch ${OPENSIPS_VERSION} ${OPENSIPS_REPO_URL} && \
    cd opensips && \
    find /patchset -type f -name '*.patch' -print -exec git apply '{}' \; && \
    \
### Compile
    if expr ${TARGETPLATFORM} : 'linux/arm/v7.*' ; then \
        CC_EXTRA_OPTS="-march=armv7-a -mthumb-interwork -mfloat-abi=hard -mfpu=neon -marm" make ; \
        CC_EXTRA_OPTS="-march=armv7-a -mthumb-interwork -mfloat-abi=hard -mfpu=neon -marm" make modules ; \
    else \
        make ; \
        make modules ; \
    fi ; \
    make install && \
\
### Install OpenSIPS-CLI
    if [ -z ${NO_OPENSIPSCLI} ] ; then \
        OPENSIPS_CLI_BUILD_LIBS='python3 \
                    python3-pip python3-dev gcc default-libmysqlclient-dev python3-mysqldb python3-sqlalchemy python3-sqlalchemy-utils python3-openssl' && \
        apt-get --no-install-recommends -y install ${OPENSIPS_CLI_BUILD_LIBS} ; \
        cd /usr/src ; \
        git clone --depth 1 --branch ${OPENSIPSCLI_VERSION} ${OPENSIPSCLI_REPO_URL} ; \
        cd opensips-cli ; \
        python3 setup.py install clean ; \
    fi && \
\
### Cleanup
    rm -rf /usr/src/* /patchset /tmp/* /etc/cron* && \
    apt-get -y purge ${OPENSIPS_BUILD_TOOLS} && \
    apt-get -y autoremove && \
    apt-get -y purge ${OPENSIPS_BUILD_LIBS} && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* 

### Files add
ADD /install /

VOLUME [ "/usr/local/etc/opensips" ]

ENTRYPOINT [ "/usr/local/sbin/opensips", "-u 999", "-g 998", "-D" ]
