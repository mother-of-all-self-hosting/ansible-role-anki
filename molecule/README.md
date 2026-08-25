<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

There are two testing scenarios available.

### `default`

Tests a standard Anki synchronization server installation.

The server answers `GET /health` with 200 and an empty body however it is configured, and answers everything else with 404, so neither the systemd unit being active (`Restart=always` keeps a crash-looping container's unit active) nor a health check says much on its own. What this scenario checks instead is the sync protocol itself, with [`sync-probe.py`](./sync-probe.py) sending the same requests an Anki client sends:

- logging in with the configured credentials returns a sync key, while a wrong password, an unknown user and a forged sync key are all rejected with 403
- a metadata request over the protocol succeeds, which makes the server create the collection of that user, and the collection turns up as an SQLite database under `anki_data_path` on the host
- the container listens on `anki_container_http_port` rather than on the server's own default, so the probe reaching it at all proves the role's environment file reached the process
- the container mounts both the data directory and the volume configured via `anki_container_additional_volumes_custom`
- the container was created from the image tag `anki_version` pins (read out of `defaults/main.yml`, so that it cannot go stale)

### `upgrade`

Tests what happens to a collection which already exists when the role is upgraded.

The role is installed at an older release first and synced against, so that a collection exists on disk; the role is then run again at the version it pins and the service is restarted onto it. The scenario asserts that the upgraded server still logs the user in, still serves the collection, and that the collection's schema timestamp did not move — a schema migration would move it and force every client to resynchronize from scratch. Finally it stops the service, points the older release at the upgraded data, and asserts that it still reads the collection, which is what says the upgrade is not one-way.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
