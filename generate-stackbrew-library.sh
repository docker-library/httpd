#!/usr/bin/env bash
set -eu

declare -A aliases=(
	[2.4]='2 latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesBase="${BASHBREW_LIBRARY:-https://github.com/docker-library/official-images/raw/HEAD/library}/"

	local parentRepoToArchesStr
	parentRepoToArchesStr="$(
		find -name 'Dockerfile' -exec awk -v officialImagesBase="$officialImagesBase" '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					printf "%s%s\n", officialImagesBase, $2
				}
			' '{}' + \
			| sort -u \
			| xargs -r bashbrew cat --format '["{{ .RepoName }}:{{ .TagName }}"]="{{ join " " .TagEntry.Architectures }}"'
	)"
	eval "declare -g -A parentRepoToArches=( $parentRepoToArchesStr )"
}
getArches 'httpd'

cat <<-EOH
# this file is generated via https://github.com/docker-library/httpd/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/httpd.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	for variant in '' alpine; do
		dir="$version${variant:+/$variant}"
		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

		fullVersion="$(git show "$commit":"$dir/Dockerfile" | awk '$1 == "ENV" && $2 == "HTTPD_VERSION" { print $3; exit }')"

		versionAliases=(
			$fullVersion
			$version
			${aliases[$version]:-}
		)

		if [ -z "$variant" ]; then
			variantAliases=( "${versionAliases[@]}" )
		else
			variantAliases=( "${versionAliases[@]/%/-$variant}" )
			variantAliases=( "${variantAliases[@]//latest-/}" )
		fi

		variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"

		suite="${variantParent#*:}" # "bookworm-slim", "bookworm"
		suite="${suite%-slim}" # "bookworm"

		if [ "$variant" = 'alpine' ]; then
			suite="alpine$suite" # "alpine3.15"
			suiteAliases=( "${versionAliases[@]/%/-$suite}" )
		else
			suiteAliases=( "${variantAliases[@]/%/-$suite}" )
		fi
		suiteAliases=( "${suiteAliases[@]//latest-/}" )
		variantAliases+=( "${suiteAliases[@]}" )

		variantArches="${parentRepoToArches[$variantParent]}"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
