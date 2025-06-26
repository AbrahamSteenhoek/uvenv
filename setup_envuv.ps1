param (
    [switch]$help,
    [string]$ver_uv = "0.7.15",
    [string]$envdir = [System.IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path) + "\wenv"),
    [string[]]$inc
)

if ($help) {
    Write-Host "Usage: .\YourScript.ps1 [-help] [-ver_uv <version>] [-envdir <directory>]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -help        Display this help message."
    Write-Host "  -ver_uv      Version of uv to install. Default is $ver_uv"
    Write-Host "  -envdir      Directory for the local environment setup. Default is the <path-to-setup-script>\wenv"
    exit
}

function Set-FullControlPermissions {
    param (
        [string]$Path  # Path to the directory
    )
    try {
        # Ensure the directory exists
        if (-not (Test-Path -Path $Path -PathType Container)) {
            Write-Host "Directory [$Path] does not exist. Cannot set permissions."
            return
        }
        # Get the current ACL of the directory
        $acl = Get-Acl -Path $Path
        # Create a new access rule for "Everyone"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "Everyone", 
            "FullControl", 
            "ContainerInherit,ObjectInherit", 
            "None", 
            "Allow"
        )
        # Add the access rule to the ACL
        $acl.SetAccessRule($accessRule)
        # Apply the updated ACL to the directory
        Set-Acl -Path $Path -AclObject $acl
        Write-Host "Permissions updated. 'Everyone' now has full control over [$Path]."
    } catch {
        Write-Host "Failed to set permissions on [$Path]. Error: $_"
    }
}

### uv local install ############################################
$uvdir_top = "$envdir\uv"
if (-not (Test-Path -Path $uvdir_top)) {
    Write-Host "Local uv install doesn't exist. Downloading in $uvdir_top ..."
    $env:UV_INSTALL_DIR = $uvdir_top
    $env:UV_NO_MODIFY_PATH = "1"
    try {
        if ($ver_uv -match '^\d+\.\d+\.\d+$') {
            Write-Host "Downloading uv version [$ver_uv] ..."
            powershell -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/$ver_uv/install.ps1 | iex"
        } else {
            Write-Host "Version uv doesn't fit fmt X.X.X. Downloading latest version..."
            powershell -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex"
        }
    } catch {
        Write-Host "Failed to download or install uv. Error: $_"
        exit 1
    }
} else {
    Write-Host "Using existing uv env in [$uvdir_top]"
}
$env:Path = "$uvdir_top;$env:Path"

#################################################################
### py virtualenv local install ############################################
# python venv is labeled after the base directory that the env.ps1 script is located in.
$pyvenv_top = "$envdir\venv-uv"
# TODO: move this to gloabl uv.toml
$env:UV_PROJECT_ENVIRONMENT = $pyvenv_top
$env:UV_CACHE_DIR = "$uvdir_top\cache"
$env:UV_PYTHON_INSTALL_DIR = $uvdir_top
$env:UV_MANAGED_PYTHON = 1

# if venv dir doesn't exist, create it and install python
if (-not (Test-Path -Path $pyvenv_top -PathType Container)) { 
    Write-Host "Virtual env dir [$pyvenv_top] doesn't exist. Creating it now..."
    # 'uv venv' can automatically detect python version from pyproject.toml.
    # Use this instead of manual 'uv python install <ver>' to avoid needing to duplicate python version passed as arg to this script
    try {
        &$uvdir_top\uv venv "$uvdir_top\tmp"
    } catch {
        Write-Host "Failed to create temporary virtual environment. Error: $_"
        exit 1
    }
    # Set-FullControlPermissions -Path "$uvdir_top\tmp"
    Remove-Item -Path "$uvdir_top\tmp" -Recurse -Force

    $pypath = &$uvdir_top\uv python find # since we're using --managed-python, uv should find the version just installed
    $pypath = [System.IO.Path]::GetFullPath($pypath)
    # Run sysconfigpatcher on installed python version
    &$uvdir_top\uvx --from 'git+https://github.com/bluss/sysconfigpatcher' sysconfigpatcher $pypath
    # now that right python is installed and sysconfigpatched, create real venv to use
    try {
        &$uvdir_top\uv venv -p $pypath $pyvenv_top
    } catch {
        Write-Host "Failed to create temporary virtual environment. Error: $_"
        exit 1
    }
} else {
    Write-Host "Using existing python uv venv in [$pyvenv_top]"
}

############################################################################
# Activate the virtual environment
&$pyvenv_top\Scripts\activate.ps1


############################################################################
# Define the folders to add to PYTHONPATH
$default_inc_paths = @(
    [System.IO.Path]::Combine($PSScriptRoot, "."), # Add include dirs to append to PYTHONPATH here...
)
# Combine default paths, additional paths, and user-provided paths
$inc_dirs = $default_inc_paths + $inc
# Combine the additional paths into a single string
$append_pythonpath = $inc_dirs -join ";"
$env:PYTHONPATH = "$append_pythonpath;$env:PYTHONPATH"

############################################################################
# sync python packages to local pyproject.toml
&$uvdir_top\uv sync
## Double sync here because first sync creates all files with default admin permissions. Second sync resets permissions on all files in uv/...
## Needed because requires admin privileges to delete otherwise: rmdir /s /q wenv
&$uvdir_top\uv sync *> $null
