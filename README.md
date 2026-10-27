> **⚠️ Disclaimer**  
> This Docker image is **provided as-is** and **intended for community use only**.  
> It is **not officially supported by BMC Software** and comes **with no warranty**, use entirely **at your own risk**.  
> You are solely responsible for ensuring compliance with all applicable software licensing agreements before using this image in your environment.  
>  
> Created and shared for the community by [Minh Nguyen](https://www.linkedin.com/in/mnguyen92/).

# Control-M CLI + Agent Provisioning Support (AlmaLinux 9 + JDK 25)

A ready-to-use container for the **Control-M CLI** (Automation API) that can also provision a **Control-M Agent** and **plugins** on first start.  
It's based on **AlmaLinux 9** (RHEL-compatible) and includes **Temurin JDK 25 LTS**, which the Provision service needs to install the agent and plugins.

[Docker Hub](https://hub.docker.com/r/minhion/controlm-cli) · [GitHub](https://github.com/minhion/controlm-cli)

<!-- README.md is the source of truth; it is pushed to Docker Hub automatically on every change to main. -->

---

## 📑 Contents

- [Features](#-features)
- [Quick start](#-quick-start)
- [Environment variables](#%EF%B8%8F-environment-variables)
- [Agent provisioning](#-agent-provisioning)
- [Plugins](#-plugins)
- [Verifying the container](#-verifying-the-container)
- [Startup behaviour](#-startup-behaviour)
- [Persistent volumes](#-persistent-volumes)
- [Requirements](#-requirements)
- [Troubleshooting](#-troubleshooting)
- [Building the image](#%EF%B8%8F-building-the-image)
- [Tags](#-tags) · [Changelog](#-changelog) · [License](#-license)

---

## 🚀 Features

- **AlmaLinux 9** base image (`ALMA_VERSION` build arg)
- **Temurin JDK 25 LTS** from the Adoptium RPM repository
- **Python 3** (system package) with the CLI in a virtual environment
- **Control-M CLI** pre-installed and on `PATH`
- **Control-M Agent** provisioned on first start, for Helix Control-M (`ctm provision saas::install`) or self-hosted Control-M (`ctm provision agent::install`)
- Agent image defaults to **`Agent_Alma.Linux`**
- **Plugins** deployed automatically after the agent when `CTM_DEPLOY_PLUGINS=true`
- **Restart-safe:** the CLI environment is refreshed on every start, the agent is started again after a container restart, and plugins are deployed only once
- Suited to automation in CI/CD pipelines

The container runs in one of two modes:

| Mode | When | What it does |
|------|------|--------------|
| **CLI-only** | `CTM_AGENT_TAG` unset (or `CTM_AGENT_MODE=none`) | Registers your Control-M environment with the CLI and stays up so you can run `ctm` commands |
| **CLI + Agent** | `CTM_AGENT_TAG` set, or `CTM_AGENT_MODE=agent` | Also provisions a Control-M Agent on first start, then optionally deploys plugins |

---

## ⚡ Quick start

### 1. CLI-only

```bash
docker run -d --name ctm-cli \
  -e CTM_ENDPOINT="https://<tenant>-aapi.<region>.controlm.com/automation-api" \
  -e CTM_API_TOKEN="<your-api-token>" \
  -it minhion/controlm-cli:22.100.2

docker exec -it ctm-cli ctm config servers
```

### 2. CLI + Agent + Plugins with Docker Compose (Helix Control-M)

```bash
git clone https://github.com/minhion/controlm-cli && cd controlm-cli
cp .env.example .env    # then edit .env
```

`.env`:
```env
CTM_ENDPOINT=https://<tenant>-aapi.<region>.controlm.com/automation-api
CTM_API_TOKEN=<your-api-token>
CTM_ENV_NAME=default

CTM_AGENT_TAG=<your-agent-tag>
CTM_AGENT_NAME=<your-agent-name>

# Optional: deploy plugins once the agent is installed
CTM_DEPLOY_PLUGINS=true
CTM_PLUGINS=DataAssurance_plugin.Linux
```

```bash
docker compose up -d
docker compose logs -f              # watch provisioning (several minutes on first start)
docker compose exec ctm-cli bash    # a new shell has the agent environment loaded
ag_diag_comm
```

> Never commit `.env`; it holds your API token. It's already in `.gitignore`.

---

## ⚙️ Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CTM_ENDPOINT` | ✅ | | Automation API endpoint, e.g. Helix `https://<tenant>-aapi.<region>.controlm.com/automation-api` or self-hosted `https://<emHost>:8443/automation-api` |
| `CTM_API_TOKEN` | ✅ | | API token used by the CLI |
| `CTM_ENV_NAME` | | `default` | Name the CLI uses for this environment |
| `CTM_AGENT_MODE` | | `saas` if `CTM_AGENT_TAG` is set, else `none` | `saas`, `agent` or `none` (see [Agent provisioning](#-agent-provisioning)) |
| `CTM_AGENT_IMAGE` | | `Agent_Alma.Linux` | Provision image for the agent. List them with `ctm provision images Linux` |
| `CTM_AGENT_TAG` | `saas` mode | | Agent tag in Helix Control-M |
| `CTM_AGENT_NAME` | | | Agent name (`saas`: host name, `agent`: agent name) |
| `CTM_SERVER` | | | `agent` mode: Control-M/Server to connect the agent to |
| `CTM_AGENT_PORT` | | | `agent` mode: agent port |
| `CTM_AGENT_CONFIG_FILE` | | | Configuration file passed as `-f <file>`. Mount it into the container |
| `CTM_AGENT_REPO` | | | Repository passed as `-r <name>` (self-hosted local repository, see below) |
| `CTM_DEPLOY_PLUGINS` | | `false` | `true` deploys each image in `CTM_PLUGINS` after the agent is installed |
| `CTM_PLUGINS` | | | Comma- or space-separated plugin images, e.g. `DataAssurance_plugin.Linux,AWS_Lambda_plugin.Linux` |

---

## 🤖 Agent provisioning

On first start the entrypoint builds one of these commands from the environment:

```text
CTM_AGENT_MODE=saas   ctm provision saas::install  <CTM_AGENT_IMAGE> <CTM_AGENT_TAG> [CTM_AGENT_NAME]                [-f CTM_AGENT_CONFIG_FILE] [-r CTM_AGENT_REPO]
CTM_AGENT_MODE=agent  ctm provision agent::install <CTM_AGENT_IMAGE> [CTM_SERVER] [CTM_AGENT_NAME] [CTM_AGENT_PORT] [-f CTM_AGENT_CONFIG_FILE] [-r CTM_AGENT_REPO]
```

- **Helix Control-M (SaaS):** set `CTM_AGENT_TAG`; `CTM_AGENT_MODE` defaults to `saas`.  
  Example: `CTM_AGENT_TAG=Admin`, `CTM_AGENT_NAME=my-alma-agent` runs  
  `ctm provision saas::install Agent_Alma.Linux Admin my-alma-agent`.
- **Self-hosted Control-M:** set `CTM_AGENT_MODE=agent` and, optionally, `CTM_SERVER`, `CTM_AGENT_NAME` and `CTM_AGENT_PORT`.  
  The optional positional arguments can't be skipped, so `CTM_AGENT_PORT` requires `CTM_SERVER` and `CTM_AGENT_NAME`; the container refuses to start otherwise.
- **Local repository (`-r`):** for self-hosted environments that serve installation packages from a local repository defined with `ctm provision repository::add <name> <location>`. See BMC's *Control-M Automation API Provisioning* documentation.
- **Other images:** override `CTM_AGENT_IMAGE` (e.g. `Agent_RedHat.Linux`). On this base image `Agent_Alma.Linux` is the matching one.

Reference: BMC [Provision service documentation](https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm).

---

## 🧩 Plugins

Set `CTM_DEPLOY_PLUGINS=true` and list the plugin images in `CTM_PLUGINS`. After the agent is installed, the entrypoint runs, for each one:

```bash
ctm provision image <plugin>
```

- List the available plugins with `ctm provision images Linux` (names end in `_plugin.Linux`).
- Each plugin is deployed once; a marker in `~/.ctm_plugins/` records it.
- A failed plugin is logged as a warning and retried on the next container start, so the agent and CLI stay up.
- Plugins are skipped (with a warning) when no agent is installed.
- To add a plugin later, add it to `CTM_PLUGINS` and run `docker compose up -d`, or run `ctm provision image <plugin>` inside the container.

---

## ✅ Verifying the container

```bash
# CLI connectivity
docker exec -it ctm-cli ctm config servers

# Images available to this tenant (Agent_Alma.Linux, plugins, ...)
docker exec -it ctm-cli ctm provision images Linux

# Agent communication: use a NEW shell so the agent environment is loaded
docker exec -it ctm-cli bash -l -c ag_diag_comm

# Agent status in Control-M
docker exec -it ctm-cli ctm config server:agents::get <server> -s "agent=<agent-name>"

# Installed agent and plugin versions
docker exec -it ctm-cli cat /opt/ctm/installed-versions.txt
```

The agent install writes its environment (`PATH`, `CONTROLM`, `LD_LIBRARY_PATH`) to `~/.bash_profile`. A shell that was already open during the install (for example, a `docker attach` to the original `bash`) won't see it. Open a new shell (`docker exec -it <container> bash`) and agent commands such as `ag_diag_comm`, `start-ag` and `shut-ag` work.

A healthy agent reports `Agent ping to Control-M/Server : Succeeded` and lists the Agent Listener and Tracker as running.

---

## 🔁 Startup behaviour

On every start the entrypoint:

1. **Registers the CLI environment.** Adds `CTM_ENV_NAME` → `CTM_ENDPOINT` and makes it the default.  
   If it already exists (e.g. after `docker restart`), it is deleted and re-added, so a **rotated token or changed endpoint takes effect on the next restart**.  
   Any other failure (bad token, unreachable endpoint) stops the container with the error in its logs.
2. **Provisions or starts the agent.**
   - No agent installed: provisions it as described in [Agent provisioning](#-agent-provisioning). If provisioning fails, the container exits with the error.
   - Agent installed: starts it, because agent processes don't survive a container restart.
   - Agent installed but setup failed (e.g. agent registration was rejected): logs an error and stays up in **CLI-only mode**, instead of re-downloading the agent on every restart. Fix the cause, then run `docker compose up -d --force-recreate`.
3. **Deploys plugins** when `CTM_DEPLOY_PLUGINS=true`.
4. **Runs the container command** (default: `bash`).

Check what happened with `docker logs <container>`.

---

## 💾 Persistent volumes

Agent data directories under `/opt/ctm/ctm/` are pre-created in the image with `controlm:controlm` ownership, so named volumes get the right permissions on first creation. `docker-compose.yml` mounts all of them:

| Directory | Purpose |
|-----------|---------|
| `/opt/ctm/ctm/alert` | Alert files |
| `/opt/ctm/ctm/backup` | Job backup files |
| `/opt/ctm/ctm/capdef` | Capacity planning definitions |
| `/opt/ctm/ctm/cfg_backup` | Configuration backups |
| `/opt/ctm/ctm/cm` | Configuration manager files |
| `/opt/ctm/ctm/dailylog` | Daily log files |
| `/opt/ctm/ctm/data` | Agent data files |
| `/opt/ctm/ctm/measure` | Measurement data |
| `/opt/ctm/ctm/metric` | Metric data |
| `/opt/ctm/ctm/onstmt` | On-statement files |
| `/opt/ctm/ctm/pid` | Process ID files |
| `/opt/ctm/ctm/procid` | Process ID tracking |
| `/opt/ctm/ctm/proclog` | Process log files |
| `/opt/ctm/ctm/runtime` | Runtime files |
| `/opt/ctm/ctm/scripts` | Agent scripts |
| `/opt/ctm/ctm/status` | Agent status files |
| `/opt/ctm/ctm/svrlocks` | Server lock files |
| `/opt/ctm/ctm/sysout` | Job sysout output |
| `/opt/ctm/ctm/temp` | Temporary files |
| `/home/controlm/se_storage` | Local store for scripts and files brought into the container for job execution |

The agent binaries (`/opt/ctm/ctm/exe_*`) live in the container layer, so **recreating** the container (not restarting it) provisions a fresh agent. Remove the old agent from Control-M first, or give the new one a different `CTM_AGENT_NAME`.

To use host directories instead of named volumes, replace each entry, e.g.:

```yaml
    volumes:
      - /your/persistent/path/sysout:/opt/ctm/ctm/sysout
      - /your/persistent/path/se_storage:/home/controlm/se_storage
```

### Multiple Control-M environments

Run one container (or one Compose / Portainer stack) per Automation API endpoint. Give each its own `CTM_ENDPOINT`, `CTM_API_TOKEN` and `CTM_ENV_NAME`, a unique `container_name`, and its own volumes so containers don't share files.

---

## 📋 Requirements

- **CPU / memory:** at least 2 vCPU and 6 GB RAM for the agent (image labels `cpu.required`, `memory.required`).
- **Disk:** the agent download is about 500 MB and its install needs at least **750 MB free under `/opt/ctm`**; each plugin needs about as much again. Make sure Docker's storage (usually `/var/lib/docker`) has a few GB free.
- **Network:** outbound HTTPS to your Automation API endpoint and to the BMC artifact repository the Provision service downloads from.
- **Licensing:** a valid Control-M license.

---

## 🩺 Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `There is not enough available disk space in /opt/ctm` | Free space on the Docker host's storage. See [Requirements](#-requirements) |
| `The Agent on this account already exists in the Control-M environment` | An agent with that name is already registered. Delete it in Control-M Web, or use another `CTM_AGENT_NAME`, then `docker compose up -d --force-recreate` |
| `a previous agent provisioning attempt failed` | The agent was installed but its setup failed. Check `~/BMCINSTALL/log` and `docker logs`, fix the cause, then recreate the container |
| `ag_diag_comm: command not found` | You're in a shell that was opened before the agent installed. Open a new one: `docker exec -it <container> bash` |
| `CTM_AGENT_PORT is set but CTM_SERVER is not` | `agent` mode positional arguments can't be skipped. Set the earlier ones too |
| `WARN: failed to deploy plugin` | See the provision output above it in `docker logs`. The plugin is retried on the next start |
| Container exits right away with `docker run` | It needs a TTY for the default `bash` command: use `-it` (as above) or `tty: true` in Compose |

---

## 🛠️ Building the image

```bash
docker compose build                       # AlmaLinux 9 (default)
ALMA_VERSION=9 docker compose build        # pin the AlmaLinux major version
```

Or with plain Docker:

```bash
docker build --build-arg ALMA_VERSION=9 -t controlm-cli:alma .
```

AlmaLinux 9 is the tested version.

---

## 🏷 Tags

Image tags follow the Control-M agent version (major version `9.0` dropped), with a trailing number for image changes.  
From `22.100.2` the image is based on **AlmaLinux 9**; `22.100.1` and earlier are Ubuntu-based.

| Tag | Contents |
|-----|----------|
| `22.100.2` | Control-M Agent 9.0.22.100 · **AlmaLinux 9** · JDK 25 LTS · `Agent_Alma.Linux`, `saas`/`agent` provisioning modes, optional plugin deployment **(recommended)** |
| `22.100.1` | Last **Ubuntu 24.04** build · Control-M Agent 9.0.22.100 · JDK 25 LTS · restart-safe entrypoint, optional `CTM_AGENT_TAG` |
| `<tag>-<sha>` | The same build pinned to a Git commit; never moves |
| `22.100` | Original 9.0.22.100 build (Ubuntu). Its container goes into a restart loop after any restart and requires `CTM_AGENT_TAG`; use `22.100.1` instead |
| `22` | Legacy 9.0.22 build (Aug 2025); superseded |
| `latest` | Always the most recent release (AlmaLinux from `22.100.2` on) |

For production stacks, pin a specific tag (or a `-<sha>` tag) rather than `latest`.

---

## 📝 Changelog

- **22.100.2:**
  - **Base image switched from Ubuntu 24.04 to AlmaLinux 9.** Pin `22.100.1` to stay on Ubuntu. AlmaLinux 9 base image with Temurin JDK 25 from the Adoptium RPM repository; the agent image defaults to `Agent_Alma.Linux`.
  - New provisioning variables: `CTM_AGENT_MODE` (`saas`/`agent`/`none`), `CTM_AGENT_IMAGE`, `CTM_SERVER`, `CTM_AGENT_PORT`, `CTM_AGENT_CONFIG_FILE` and `CTM_AGENT_REPO`.
  - New `CTM_DEPLOY_PLUGINS` / `CTM_PLUGINS` to deploy plugins after the agent installs.
  - The agent is started again on container restart, and a failed agent setup no longer crash-loops.
- **22.100.1:** Fixed the restart loop (`Environment '<name>' already exists`) when a container restarts. An existing environment is now refreshed so token and endpoint changes apply. `CTM_AGENT_TAG` is optional (CLI-only mode). Added immutable `-<sha>` image tags.
- **22.100:** Agent provisioning on first start, full `/opt/ctm/ctm/` volume layout, pre-created directories with correct ownership.

---

## 📄 License

BMC Control-M CLI and Agent are subject to BMC Software license terms.  
You must have a valid Control-M license to use this image with Control-M environments.
