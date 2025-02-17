# daos-env
## Env
+ Ubuntu 22.04


## Usage
### Install DAOS
```bash
cd <project_dir>
. daosenv $(pwd)
./scripts/install.sh
```

### Run `daos_server` in the foreground (Server Side)
```bash
cd <project_dir>
. daosenv $(pwd)
daos_server start --config=${DAOS_HOME}/conf/daos_server.yml
```

### Run `daos_agent` in the foreground (Client Side)
```bash
cd <project_dir>
. daosenv $(pwd)
daos_agent start --config-path=${DAOS_HOME}/conf/daos_agent.yml
```

### Installation
```bash
# Install DAOS with all dependencies
install-daos

# Force reinstall
install-daos --force
```

### NVMe Management
The following commands are available after initializing the environment:

```bash
# List NVMe devices and their block devices
find_nvme

# Bind/Unbind NVMe devices
bind_nvme -m {vfio|kernel} [-f /path/to/nvme_devices.yml]

# Check NVMe device status
bind_nvme status [-f /path/to/nvme_devices.yml]
```
