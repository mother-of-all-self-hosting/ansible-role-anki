# SPDX-FileCopyrightText: 2023 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# show help by default
default:
    @just --list --justfile {{ justfile() }}

lint:
    ansible-lint .
