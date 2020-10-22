# #########################################
#
# Image for arbetsformedlingen CRM (Odoo)
# Made By: Peter Hammarstrom
# Date:  January 2020
#
#-------------------------------------------------------
# Ubuntu install info, https://hub.docker.com/_/ubuntu/
#

FROM scratch
ADD ubuntu-bionic-core-cloudimg-amd64-root.tar.gz /
ENV LANG C.UTF-8

# verify that the APT lists files do not exist
RUN [ -z "$(apt-get indextargets)" ]
# (see https://bugs.launchpad.net/cloud-images/+bug/1699913)

# a few minor docker-specific tweaks
# see https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap
RUN set -xe \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L40-L48
        && echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
        && echo 'exit 101' >> /usr/sbin/policy-rc.d \
        && chmod +x /usr/sbin/policy-rc.d \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L54-L56
        && dpkg-divert --local --rename --add /sbin/initctl \
        && cp -a /usr/sbin/policy-rc.d /sbin/initctl \
        && sed -i 's/^exit.*/exit 0/' /sbin/initctl \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L71-L78
        && echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L85-L105
        && echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
        && echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
        && echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L109-L115
        && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L118-L130
        && echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
        \
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L134-L151
        && echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests

# make systemd-detect-virt return "docker"
# See: https://github.com/systemd/systemd/blob/aa0c34279ee40bce2f9681b496922dedbadfca19/src/basic/virt.c#L434
RUN mkdir -p /run/systemd && echo 'docker' > /run/systemd/container

#-----------------------------------------------------
##  Odoo Install start: Based on  https://hub.docker.com/_/odoo version 12.0
# From Odoo official Image
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            rsync \
            vim \
            dirmngr \
            fonts-noto-cjk \
            gnupg \
            libssl1.0-dev \
            xz-utils

# From Vertel Install Script
RUN set -x; \
	apt-get update \
        && apt-get install -y --no-install-recommends\
	    git \
	    python3-pip \
	    build-essential \
	    wget \
	    python3-dev \
	    python3-venv \
	    python3-wheel \
	    libxslt-dev \
	    libzip-dev \
	    libldap2-dev \
	    libxml2-dev \
        libxmlsec1-dev \
        libsasl2-dev \
	    python3-setuptools \
	    node-less \
        python3-lasso

# wget -O /tmp/requirements.txt https://raw.githubusercontent.com/odoo/odoo/12.0/requirements.txt
# Use local copy
COPY ./requirements.txt /tmp/requirements.txt
RUN set -x; \
        pip3 install wheel \
        && pip3 install -r /tmp/requirements.txt \
        && pip3 install odoorpc \
        && pip3 install openpyxl \
        && pip3 install phonenumbers \
        && pip3 install python3-saml \
        && pip3 install simplejson \
        && pip3 install stomp.py \
        && pip3 install xmltodict \
        && pip3 install zeep

RUN set -x; \
		wget -O /tmp/wkhtmltox_0.12.1.3-1~bionic_amd64.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb \
		&& apt-get install -y --no-install-recommends /tmp/wkhtmltox_0.12.1.3-1~bionic_amd64.deb \
		&& rm -f /tmp/wkhtmltox_0.12.1.3-1~bionic_amd64.deb

# Fix Odoo User and group, needed for odoo installation
#
RUN set -x; \
      chmod g=u /etc/passwd \
      && chmod g=u /etc/passwd \
      && echo "odoo:x:1001190000:1001190000::/var/lib/odoo:/usr/sbin/nologin" >> /etc/passwd \
      && echo "odoo:x:1001190000:" >> /etc/group \
      && usermod -a -G root odoo \
      && mkdir -p /var/lib/odoo \
      && chown -R odoo:0 /var/lib/odoo

# Install Odoo  Install specific build and not latest
ENV ODOO_VERSION 12.0
ARG ODOO_RELEASE=20191201
ARG ODOO_SHA=41f3d9b28a02db28db57ec4cec6351866fb2ac6a
RUN set -x; \
        curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
        && dpkg --force-depends -i odoo.deb \
		&& export DEBIAN_FRONTEND=noninteractive \
        && apt-get update \
        && apt-get -y install -f --no-install-recommends \
        && rm -rf /var/lib/apt/lists/* odoo.deb \
		&& ln -fs /usr/share/zoneinfo/Europe/Stockholm /etc/localtime \
		&& dpkg-reconfigure --frontend noninteractive tzdata \
		&& ln -s /usr/lib/python3/dist-packages/odoo/ /usr/share/core-odoo

# Copy Af certificate
COPY ./Arbetsformedlingen_ServerCertUPA_CA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./af_init_db.sh /
COPY ./odoo.conf /etc/odoo/
COPY ./installed_modules.conf /
RUN chown odoo /etc/odoo/odoo.conf
RUN ln -sf /dev/stdout /var/log/odoo/odoo-server.log
#RUN /af_init_odooprojects.sh ${BRANCH}

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons \
  	&& chown -R odoo:0 /mnt/extra-addons \
        && chmod -R g=u /mnt/extra-addons \
        && mkdir /usr/share/afcrm \
        && chown -R odoo:0 /usr/share/afcrm \
        && chmod -R g=u /usr/share/afcrm \
        && chown -R odoo:0 /var/lib/odoo \
        && chmod -R g=u /var/lib/odoo
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER 1001190000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
