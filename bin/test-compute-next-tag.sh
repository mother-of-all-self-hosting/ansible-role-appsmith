#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Appsmith v2.2 which has already
# seen two releases of it (v2.2-0 and v2.2-1).
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	# Written the way defaults/main.yml really is, Renovate annotation and all,
	# so that the extraction is exercised against the line it has to cope with.
	printf '# renovate: datasource=docker depName=appsmith/appsmith-ce\nappsmith_version: v2.2\n' > defaults/main.yml
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v2.2-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|appsmith_version: v2.2|appsmith_version: v2.3|' defaults/main.yml"
revert_version="sed -i 's|appsmith_version: v2.3|appsmith_version: v2.2|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v2.3-0 "$(merge "$bump_version")"
expect 'task edit'    v2.3-1 "$(merge "$edit_task")"
expect 'template'     v2.3-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v2.2-2 "$(merge "$edit_task")"
expect 'version bump' v2.3-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''      "$(merge "$edit_readme")"
expect 'a script' ''      "$(merge "$edit_script")"
expect 'meta'     v2.2-2  "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
# The real history has this shape: v1.53.1 was released ten times, so the
# eleventh had to sort -10 above -9 rather than below it.
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v2.2-$release_number"
done
expect 'a task' v2.2-11 "$(merge "$edit_task")"

# Appsmith renumbered from `v1.9`, `v1.9.1` ... to `v1.90`, `v1.91` ... and then
# to `v2.0`, so version strings that are prefixes of other version strings
# genuinely coexist in this repository's tag history. A release of `v2.3` must
# not be counted as a release of `v2.30`, in either direction.
scenario 'A version whose string is a prefix of another released version'
git tag 'v2.30-0'
git tag 'v2.30-1'
git tag 'v2.30-2'
expect 'bump to v2.3' v2.3-0 "$(merge "$bump_version")"

scenario 'A version another released version is a prefix of'
git tag 'v2.2-7'
expect 'bump to v2.30' v2.30-0 "$(merge "sed -i 's|appsmith_version: v2.2|appsmith_version: v2.30|' defaults/main.yml")"

# Appsmith has shipped respins with a fourth component (`v1.9.37.1`), and the
# tag is built from the version verbatim, so those release like anything else.
scenario 'A version with a fourth component'
expect 'bump to v1.9.37.1' v1.9.37.1-0 "$(merge "sed -i 's|appsmith_version: v2.2|appsmith_version: v1.9.37.1|' defaults/main.yml")"
expect 'task edit'         v1.9.37.1-1 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v2.2-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v2.2-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
