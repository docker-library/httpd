#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

nghttp2VersionDebian="$(docker run -i --rm debian:stretch-slim bash -c 'apt-get update -qq && apt-cache show "$@"' -- "libnghttp2-dev" |tac|tac| awk -F ': ' '$1 == "Version" { print $2; exit }')"
opensslVersionDebian="$(docker run -i --rm debian:jessie-backports bash -c 'apt-get update -qq && apt-cache show "$@"' -- "openssl" |tac|tac| awk -F ': ' '$1 == "Version" { print $2; exit }')"

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(curl -sSL --compressed "https://www-us.apache.org/dist/httpd/" | grep -E '<a href="httpd-'"$version"'[^"-]+.tar.bz2"' | sed -r 's!.*<a href="httpd-([^"-]+).tar.bz2".*!\1!' | sort -V | tail -1)"
	sha1="$(curl -fsSL "https://www-us.apache.org/dist/httpd/httpd-$fullVersion.tar.bz2.sha1" | cut -d' ' -f1)"
	patchUrl="https://www-us.apache.org/dist/httpd/patches/apply_to_$fullVersion"
	patchInsert="$(mktemp)"
	echo "# Apply source patches" > $patchInsert
	if curl -fsIo /dev/null "$patchUrl/"; then
	    patchFiles="$(curl -fssL "$patchUrl/?C=M;O=A" | grep -E 'Source code patch$' | sed -r 's!.*<a href=\"([^\"]+)\".*!\1!')"
	    for patch in $patchFiles; do
		psum="$(curl -fssL $patchUrl/$patch | sha256sum | cut -d ' ' -f1)"
		echo "        && { \\" >> $patchInsert
		echo "             wget -O ${patch} \"$patchUrl/$patch\" \\" >> $patchInsert
		echo "               && echo \"${psum} ${patch}\" | sha256sum -c - \\" >> $patchInsert
		echo "               && patch -p0 < ${patch} \\" >>$patchInsert
		echo "               && rm ${patch} \\" >> $patchInsert
		echo "        ; } \\" >> $patchInsert
	    done
	fi
	echo "# End source patch list" >> $patchInsert
	(
		set -x
		sed -ri \
			-e 's/^(ENV HTTPD_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV HTTPD_SHA1) .*/\1 '"$sha1"'/' \
			-e 's/^(ENV NGHTTP2_VERSION) .*/\1 '"$nghttp2VersionDebian"'/' \
			-e 's/^(ENV OPENSSL_VERSION) .*/\1 '"$opensslVersionDebian"'/' \
                        -e '/# Apply source patches/{:a;N;/# End source patch list/!ba;' -e 'r '"$patchInsert" -e 'd;};' \
			"$version/Dockerfile" "$version"/*/Dockerfile
	)
	rm $patchInsert

	for variant in alpine; do
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
