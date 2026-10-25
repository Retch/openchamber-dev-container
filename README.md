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

## Inside the image

`run_openchamber_podman.sh` rebuilds the image on every start, so everything in
it is decided at build time:

- **Base packages** (always): curl, git, tar, gzip, bzip2, procps-ng, libatomic
- **Node** via nvm: `NODE_VERSION` is the default version for opencode and
  openchamber, `EXTRA_NODE_VERSIONS` installs more. `nvm use <version>` switches,
  and a `.nvmrc` in a project directory is honored on `cd`.
- **Python** via uv: uv itself is always installed; `PYTHON_VERSION` is the
  default and also backs `UV_PYTHON` and the `python3`/`python` links,
  `EXTRA_PYTHON_VERSIONS` installs more.
- **opencode** and **@openchamber/web**
- **ArtCraft apps** from `artcraft-apps.conf`, registered as MCP servers

Anything else you want preinstalled — further dnf packages, other toolchains,
extra MCP servers — goes into the `Dockerfile` the same way and appears after
the next rebuild.

## Configuration

Three config files in this directory are read on startup:

| File                   | Purpose                                                             |
| ---------------------- | ------------------------------------------------------------------- |
| `node-versions.conf`   | Node version for opencode and openchamber, plus additional versions |
| `python-versions.conf` | Default python version for uv, plus additional versions             |
| `artcraft-apps.conf`   | ArtCraft suite apps to install and register as MCP servers          |

### Python (uv)

`python-versions.conf` selects the Python versions uv installs:

```sh
PYTHON_VERSION="3.13"
EXTRA_PYTHON_VERSIONS=""
```

`PYTHON_VERSION` is the default: it backs `UV_PYTHON`, `python3` and `python`.
uv works on the files in `/projects` right away (`uv run`, `uv sync`,
`uv pip`, `uv tool install`), and `uv python install <version>` fetches further
versions at runtime.

### ArtCraft apps

`artcraft-apps.conf` lists the apps to install. The newest release of each app is
downloaded from its GitHub releases page and installed as an RPM, which puts the
app and its `*-cli` into `/usr/bin`. Every app is then registered as an MCP
server for opencode in `/etc/opencode/opencode.jsonc`, so the tools are
available to agents right after the container starts.

The apps work on the files in `/projects`, which is the `projects` directory of
this repository.

```sh
ARTCRAFT_APPS="pdfcraft wordcraft gridcraft"
```

### MCP templates

The MCP entries are generated from `artcraft_mcp_templates/`, so they stay
adjustable instead of living in a script. A template is the JSON object of one
MCP server:

- `default.jsonc` is used for every app without a template of its own
- `<app>.jsonc` replaces the default for exactly this app

`__APP__` and `__APP_CLI__` are replaced with the app name and its CLI. A
template has to start with `{` and end with `}`; comments in between are fine.

`artcraft_mcp_templates/pdfcraft.jsonc` for example gives pdfcraft its own
`--root`, while the other apps fall back to the default without one:

```jsonc
{
  "type": "local",
  "command": ["pdfcraft-cli", "mcp", "--root", "/projects"]
}
```

The templates are read when the image is built, so rerun
`./run_openchamber_podman.sh` after changing one.
