<#
.SYNOPSIS
    Creates a predefined multi-level subfolder structure within StabilityMatrix's Data\Models directory.

.DESCRIPTION
    This script is designed to be run from the root of your StabilityMatrix installation (e.g., X:\stabilitymatrix\).
    It will create specific subfolders for base model types within 'StableDiffusion' and 'Lora' directories.
    For WAN and Hunyuan checkpoints, it adds further 'I2V' and 'T2V' subdivisions.
    For LoRAs, it creates nested subfolders (e.g., 'Character', 'Style', 'Motion', 'Behaviors') within each base model type folder.

    By default, this script runs in DRY RUN mode, only logging proposed folder creations without actually creating them.
    Use the -LiveRun flag to perform actual directory creation.

.PARAMETER StabilityMatrixPath
    The root path of your StabilityMatrix installation. Defaults to the current directory if not specified.

.PARAMETER LiveRun
    If specified, the script will perform actual directory creation.
    DO NOT use this flag without first running a dry run to review proposed changes.

.EXAMPLE
    # Run a dry run from the StabilityMatrix root (default behavior)
    .\reate-StabilityMatrixModelFolders-Detailed.ps1

.EXAMPLE
    # Run a dry run from a different directory, specifying the StabilityMatrix path
    C:\Scripts\Create-Folders.ps1 -StabilityMatrixPath "D:\MyAI\StabilityMatrix"

.EXAMPLE
    # Perform the actual folder creation (only after a successful dry run review!)
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -LiveRun

.NOTES
    Author: Gemini (Google)
    Version: 1.6
    Date: 2025-07-29
    This script only creates directories and does not affect existing files.
    Remember to manually sort your files into these new subfolders or use a separate script for moving.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$StabilityMatrixPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [switch]$LiveRun # New parameter: specify this to run live
)

# Determine if it's a dry run based on the -LiveRun switch
$IsDryRun = -not $LiveRun

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message"
}

Write-Log "Starting detailed folder structure creation script for StabilityMatrix."
Write-Log "StabilityMatrix Root Path: $StabilityMatrixPath"
if ($IsDryRun) {
    Write-Log "Running in DRY RUN mode. No directories will be created.", "WARN"
} else {
    Write-Log "Running in LIVE mode. Directories WILL be created. Proceed with caution!", "WARN"
}

# Define the base paths for models within StabilityMatrix's Data folder
$dataModelsPath = Join-Path -Path $StabilityMatrixPath -ChildPath "Data\Models"
$stableDiffusionDir = Join-Path -Path $dataModelsPath -ChildPath "StableDiffusion"
$loraDir = Join-Path -Path $dataModelsPath -ChildPath "Lora"

# Check if essential parent directories exist
if (-not (Test-Path $stableDiffusionDir)) {
    Write-Log "Error: StableDiffusion directory not found at '$stableDiffusionDir'. Please check your StabilityMatrix installation path.", "ERROR"
    exit 1
}
if (-not (Test-Path $loraDir)) {
    Write-Log "Error: Lora directory not found at '$loraDir'. Please check your StabilityMatrix installation path.", "ERROR"
    exit 1
}

# Define the base model types for top-level folders
$baseModelTypes = @(
    "SD15",
    "SDXL",
    "Pony",
    "Illustrious",
    "NooB_AI",
    "WAN",
    "Hunyuan",
    "Flux"
)

# Define common LoRA sub-categories
# 'Motion' is for scene/camera movement (e.g., POV driving)
# 'Behaviors' is for character-specific movement (e.g., twirl in a skirt)
$loraSubCategories = @(
    "Characters",
    "Concepts",
    "Styles",
    "Motion",
    "Behaviors",
    "Utility_Enhancers",
    "Other"
)

# --- Create subfolders within StableDiffusion directory (for main checkpoints) ---
Write-Log "Creating top-level base model folders within: $stableDiffusionDir"
foreach ($folderName in $baseModelTypes) {
    $targetPath = Join-Path -Path $stableDiffusionDir -ChildPath $folderName
    if (-not (Test-Path $targetPath)) {
        Write-Log "Proposed: Creating directory: $targetPath"
        if (-not $IsDryRun) {
            New-Item -Path $targetPath -ItemType Directory | Out-Null
        }
    } else {
        Write-Log "Directory already exists: $targetPath"
    }

    # Special handling for WAN and Hunyuan to add I2V/T2V subfolders
    if ($folderName -eq "WAN" -or $folderName -eq "Hunyuan") {
        $wanHunyuanSubTypes = @("I2V", "T2V")
        foreach ($subType in $wanHunyuanSubTypes) {
            $subTargetPath = Join-Path -Path $targetPath -ChildPath $subType
            if (-not (Test-Path $subTargetPath)) {
                Write-Log "Proposed: Creating nested directory: $subTargetPath"
                if (-not $IsDryRun) {
                    New-Item -Path $subTargetPath -ItemType Directory | Out-Null
                }
            } else {
                Write-Log "Nested directory already exists: $subTargetPath"
            }
        }
    }
}
# Add an 'Unsorted' folder for checkpoints that don't fit a specific category
$unsortedCheckpointsPath = Join-Path -Path $stableDiffusionDir -ChildPath "Unsorted"
if (-not (Test-Path $unsortedCheckpointsPath)) {
    Write-Log "Proposed: Creating directory: $unsortedCheckpointsPath"
    if (-not $IsDryRun) {
        New-Item -Path $unsortedCheckpointsPath -ItemType Directory | Out-Null
    }
} else {
    Write-Log "Directory already exists: $unsortedCheckpointsPath"
}


# --- Create multi-level subfolders within Lora directory ---
Write-Log "Creating multi-level LoRA folders within: $loraDir"
foreach ($baseType in $baseModelTypes) {
    $baseTypeLoraPath = Join-Path -Path $loraDir -ChildPath $baseType
    if (-not (Test-Path $baseTypeLoraPath)) {
        Write-Log "Proposed: Creating base type LoRA directory: $baseTypeLoraPath"
        if (-not $IsDryRun) {
            New-Item -Path $baseTypeLoraPath -ItemType Directory | Out-Null
        }
    } else {
        Write-Log "Base type LoRA directory already exists: $baseTypeLoraPath"
    }

    # Now create the sub-categories within each base type LoRA folder
    foreach ($subCategory in $loraSubCategories) {
        $targetPath = Join-Path -Path $baseTypeLoraPath -ChildPath $subCategory
        if (-not (Test-Path $targetPath)) {
            Write-Log "Proposed: Creating nested LoRA directory: $targetPath"
            if (-not $IsDryRun) {
                New-Item -Path $targetPath -ItemType Directory | Out-Null
            }
        } else {
            Write-Log "Nested LoRA directory already exists: $targetPath"
        }
    }
}
# Add an 'Unsorted' folder for LoRAs that don't fit a specific category
$unsortedLorasPath = Join-Path -Path $loraDir -ChildPath "Unsorted"
if (-not (Test-Path $unsortedLorasPath)) {
    Write-Log "Proposed: Creating directory: $unsortedLorasPath"
    if (-not $IsDryRun) {
        New-Item -Path $unsortedLorasPath -ItemType Directory | Out-Null
    }
} else {
    Write-Log "Directory already exists: $unsortedLorasPath"
}


Write-Log "Folder structure creation script completed."
if ($IsDryRun) {
    Write-Log "DRY RUN finished. Review the log above. To perform actual folder creation, run the script with the -LiveRun parameter.", "WARN"
} else {
    Write-Log "LIVE run finished. Please check your model folders; the structure should now be created.", "INFO"
}
