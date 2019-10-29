FROM debian:buster-slim

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
#RUN groupadd -r www-data && useradd -r --create-home -g www-data www-data

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

# install httpd runtime dependencies
# https://httpd.apache.org/docs/2.4/install.html#requirements
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libapr1-dev \
		libaprutil1-dev \
		libaprutil1-ldap \
	; \
	rm -rf /var/lib/apt/lists/*

ENV HTTPD_VERSION 2.4.41
ENV HTTPD_SHA256 133d48298fe5315ae9366a0ec66282fa4040efa5d566174481077ade7d18ea40

# https://httpd.apache.org/security/vulnerabilities_24.html
ENV HTTPD_PATCHES=""

# see https://httpd.apache.org/docs/2.4/install.html#requirements
RUN set -eux; \
	\
	# mod_http2 mod_lua mod_proxy_html mod_xml2enc
	# https://anonscm.debian.org/cgit/pkg-apache/apache2.git/tree/debian/control?id=adb6f181257af28ee67af15fc49d2699a0080d4c
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bzip2 \
		ca-certificates \
		dirmngr \
		dpkg-dev \
		gcc \
		gnupg \
		libbrotli-dev \
		libcurl4-openssl-dev \
		libjansson-dev \
		liblua5.2-dev \
		libnghttp2-dev \
		libpcre3-dev \
		libssl-dev \
		libxml2-dev \
		make \
		wget \
		zlib1g-dev \
	; \
	rm -r /var/lib/apt/lists/*; \
	\
	ddist() { \
		local f="$1"; shift; \
		local distFile="$1"; shift; \
		local success=; \
		local distUrl=; \
		for distUrl in \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
			'https://www.apache.org/dyn/closer.cgi?action=download&filename=' \
# if the version is outdated (or we're grabbing the .asc file), we might have to pull from the dist/archive :/
			https://www-us.apache.org/dist/ \
			https://www.apache.org/dist/ \
			https://archive.apache.org/dist/ \
		; do \
			if wget -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
				success=1; \
				break; \
			fi; \
		done; \
		[ -n "$success" ]; \
	}; \
	\
	ddist 'httpd.tar.bz2' "httpd/httpd-$HTTPD_VERSION.tar.bz2"; \
	echo "$HTTPD_SHA256 *httpd.tar.bz2" | sha256sum -c -; \
	\
# see https://httpd.apache.org/download.cgi#verify
	ddist 'httpd.tar.bz2.asc' "httpd/httpd-$HTTPD_VERSION.tar.bz2.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in \
# gpg: key 791485A8: public key "Jim Jagielski (Release Signing Key) <jim@apache.org>" imported
		A93D62ECC3C8EA12DB220EC934EA76E6791485A8 \
# gpg: key 995E35221AD84DFF: public key "Daniel Ruggeri (https://home.apache.org/~druggeri/) <druggeri@apache.org>" imported
		B9E8213AEFB861AF35A41F2C995E35221AD84DFF \
	; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done; \
	gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" httpd.tar.bz2.asc; \
	\
	mkdir -p src; \
	tar -xf httpd.tar.bz2 -C src --strip-components=1; \
	rm httpd.tar.bz2; \
	cd src; \
	\
	patches() { \
		while [ "$#" -gt 0 ]; do \
			local patchFile="$1"; shift; \
			local patchSha256="$1"; shift; \
			ddist "$patchFile" "httpd/patches/apply_to_$HTTPD_VERSION/$patchFile"; \
			echo "$patchSha256 *$patchFile" | sha256sum -c -; \
			patch -p0 < "$patchFile"; \
			rm -f "$patchFile"; \
		done; \
	}; \
	patches $HTTPD_PATCHES; \
	\
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	./configure \
		--build="$gnuArch" \
		--prefix="$HTTPD_PREFIX" \
		--enable-mods-shared=reallyall \
		--enable-mpms-shared=all \
# enable the same hardening flags as Debian
# - https://salsa.debian.org/apache-team/apache2/blob/87db7de4e59683fb03e97900f078d06ef2292748/debian/rules#L19-21
# - https://salsa.debian.org/apache-team/apache2/blob/87db7de4e59683fb03e97900f078d06ef2292748/debian/rules#L115
		--enable-pie \
		CFLAGS="-pipe $CFLAGS" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="-Wl,--as-needed $LDFLAGS" \
	; \
	make -j "$(nproc)"; \
	make install; \
	\
	cd ..; \
	rm -r src man manual; \
	\
	sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		-e 's!^(\s*TransferLog)\s+\S+!\1 /proc/self/fd/1!g' \
		"$HTTPD_PREFIX/conf/httpd.conf" \
		"$HTTPD_PREFIX/conf/extra/httpd-ssl.conf" \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# smoke test
	httpd -v

# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL WINCH

COPY httpd-foreground /usr/local/bin/

EXPOSE 80
CMD ["httpd-foreground"]
