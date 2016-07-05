FROM alpine:3.4

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -g 82 -S www-data \
	&& adduser -u 82 -D -S -G www-data www-data

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $PATH:$HTTPD_PREFIX/bin
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

# see https://httpd.apache.org/download.cgi#verify
ENV GPG_KEY A93D62ECC3C8EA12DB220EC934EA76E6791485A8
ENV HTTPD_VERSION 2.4.20
ENV HTTPD_BZ2_URL https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2

# see https://httpd.apache.org/docs/2.4/install.html#requirements
RUN set -x \
	&& apk add --no-cache --virtual .build-deps \
		apr-dev \
		apr-util-dev \
		curl \
		gcc \
		gnupg \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
	&& curl -fSL "$HTTPD_BZ2_URL" -o httpd.tar.bz2 \
	&& curl -fSL "$HTTPD_BZ2_URL.asc" -o httpd.tar.bz2.asc \
# see https://httpd.apache.org/download.cgi#verify
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys $GPG_KEY \
	&& gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2 \
	&& rm -r "$GNUPGHOME" httpd.tar.bz2.asc \
	&& mkdir -p src \
	&& tar -jxvf httpd.tar.bz2 -C src \
	&& rm httpd.tar.bz2 \
	&& cd src/httpd-$HTTPD_VERSION \
	&& ./configure --enable-so --enable-ssl --prefix=$HTTPD_PREFIX --enable-mods-shared=most \
	&& make -j"$(getconf _NPROCESSORS_ONLN)" \
	&& make install \
	&& cd ../../ \
	&& rm -r src/httpd-$HTTPD_VERSION \
	&& sed -ri ' \
		s!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g; \
		s!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g; \
		' /usr/local/apache2/conf/httpd.conf \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .httpd-rundeps $runDeps \
		apr-dev \
		apr-util-dev \
	&& apk del .build-deps

COPY httpd-foreground /usr/local/bin/

EXPOSE 80
CMD ["httpd-foreground"]
