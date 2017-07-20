# this cannot upgrade to Alpine 3.5 due to https://github.com/libressl-portable/portable/issues/147
# given that 2.2.x is a "legacy branch", and is in security-fixes-only mode upstream, this should be reasonably fine
#   "Minimal maintenance patches of 2.2.x are expected throughout this period, and users are strongly encouraged to promptly complete their transitions to the the 2.4.x flavour of httpd to benefit from a much larger assortment of minor security and bug fixes as well as new features."
# https://httpd.apache.org/
FROM alpine:3.4

# ensure www-data user exists
RUN set -x \
	&& addgroup -g 82 -S www-data \
	&& adduser -u 82 -D -S -G www-data www-data
# 82 is the standard uid/gid for "www-data" in Alpine
# http://git.alpinelinux.org/cgit/aports/tree/main/apache2/apache2.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/lighttpd/lighttpd.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/nginx-initscripts/nginx-initscripts.pre-install?h=v3.3.2

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

ENV HTTPD_VERSION 2.2.34
ENV HTTPD_SHA1 829206394e238af0b800fc78d19c74ee466ecb23

# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
ENV HTTPD_BZ2_URL https://www.apache.org/dyn/closer.cgi?action=download&filename=httpd/httpd-$HTTPD_VERSION.tar.bz2
# not all the mirrors actually carry the .asc files :'(
ENV HTTPD_ASC_URL https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2.asc

# if the version is outdated, we have to pull from the archive :/
ENV HTTPD_BZ2_FALLBACK_URL https://archive.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2
ENV HTTPD_ASC_FALLBACK_URL https://archive.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2.asc

# see https://httpd.apache.org/docs/2.2/install.html#requirements
RUN set -x \
	&& runDeps=' \
		apr-dev \
		apr-util-dev \
		apr-util-ldap \
		perl \
	' \
	&& apk add --no-cache --virtual .build-deps \
		$runDeps \
		ca-certificates \
		coreutils \
		dpkg-dev dpkg \
		gcc \
		gnupg \
		libc-dev \
		make \
		openssl \
		openssl-dev \
		pcre-dev \
		tar \
	\
	&& { \
		wget -O httpd.tar.bz2 "$HTTPD_BZ2_URL" \
		|| wget -O httpd.tar.bz2 "$HTTPD_BZ2_FALLBACK_URL" \
	; } \
	&& echo "$HTTPD_SHA1 *httpd.tar.bz2" | sha1sum -c - \
# see https://httpd.apache.org/download.cgi#verify
	&& { \
		wget -O httpd.tar.bz2.asc "$HTTPD_ASC_URL" \
		|| wget -O httpd.tar.bz2.asc "$HTTPD_ASC_FALLBACK_URL" \
	; } \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B1B96F45DFBDCCF974019235193F180AB55D9977 \
	&& gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2 \
	&& rm -rf "$GNUPGHOME" httpd.tar.bz2.asc \
	\
	&& mkdir -p src \
	&& tar -xf httpd.tar.bz2 -C src --strip-components=1 \
	&& rm httpd.tar.bz2 \
	&& cd src \
	\
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--prefix="$HTTPD_PREFIX" \
# https://httpd.apache.org/docs/2.2/programs/configure.html
# Caveat: --enable-mods-shared=all does not actually build all modules. To build all modules then, one might use:
		--enable-mods-shared='all ssl ldap cache proxy authn_alias mem_cache file_cache authnz_ldap charset_lite dav_lock disk_cache' \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& cd .. \
	&& rm -r src man manual \
	\
	&& sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		"$HTTPD_PREFIX/conf/httpd.conf" \
	\
	&& runDeps="$runDeps $( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .httpd-rundeps $runDeps \
	&& apk del .build-deps

COPY httpd-foreground /usr/local/bin/

EXPOSE 80
CMD ["httpd-foreground"]
