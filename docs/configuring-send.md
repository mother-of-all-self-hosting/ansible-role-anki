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

# Setting up Anki

This is an [Ansible](https://www.ansible.com/) role which installs [Anki](https://github.com/timvisee/send) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Anki is a fork of Mozilla's discontinued [Firefox Anki](https://github.com/mozilla/send) which allows you to send files to others with a link. Files are end-to-end encrypted so they cannot be read by the server, and also can be protected with a password.

See the project's [documentation](https://github.com/timvisee/send/blob/master/README.md) to learn what Anki does and why it might be useful to you.

## Prerequisites

To run a Anki instance it is necessary to prepare a [Redis](https://redis.io/) server for managing a metadata database.

If you are looking for an Ansible role for Redis, you can check out [this role (ansible-role-redis)](https://github.com/mother-of-all-self-hosting/ansible-role-redis) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team. Note that the team recommends to have a look at [this role (ansible-role-valkey)](https://github.com/mother-of-all-self-hosting/ansible-role-valkey) for [Valkey](https://valkey.io/) instead.

## Adjusting the playbook configuration

To enable Anki with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# send                                                                 #
#                                                                      #
########################################################################

send_enabled: true

########################################################################
#                                                                      #
# /send                                                                #
#                                                                      #
########################################################################
```

### Set the hostname

To enable the Anki you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
send_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting Anki under a subpath (by configuring the `send_path_prefix` variable) does not seem to be possible due to Anki's technical limitations.

### Set variables for connecting to a Redis server

As described above, it is necessary to set up a [Redis](https://redis.io/) server for managing a metadata database of a Anki instance. You can use either KeyDB or Valkey alternatively.

Having configured it, you need to add and adjust the following configuration to your `vars.yml` file, so that  the Anki instance will connect to the server:

```yaml
send_environment_variable_redis_host: YOUR_REDIS_SERVER_HOSTNAME_HERE
send_environment_variable_redis_port: 6379
send_environment_variable_redis_user: ''
send_environment_variable_redis_password: ''
send_environment_variable_redis_db: ''
```

Make sure to replace `YOUR_REDIS_SERVER_HOSTNAME_HERE` with the hostname of your Redis server. If the Redis server runs on the same host as Anki, set `localhost`.

### Configure a storage backend

The service provides these storage backend options: local filesystem (default), Amazon S3 compatible object storage, and Google Cloud Storage.

#### Local filesystem (default)

With the default configuration, the directory for storing files inside the Docker container is set to `/uploads`. You can change it by adding and adjusting the following configuration to your `vars.yml` file:

```yaml
send_environment_variable_file_dir: YOUR_DIRECTORY_HERE
```

**By default this role removes uploaded files when uninstalling the service**. In order to make those files persistent, you need to add a Docker volume to mount in the container, so that the directory for storing files is shared with the host machine.

To add the volume, prepare a directory on the host machine and add the following configuration to your `vars.yml` file, setting the directory path to `src`:

```yaml
send_container_additional_volumes:
  - type: bind
    src: /path/on/the/host
    dst: "{{ send_environment_variable_file_dir }}"
    options:
```

Make sure permissions of the directory specified to `src` (`/path/on/the/host`).

#### Amazon S3 compatible object storage

To use Amazon S3 or a S3 compatible object storage, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
send_storage_backend_option: s3compatible

# Set a S3 bucket name to use
send_environment_variable_S3_bucket: ''

# Set a custom endpoint to use for S3 (defaults to AWS; set if using a S3 compatible storage like Wasabi and Storj)
# send_environment_variable_S3_endpoint: ''

# Control whether to force path style URLs (https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Config.html#s3ForcePathStyle-property) for S3 objects
send_environment_variable_S3_use_path_style_endpoint: false

# Set a S3 access key ID
send_environment_variable_aws_access_key_id: ''

# Set a S3 secret access key ID
send_environment_variable_aws_secret_access_key: ''
```

#### Google Cloud Storage

To use Google Cloud Storage, add and adjust the following configuration to your `vars.yml` file:

```yaml
send_storage_backend_option: gcs

# Set a Google Cloud Storage bucket
send_environment_variable_gcs_bucket: ''
```

Before using it, authentication should be set up with [Application Default Credentials](https://cloud.google.com/docs/authentication/production#auth-cloud-implicit-nodejs).

### Configure upload and download limits (optional)

You can configure settings for uploading and downloading limits by adding the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
# Set maximum upload file size to 1 GB (default: 2 GB, 2147483648 in bytes)
send_environment_variable_max_file_size: 1073741824

# Set maximum upload expiry time to 3 days (default: 7 days, 604800 seconds)
send_environment_variable_max_expire_seconds: 259200

# Set maximum number of downloads to 10 (default: 20)
send_environment_variable_max_downloads: 10

# Comma separated list of expire time options to show in UI dropdown (default: 300, 3600, 86400, 604800)
send_environment_variable_expire_times_seconds: 300, 3600, 86400, {{ send_environment_variable_max_expire_seconds }}

# Comma separated list of download limit options to show in UI dropdown (default: 1, 2, 3, 4, 5, 20)
send_environment_variable_download_counts: 1, 2, 3, 4, 5, {{ send_environment_variable_max_downloads }}
```

> [!NOTE]
>
> The developer recommends to take a precaution to mitigate the risk of your instance being used as a hosting service of illegal contents, such as setting a short expiration time and setting a URL for inquiry based on DMCA.

> Long expiration times are risky on public servers as people may use you as free hosting for copyrighted content or malware (which is why Mozilla shut down their send service). It's advised to only expose your service on a LAN/intranet, password protect it with a proxy/gateway, or make sure to set SEND_FOOTER_DMCA_URL above so you can respond to takedown requests.

<small>Source: [Docker Quickstart](https://github.com/timvisee/send/blob/5124572dba7cac073d85f3e277d647aa3433ea38/docs/docker.md#environment-variables)</small>

To set a URL to the contact page for DMCA requests, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
# default: empty
send_environment_variable_send_footer_dmca_url: ''
```

See [the section about usage](#takedown-illegal-materials) below to check how to takedown an illegal file from the service.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `send_environment_variables_additional_variables` variable

For a complete list of Anki's config options that you could put in `send_environment_variables_additional_variables`, see its [environment variables](https://github.com/timvisee/send/blob/master/docs/docker.md#environment-variables).

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

Anki should be available at the specified hostname like `https://example.com`.

It can be used via [CLI client](https://github.com/timvisee/ffsend). With the client you can upload a file specifying your host with `--host` option as below:

```sh
ffsend upload --host https://example.com YOUR_FILE_PATH_HERE
```

To download the file, you can use `ffsend download` command like below:

```sh
ffsend download https://example.com/#url-to-the-uploaded-file
```

See its [documentation](https://github.com/timvisee/ffsend/blob/master/README.md) for details about how to use the client.

### Takedown illegal materials

When a DMCA compliant was submitted or an abuse was detected, you need to remove the illegal material from the service. You can make the file inaccessible by following the steps below:

1. Take a note of an ID of the file which needs to make inaccessible. The ID is contained in the URL. For example, if the URL is https://example.com/download/fa04ec7f8ce1bc05/#PhQ5XsSkKwcLfaODf9-K3B, the file ID is `fa04ec7f8ce1bc05`.
2. Run a `DEL` command with the file ID from a host with access to the Redis server:

   ```sh
   redis-cli DEL fa04ec7f8ce1bc05
   ```

   If you run a Redis, KeyDB, or Valkey server on a Docker container along with the contaiener for Anki on the same server, you can directly run the command with `docker exec`:

   ```sh
   docker exec -it YOUR_CONTAINER_FOR_REDIS_HERE sh -c "redis-cli DEL fa04ec7f8ce1bc05"
   ```

   Replace `YOUR_CONTAINER_FOR_REDIS_HERE` with the Docker container's name before running the command. For example, if you enable a [Valkey instance with the playbook](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/services/valkey.md) by the MASH project, it should be `mash-valkey` (if is a shared one) or `mash-send-valkey` (if it is a dedicated one).

If the command returns `(integer) 1`, the record for the file has been removed, and the file has become inaccessible.

Also see: https://github.com/timvisee/send/blob/master/docs/takedowns.md

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu send` (or how you/your playbook named the service, e.g. `mash-send`).
