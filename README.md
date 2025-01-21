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
daos_agent start --config=${DAOS_HOME}/conf/daos_agent.yml
```
