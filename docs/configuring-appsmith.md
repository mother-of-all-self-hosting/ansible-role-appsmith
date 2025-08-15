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
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Appsmith

This is an [Ansible](https://www.ansible.com/) role which installs [Appsmith](https://www.appsmith.com) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Appsmith is an open-source platform that enables developers to build and deploy custom internal tools and applications without writing code.

See the project's [documentation](https://docs.appsmith.com/) to learn what Appsmith does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Appsmith with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# appsmith                                                             #
#                                                                      #
########################################################################

appsmith_enabled: true

########################################################################
#                                                                      #
# /appsmith                                                            #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Appsmith you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
appsmith_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting Appsmith under a subpath (by configuring the `appsmith_path_prefix` variable) does not seem to be possible due to Appsmith's technical limitations.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `appsmith_environment_variables_additional_variables` variable

## Installing

It is recommended to install Appsmith with public registration enabled at first, create your user account, and disable public registration unless you need it.

By default, public registration on the instance is disabled. You can enable it by adding the following configuration to your `vars.yml` file:

```yaml
appsmith_environment_variable_appsmith_signup_disabled: false
```

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

To disable public registration, remove the configuration and re-run the same command.

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, the Appsmith instance becomes available at the URL specified with `appsmith_hostname`. With the configuration above, the service is hosted at `https://example.com`.

To get started, open the URL with a web browser, and create the first user from the web interface.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu appsmith` (or how you/your playbook named the service, e.g. `mash-appsmith`).
