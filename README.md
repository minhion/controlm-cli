> **⚠️ Disclaimer**  
> This Docker image is **provided as-is** and **intended for community use only**.  
> It is **not officially supported by BMC Software** and comes **with no warranty**, use entirely **at your own risk**.  
> You are solely responsible for ensuring compliance with all applicable software licensing agreements before using this image in your environment.  
>  
> Created and shared for the community by [Minh Nguyen](https://www.linkedin.com/in/mnguyen92/).

# Control-M CLI + Agent Provisioning Support (Ubuntu 24.04 + JDK 25)

This Docker image provides a ready-to-use environment for **Control-M CLI** with **Control-M Agent** provisioning support.  
It’s based on **Ubuntu 24.04** and includes **Temurin JDK 25** for provisioning Control-M agent and plugins.

[Docker Repo](https://hub.docker.com/r/minhion/controlm-cli)

To provision a Control-M agent, follow the following guide after running the container. [https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm](https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm)

---

## 🚀 Features
- **Ubuntu 24.04 LTS** base image
- **Temurin JDK 25 LTS** included
- **Python:** 3.x (installed via system package; venv-ready)
- **Control-M CLI** pre-installed inside a Python virtual environment
- Ready for **Control-M Agent** provisioning
- Ideal for automation in CI/CD pipelines

---

## ⚙️ Environment Variables

| Variable         | Required | Description |
|------------------|----------|-------------|
| `CTM_ENDPOINT`   | ✅       | Control-M Automation API endpoint (e.g., On-Premise `https://<controlmEndPointHost>:8443/automation-api` or SaaS `https://tenant-123-aapi.prod.controlm.com/automation-api` ) |
| `CTM_API_TOKEN`  | ✅       | API token for authenticating with Control-M |
| `CTM_ENV_NAME`   | ✅       | Environment Name |

---

## 🛠 Usage

### Run Control-M CLI container
```bash
docker run \
  -e CTM_ENDPOINT="https://<your-controlm-host>/automation-api" \
  -e CTM_API_TOKEN="<your-api-token>" \
  -e CTM_ENV_NAME="<your-environment-name>" \
  -it minhion/controlm-cli:22.100
```

### Docker Compose

The following Control-M agent directories must be persisted across container restarts:

| Directory | Purpose |
|-----------|---------|
| `/opt/ctm/backup` | Job backup files |
| `/opt/ctm/capdef` | Capacity planning definitions |
| `/opt/ctm/dailylog` | Daily log files |
| `/opt/ctm/data` | Agent data files |
| `/opt/ctm/measure` | Measurement data |
| `/opt/ctm/onstmt` | On-statement files |
| `/opt/ctm/pid` | Process ID files |
| `/opt/ctm/procid` | Process ID tracking |
| `/opt/ctm/sysout` | Job sysout output |
| `/opt/ctm/status` | Agent status files |
| `/opt/ctm/temp` | Temporary files |
| `/opt/ctm/cm` | Configuration manager files |
| `/home/controlm/se_storage` | Local store for scripts and files brought into the container for job execution |

Create a `.env` file with your credentials:
```env
CTM_ENDPOINT=https://<your-controlm-host>/automation-api
CTM_API_TOKEN=<your-api-token>
CTM_ENV_NAME=default
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
    volumes:
      - ctm_backup:/opt/ctm/backup
      - ctm_capdef:/opt/ctm/capdef
      - ctm_dailylog:/opt/ctm/dailylog
      - ctm_data:/opt/ctm/data
      - ctm_measure:/opt/ctm/measure
      - ctm_onstmt:/opt/ctm/onstmt
      - ctm_pid:/opt/ctm/pid
      - ctm_procid:/opt/ctm/procid
      - ctm_sysout:/opt/ctm/sysout
      - ctm_status:/opt/ctm/status
      - ctm_temp:/opt/ctm/temp
      - ctm_cm:/opt/ctm/cm
      - ctm_se_storage:/home/controlm/se_storage
    stdin_open: true
    tty: true
    restart: unless-stopped

volumes:
  ctm_backup:
  ctm_capdef:
  ctm_dailylog:
  ctm_data:
  ctm_measure:
  ctm_onstmt:
  ctm_pid:
  ctm_procid:
  ctm_sysout:
  ctm_status:
  ctm_temp:
  ctm_cm:
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
    volumes:
      - /your/persistent/path/backup:/opt/ctm/backup
      - /your/persistent/path/capdef:/opt/ctm/capdef
      - /your/persistent/path/dailylog:/opt/ctm/dailylog
      - /your/persistent/path/data:/opt/ctm/data
      - /your/persistent/path/measure:/opt/ctm/measure
      - /your/persistent/path/onstmt:/opt/ctm/onstmt
      - /your/persistent/path/pid:/opt/ctm/pid
      - /your/persistent/path/procid:/opt/ctm/procid
      - /your/persistent/path/sysout:/opt/ctm/sysout
      - /your/persistent/path/status:/opt/ctm/status
      - /your/persistent/path/temp:/opt/ctm/temp
      - /your/persistent/path/cm:/opt/ctm/cm
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
