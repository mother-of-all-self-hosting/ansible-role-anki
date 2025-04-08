<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Anki synchronization server

This is an [Ansible](https://www.ansible.com/) role which installs [a synchronization server](https://github.com/ankitects/anki/tree/main/docs/syncserver) for [Anki](https://apps.ankiweb.net) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Anki is a flashcard program that helps you spend more time on challenging material, and less on what you already know. This role enables to run a self-hosted synchronization server, similar to what AnkiWeb.net offers.

See the project's [documentation](https://docs.ankiweb.net/sync-server.html) to learn what the synchronization server does and why it might be useful to you.

✨ Anki (暗記) means "Memorize" in Japanese.

>[!NOTE]
>
> This role is configured to use [this pre-built Docker image](https://github.com/luckyturtledev/docker-images/pkgs/container/anki) by default. While the image itself is unofficial, it contains the official synchronization server. See [Dockerfile](https://github.com/LuckyTurtleDev/docker-images/blob/main/dockerfiles/anki/Dockerfile) by the author and [this summary](https://github.com/truecharts/public/issues/17318#issue-2092096085) for (a bit complicated) history behind the Docker image.

## Adjusting the playbook configuration

To enable the server with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# anki                                                                 #
#                                                                      #
########################################################################

anki_enabled: true

########################################################################
#                                                                      #
# /anki                                                                #
#                                                                      #
########################################################################
```

### Set the hostname

To enable the server you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
anki_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Set the username and password

You also need to create a user to log in to the instance with a client application. To create one, add the following configuration to your `vars.yml` file. Make sure to replace `YOUR_USERNAME_HERE` and `YOUR_PASSWORD_HERE`.

```yaml
anki_environment_variables_username: YOUR_USERNAME_HERE
anki_environment_variables_password: YOUR_PASSWORD_HERE
```

**Note**: if the username is changed after creating the user, a new user with the specified username will be created by running the installation command, instead of renaming the user.

### Mount a directory for storing data

The service requires a Docker volume to be mounted, so that the directory for storing files is shared with the host machine.

To add the volume, prepare a directory on the host machine and add the following configuration to your `vars.yml` file, setting the directory path to `src`:

```yaml
anki_container_additional_volumes:
  - type: bind
    src: /path/on/the/host
    dst: /data
    options:
```

Make sure permissions of the directory specified to `src` (`/path/on/the/host`).

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `anki_environment_variables_additional_variables` variable

See [here](https://github.com/LuckyTurtleDev/docker-images/blob/main/dockerfiles/anki/README.md) for a complete list of the server's config options that you could put in `anki_environment_variables_additional_variables`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, the synchronization server becomes available at the specified hostname like `https://example.com`.

If using a reverse proxy to provide HTTPS access and serving the instance under a subpath, make sure to include a trailing slash when configuring Anki. See [here](https://docs.ankiweb.net/sync-server.html#reverse-proxies) for more information.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu anki` (or how you/your playbook named the service, e.g. `mash-anki`).
