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
	fullVersion="$(curl -sSL --compressed "https://www.apache.org/dist/httpd/" | grep -E '<a href="httpd-'"$version"'[^"-]+.tar.bz2"' | sed -r 's!.*<a href="httpd-([^"-]+).tar.bz2".*!\1!' | sort -V | tail -1)"
	(
		set -x
		sed -ri '
			s/^(ENV HTTPD_VERSION) .*/\1 '"$fullVersion"'/;
		' "$version/Dockerfile"
	)
	
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
