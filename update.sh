#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(
		wget -qO- "https://www-us.apache.org/dist/httpd/" \
			| grep -E '<a href="httpd-'"$version"'[^"-]+.tar.bz2"' \
			| sed -r 's!.*<a href="httpd-([^"-]+).tar.bz2".*!\1!' \
			| sort -V \
			| tail -1
	)"
	sha256="$(wget -qO- "https://www-us.apache.org/dist/httpd/httpd-$fullVersion.tar.bz2.sha256" | cut -d' ' -f1)"
	echo "$version: $fullVersion"

	patchesUrl="https://www-us.apache.org/dist/httpd/patches/apply_to_$fullVersion"
	patches=()
	if wget --quiet --spider -O /dev/null -o /dev/null "$patchesUrl/"; then
		patchFiles="$(
			wget -qO- "$patchesUrl/?C=M;O=A" \
				| grep -oE 'href="[^"]+[.]patch"' \
				| cut -d'"' -f2 \
				|| true
		)"
		for patchFile in $patchFiles; do
			patchSha256="$(wget -qO- "$patchesUrl/$patchFile" | sha256sum | cut -d' ' -f1)"
			[ -n "$patchSha256" ]
			patches+=( "$patchFile" "$patchSha256" )
		done
	fi
	if [ "${#patches[@]}" -gt 0 ]; then
		echo " - ${patches[*]}"
	fi

	sed -ri \
		-e 's/^(ENV HTTPD_VERSION) .*/\1 '"$fullVersion"'/' \
		-e 's/^(ENV HTTPD_SHA256) .*/\1 '"$sha256"'/' \
		-e 's/^(ENV HTTPD_PATCHES=").*(")$/\1'"${patches[*]}"'\2/' \
		"$version/Dockerfile" "$version"/*/Dockerfile

	for variant in alpine; do
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
