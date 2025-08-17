> **⚠️ Disclaimer**  
> This Docker image is **provided as-is** and **intended for community use only**.  
> It is **not officially supported by BMC Software** and comes **with no warranty**, use entirely **at your own risk**.  
> You are solely responsible for ensuring compliance with all applicable software licensing agreements before using this image in your environment.  
>  
> Created and shared for the community by [Minh Nguyen](https://www.linkedin.com/in/mnguyen92/).

# Control-M CLI + Agent Provisioning Support (Ubuntu 22.04 + JDK 21)

This Docker image provides a ready-to-use environment for **Control-M CLI** with **Control-M Agent** provisioning support.  
It’s based on **Ubuntu 22.04** and includes **Temurin JDK 21** for provisioning Control-M agent and plugins.

[Docker Repo](https://hub.docker.com/r/minhion/controlm-cli)

To provision a Control-M agent, follow the following guide after running the container. [https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm](https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Services_ProvisionService.htm)

---

## 🚀 Features
- **Ubuntu 22.04 LTS** base image
- **Temurin JDK 21** included 
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
  -it minhion/controlm-cli:22
```

### Tags
22 → Ubuntu 22.04 + JDK 21 + Control-M CLI

### 📄 License
BMC Control-M CLI and Agent are subject to BMC Software license terms.
You must have a valid Control-M license to use this image with Control-M environments.
