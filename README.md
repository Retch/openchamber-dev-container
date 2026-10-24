# openchamber-dev-container

A Fedora based container that runs [OpenChamber](https://getartcraft.com/apps/openchamber)
(the web UI for opencode) together with a configurable selection of the
ArtCraft suite apps.

## Usage

```sh
./run_openchamber_podman.sh
```

OpenChamber then runs in the background on [http://127.0.0.1:3000](http://127.0.0.1:3000).
The UI password can be set with `OPENCHAMBER_UI_PASSWORD`.

## Configuration

Two config files in this directory are read on startup:

| File                   | Purpose                                                             |
| ---------------------- | ------------------------------------------------------------------- |
| `node-versions.conf`   | Node version for opencode and openchamber, plus additional versions |
| `artcraft-apps.conf`   | ArtCraft suite apps to install and register as MCP servers          |

### ArtCraft apps

`artcraft-apps.conf` lists the apps to install. The newest release of each app is
downloaded from its GitHub releases page and installed as an RPM, which puts the
app and its `*-cli` into `/usr/bin`. Every app is then registered as an MCP
server for opencode in `/etc/opencode/opencode.jsonc`, so the tools are
available to agents right after the container starts.

The apps work on the files in `/projects`, which is the `data` directory of this
repository.

```sh
ARTCRAFT_APPS="pdfcraft wordcraft gridcraft"
```
