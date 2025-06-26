# uvenv
Powershell script to download [uv](https://docs.astral.sh/uv/), set up pyenv with uv, all specified in local pyproject.toml

## Usage
`setup_envuv.ps1` is a Powershell script that performs the following:
- if environment directory doesn't exist, mkdir and download uv (specified by version in cmdline args) to env dir
- Change current shell's environment vars to point to newly downloaded uv
- Using newly downloaded uv, download the version of python (locally to environment dir) specified in the `pyproject.toml` local to where you're calling the script from
- Create virtual env from uv-installed python binary, add to PATH for current shell
- Run `uv sync`, which installs all packages listed in pyproject.toml
- If env dir exists, then update PATH to point to uv and venv that have already been installed from a previous run of the script.

## Notes
- To help with project organization and reuse, this script supports being located in another directory from where it's being called.
- `env.ps1` is an example user script used to call the `setup_envuv.ps1` script. Or the `setup_envuv.ps1` script can be called directly.

```
include/
  envuv/
    setup_envuv.ps1
  mylib/ # local python lib implemented as a pip package
    __init__.py
    pyproject.toml
    src/
      mylib.py
  scripts/ # local python scripts
    myscript1.py
    myscript2.py
myproj/
  env.ps1 # File contents: ../include/envuv/setup_envuv.ps1 -incdir ../include/scripts # include in PYTHONPATH so can be imported in scripts using this python
  pyproject.toml # lists all required packages
  test_mytest.py # pytest file
```

Example pyproject.toml:
```
[project]
    name = "myproj"
    description = "Example project demonstrating uvenv setup: myproj"
    readme = "README.md"
    requires-python = "==3.12.1" # whatever python version you want
    version = "1.0.0"
    dependencies = [
        "mylib>=1.0.0",
        "pytest-html>=4.1.1",
        "pytest>=8.3.4",
    ]

[tool.uv.workspace] # uv supports installing local python source implemented as pip packages:
    members = [
        "../include/mylib",
    ]

[tool.uv.sources]
    mylib = { workspace = true }
```
