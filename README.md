> **⚠️ Disclaimer**  
> This Docker image is **provided as-is** and **intended for community use only**.  
> It is **not officially supported by BMC Software** and comes **with no warranty**, use entirely **at your own risk**.  
> You are solely responsible for ensuring compliance with all applicable software licensing agreements before using this image in your environment.  
>  
> Created and shared for the community by [Minh Nguyen](https://www.linkedin.com/in/mnguyen92/).

# Control-M CLI + Agent Provisioning Support (Ubuntu 24.04 + JDK 25)

This Docker image provides a ready-to-use environment for **Control-M CLI** with **Control-M Agent** provisioning support.  
It's based on **Ubuntu 24.04** and includes **Temurin JDK 25 LTS** for provisioning Control-M agent and plugins.

[Docker Repo](https://hub.docker.com/r/minhion/controlm-cli)

To provision a Control-M agent, follow the following guide after running the container. [https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm](https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm)

---

## 🚀 Features
- **Ubuntu 24.04 LTS** base image
- **Temurin JDK 25 LTS** included
- **Python:** 3.x (installed via system package; venv-ready)
- **Control-M CLI** pre-installed inside a Python virtual environment
- **Control-M Agent** provisioned automatically on first container start
- Ready for **Control-M Agent** provisioning
- Ideal for automation in CI/CD pipelines

---

## ⚙️ Environment Variables

| Variable          | Required | Description |
|-------------------|----------|-------------|
| `CTM_ENDPOINT`    | ✅       | Control-M Automation API endpoint (e.g., On-Premise `https://<controlmEndPointHost>:8443/automation-api` or SaaS `https://tenant-123-aapi.prod.controlm.com/automation-api`) |
| `CTM_API_TOKEN`   | ✅       | API token for authenticating with Control-M |
| `CTM_ENV_NAME`    | ✅       | Environment name (default: `default`) |
| `CTM_AGENT_TAG`   | ✅       | Agent tag name used for provisioning (required on first start) |
| `CTM_AGENT_NAME`  | ❌       | Optional display name for the agent |

---

## 🛠 Usage

### Run Control-M CLI container
```bash
docker run \
  -e CTM_ENDPOINT="https://<your-controlm-host>/automation-api" \
  -e CTM_API_TOKEN="<your-api-token>" \
  -e CTM_ENV_NAME="<your-environment-name>" \
  -e CTM_AGENT_TAG="<your-agent-tag>" \
  -it minhion/controlm-cli:22.100
```

### Docker Compose

The following Control-M agent directories are persisted across container restarts.  
All directories live under `/opt/ctm/ctm/` and are pre-created in the image with `controlm:controlm` ownership so named volumes inherit the correct permissions on first creation.

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

Create a `.env` file with your credentials:
```env
CTM_ENDPOINT=https://<your-controlm-host>/automation-api
CTM_API_TOKEN=<your-api-token>
CTM_ENV_NAME=default
CTM_AGENT_TAG=<your-agent-tag>
CTM_AGENT_NAME=<optional-agent-name>
```

Then run:
```bash
docker compose up -d
docker compose exec ctm-cli bash
```

#### Named Volumes (recommended)

`docker-compose.yml`:
```yaml
services:
  ctm-cli:
    image: minhion/controlm-cli:22.100
    environment:
      CTM_ENDPOINT: "${CTM_ENDPOINT}"
      CTM_API_TOKEN: "${CTM_API_TOKEN}"
      CTM_ENV_NAME: "${CTM_ENV_NAME:-default}"
      CTM_AGENT_TAG: "${CTM_AGENT_TAG}"
      CTM_AGENT_NAME: "${CTM_AGENT_NAME:-}"
    volumes:
      - ctm_alert:/opt/ctm/ctm/alert
      - ctm_backup:/opt/ctm/ctm/backup
      - ctm_capdef:/opt/ctm/ctm/capdef
      - ctm_cfg_backup:/opt/ctm/ctm/cfg_backup
      - ctm_cm:/opt/ctm/ctm/cm
      - ctm_dailylog:/opt/ctm/ctm/dailylog
      - ctm_data:/opt/ctm/ctm/data
      - ctm_measure:/opt/ctm/ctm/measure
      - ctm_metric:/opt/ctm/ctm/metric
      - ctm_onstmt:/opt/ctm/ctm/onstmt
      - ctm_pid:/opt/ctm/ctm/pid
      - ctm_procid:/opt/ctm/ctm/procid
      - ctm_proclog:/opt/ctm/ctm/proclog
      - ctm_runtime:/opt/ctm/ctm/runtime
      - ctm_scripts:/opt/ctm/ctm/scripts
      - ctm_status:/opt/ctm/ctm/status
      - ctm_svrlocks:/opt/ctm/ctm/svrlocks
      - ctm_sysout:/opt/ctm/ctm/sysout
      - ctm_temp:/opt/ctm/ctm/temp
      - ctm_se_storage:/home/controlm/se_storage
    stdin_open: true
    tty: true
    restart: unless-stopped

volumes:
  ctm_alert:
  ctm_backup:
  ctm_capdef:
  ctm_cfg_backup:
  ctm_cm:
  ctm_dailylog:
  ctm_data:
  ctm_measure:
  ctm_metric:
  ctm_onstmt:
  ctm_pid:
  ctm_procid:
  ctm_proclog:
  ctm_runtime:
  ctm_scripts:
  ctm_status:
  ctm_svrlocks:
  ctm_sysout:
  ctm_temp:
  ctm_se_storage:
```

#### Bind Mounts (use when you need direct host access to agent files)

```yaml
services:
  ctm-cli:
    image: minhion/controlm-cli:22.100
    environment:
      CTM_ENDPOINT: "${CTM_ENDPOINT}"
      CTM_API_TOKEN: "${CTM_API_TOKEN}"
      CTM_ENV_NAME: "${CTM_ENV_NAME:-default}"
      CTM_AGENT_TAG: "${CTM_AGENT_TAG}"
      CTM_AGENT_NAME: "${CTM_AGENT_NAME:-}"
    volumes:
      - /your/persistent/path/alert:/opt/ctm/ctm/alert
      - /your/persistent/path/backup:/opt/ctm/ctm/backup
      - /your/persistent/path/capdef:/opt/ctm/ctm/capdef
      - /your/persistent/path/cfg_backup:/opt/ctm/ctm/cfg_backup
      - /your/persistent/path/cm:/opt/ctm/ctm/cm
      - /your/persistent/path/dailylog:/opt/ctm/ctm/dailylog
      - /your/persistent/path/data:/opt/ctm/ctm/data
      - /your/persistent/path/measure:/opt/ctm/ctm/measure
      - /your/persistent/path/metric:/opt/ctm/ctm/metric
      - /your/persistent/path/onstmt:/opt/ctm/ctm/onstmt
      - /your/persistent/path/pid:/opt/ctm/ctm/pid
      - /your/persistent/path/procid:/opt/ctm/ctm/procid
      - /your/persistent/path/proclog:/opt/ctm/ctm/proclog
      - /your/persistent/path/runtime:/opt/ctm/ctm/runtime
      - /your/persistent/path/scripts:/opt/ctm/ctm/scripts
      - /your/persistent/path/status:/opt/ctm/ctm/status
      - /your/persistent/path/svrlocks:/opt/ctm/ctm/svrlocks
      - /your/persistent/path/sysout:/opt/ctm/ctm/sysout
      - /your/persistent/path/temp:/opt/ctm/ctm/temp
      - /your/persistent/path/se_storage:/home/controlm/se_storage
    stdin_open: true
    tty: true
    restart: unless-stopped
```

### Tags
Docker image tags mirror the Control-M agent version (major version `9.0` dropped):

`22.100` → Control-M Agent 9.0.22.100 · Ubuntu 24.04 · JDK 25 LTS  
`latest` → always points to the most recent release

### 📄 License
BMC Control-M CLI and Agent are subject to BMC Software license terms.  
You must have a valid Control-M license to use this image with Control-M environments.
