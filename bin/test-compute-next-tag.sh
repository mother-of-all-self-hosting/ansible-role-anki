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

# Starts a scenario with a repository at Anki 26.08 which has already seen one
# release of it (v26.08-0), plus the two- and three-component releases of 25.02
# that this repository really carries. `v25.02-2` sitting next to `v25.02.6-0`
# is the trap here: the release counter of one version must never be read off
# the tags of another.
#
# The defaults file deliberately carries the traps this role's real one has: a
# commented-out example of the version variable, an image tag derived from it,
# and a self-build repository version derived from it through a conditional.
# None of them may be picked up as the version, and the Renovate annotation
# which decides what gets bumped is included so that moving it away from
# `anki_version` breaks this suite.
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

	cat > defaults/main.yml <<-'YAML'
		# anki_version: 9.9.9
		# renovate: datasource=docker depName=ghcr.io/luckyturtledev/anki versioning=loose
		anki_version: "26.08"
		anki_container_image_tag: "{{ anki_version }}"
		anki_container_image_self_build_repo_version: "{{ anki_version if anki_version != 'latest' else 'main' }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v25.02-0 v25.02-1 v25.02-2 v25.02.6-0 v26.08-0; do
		git tag "$tag"
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

bump_patch="sed -i 's|^anki_version: \"26.08\"|anki_version: \"26.08.1\"|' defaults/main.yml"
revert_patch="sed -i 's|^anki_version: \"26.08.1\"|anki_version: \"26.08\"|' defaults/main.yml"
bump_to_released="sed -i 's|^anki_version: \"26.08\"|anki_version: \"25.02\"|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v26.08.1-0 "$(merge "$bump_patch")"
expect 'task edit'    v26.08.1-1 "$(merge "$edit_task")"
expect 'template'     v26.08.1-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v26.08-1   "$(merge "$edit_task")"
expect 'version bump' v26.08.1-0 "$(merge "$bump_patch")"

# `v25.02-2` and `v25.02.6-0` exist in every scenario. A three-component version
# must not continue the counter of the two-component one it starts with, and
# vice versa.
scenario 'Two- and three-component versions with overlapping prefixes'
expect 'back to a released two-component version' v25.02-3 "$(merge "$bump_to_released")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'meta'     v26.08-1   "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 1 2 3 4 5 6 7 8 9 10; do
	git tag "v26.08-$release_number"
done
expect 'a task' v26.08-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_patch" > /dev/null
# The role is now identical to what v26.08-0 already published, so there is
# nothing new to release.
expect 'a revert' ''       "$(merge "$revert_patch")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_patch" > /dev/null
expect 'a revert' v26.08-1 "$(merge "$revert_patch && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
