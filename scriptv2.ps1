<#
.SYNOPSIS
    Creates a predefined multi-level subfolder structure within StabilityMatrix's main 'models' directory,
    with an interactive selection menu for base model types.

.DESCRIPTION
    This script is designed to be run from the root of your StabilityMatrix installation (e.g., X:\stabilitymatrix\).
    It will create specific subfolders for base model types within 'models\StableDiffusion\' and 'models\Lora\' directories.
    For WAN, Hunyuan, and SVD checkpoints, it adds further 'I2V' and 'T2V' subdivisions.
    For LoRAs, it creates nested subfolders (e.g., 'Character', 'Style', 'Motion', 'Behaviors') within each base model type folder.

    By default, this script runs in DRY RUN mode, only logging proposed folder creations without actually creating them.
    Use the -LiveRun flag to perform actual directory creation.

    If the -SelectedBaseModelTypes parameter is not provided, an interactive console menu will appear,
    allowing the user to select which base model types to create folders for using arrow keys and spacebar.

.PARAMETER StabilityMatrixPath
    The root path of your StabilityMatrix installation. Defaults to the current directory if not specified.

.PARAMETER LiveRun
    If specified, the script will perform actual directory creation.
    DO NOT use this flag without first running a dry run to review proposed changes.

.PARAMETER SelectedBaseModelTypes
    An array of strings specifying which base model types to create folders for.
    If not provided, an interactive menu will be displayed for selection.
    Example: -SelectedBaseModelTypes "SDXL", "WAN", "Pony"

.EXAMPLE
    # Run a dry run from the StabilityMatrix root (default behavior), then interactively select types
    .\Create-StabilityMatrixModelFolders-Detailed.ps1

.EXAMPLE
    # Run a dry run and only create folders for SDXL and WAN (skips interactive menu)
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -SelectedBaseModelTypes "SDXL", "WAN"

.EXAMPLE
    # Perform the actual folder creation for all types (after interactive selection or if -SelectedBaseModelTypes is omitted)
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -LiveRun

.EXAMPLE
    # Perform the actual folder creation for specific types (skips interactive menu)
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -LiveRun -SelectedBaseModelTypes "SD15", "Hunyuan"

.NOTES
    Author: Gemini (Google)
    Version: 2.0
    Date: 2025-07-29
    This script only creates directories and does not affect existing files.
    Remember to manually sort your files into these new subfolders or use a separate script for moving.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$StabilityMatrixPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [switch]$LiveRun,

    [Parameter(Mandatory=$false)]
    [string[]]$SelectedBaseModelTypes
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

#region Interactive Selection Function
function Invoke-InteractiveSelection {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Options,

        [Parameter(Mandatory=$false)]
        [string]$Prompt = "Select items (Space to toggle, Enter to confirm):",

        [Parameter(Mandatory=$false)]
        [int]$DefaultSelectedCount = 0 # Number of items to be selected by default (from top)
    )

    $selectedIndices = @{} # Use a hashtable for efficient lookup of selected items
    $currentIndex = 0
    $topLine = [Console]::CursorTop # Store the starting line for redrawing

    # Pre-select default items
    for ($i = 0; $i -lt $DefaultSelectedCount -and $i -lt $Options.Count; $i++) {
        $selectedIndices[$i] = $true
    }

    function DrawMenu {
        param($CurrentIndex, $SelectedIndices, $Options, $TopLine, $PromptText)

        [Console]::SetCursorPosition(0, $TopLine) # Move cursor to the start of the menu area
        Write-Host $PromptText -ForegroundColor Yellow

        for ($i = 0; $i -lt $Options.Count; $i++) {
            [Console]::SetCursorPosition(0, $TopLine + 1 + $i) # Position for each option
            $isSelected = $selectedIndices.ContainsKey($i) # Check if current item is selected
            $prefix = if ($isSelected) { "[X]" } else { "[ ]" }
            $color = if ($i -eq $CurrentIndex) { "Green" } else { "White" }

            # Clear line before writing to prevent artifacts from longer previous lines
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop) # Reset cursor to start of cleared line

            Write-Host "$prefix $($Options[$i])" -ForegroundColor $color
        }
        # Clear any lines below the menu if previous draws were longer
        for ($i = $Options.Count; $i -lt ([Console]::WindowHeight - ($TopLine + 1)); $i++) {
            [Console]::SetCursorPosition(0, $TopLine + 1 + $i)
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
        }
        [Console]::SetCursorPosition(0, $TopLine + 1 + $CurrentIndex) # Set cursor back to current item for next input
    }

    # Initial draw
    DrawMenu $currentIndex $selectedIndices $Options $topLine $Prompt

    while ($true) {
        $key = [Console]::ReadKey($true) # Read key, don't display it

        switch ($key.Key) {
            "UpArrow" {
                $currentIndex = ($currentIndex - 1 + $Options.Count) % $Options.Count
            }
            "DownArrow" {
                $currentIndex = ($currentIndex + 1) % $Options.Count
            }
            "Spacebar" {
                if ($selectedIndices.ContainsKey($currentIndex)) {
                    $selectedIndices.Remove($currentIndex)
                } else {
                    $selectedIndices[$currentIndex] = $true
                }
            }
            "Enter" {
                break # Exit loop
            }
            "Escape" {
                # Optionally, clear selections or exit without selecting
                $selectedIndices.Clear()
                break
            }
        }
        DrawMenu $currentIndex $selectedIndices $Options $topLine $Prompt # Redraw after key press
    }

    # Clear the menu area after selection is done
    for ($i = 0; $i -lt ($Options.Count + 1); $i++) {
        [Console]::SetCursorPosition(0, $topLine + $i)
        Write-Host (" " * [Console]::WindowWidth) -NoNewline
    }
    [Console]::SetCursorPosition(0, $topLine) # Reset cursor to the top of where the menu was

    # Return selected options as string array
    $result = @()
    foreach ($index in $selectedIndices.Keys | Sort-Object) {
        $result += $Options[$index]
    }
    return $result
}
#endregion

Write-Log "Starting detailed folder structure creation script for StabilityMatrix."
Write-Log "StabilityMatrix Root Path: $StabilityMatrixPath"
if ($IsDryRun) {
    Write-Log "Running in DRY RUN mode. No directories will be created.", "WARN"
} else {
    Write-Log "Running in LIVE mode. Directories WILL be created. Proceed with caution!", "WARN"
}

# Define the base paths for models within StabilityMatrix's main 'models' folder
$dataModelsPath = Join-Path -Path $StabilityMatrixPath -ChildPath "models"
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

# Define the full list of base model types for top-level folders
$allBaseModelTypes = @(
    "Flux",
    "Hunyuan",
    "Illustrious",
    "NooB_AI",
    "Pony",
    "SD15",
    "SD2x",
    "SDXL",
    "SSD1B",
    "SVD",
    "WAN"
) | Sort-Object # Alphabetized

# Determine which base model types to process based on user selection
if ($SelectedBaseModelTypes) {
    # Filter $allBaseModelTypes to only include those specified by the user from command line
    $baseModelTypesToProcess = $allBaseModelTypes | Where-Object { $_ -in $SelectedBaseModelTypes }
    if ($baseModelTypesToProcess.Count -eq 0) {
        Write-Log "No valid base model types selected from the predefined list via -SelectedBaseModelTypes parameter. Please check your input. No folders will be created.", "ERROR"
        exit 1
    }
    Write-Log "Processing only selected base model types (from parameter): $($baseModelTypesToProcess -join ', ')"
} else {
    # If no parameter is provided, invoke the interactive selection menu
    Write-Log "No specific base model types selected via parameter. Launching interactive selection..."
    $baseModelTypesToProcess = Invoke-InteractiveSelection -Options $allBaseModelTypes -Prompt "Select base model types to create folders for (Space to toggle, Enter to confirm):"
    if ($baseModelTypesToProcess.Count -eq 0) {
        Write-Log "No base model types were selected in the interactive menu. No folders will be created.", "INFO"
        exit 0
    }
    Write-Log "Selected base model types (from interactive menu): $($baseModelTypesToProcess -join ', ')"
}


# Define common LoRA sub-categories
# 'Motion' is for scene/camera movement (e.g., POV driving)
# 'Behaviors' is for character-specific movement (e.g., twirl in a skirt)
$loraSubCategories = @(
    "Behaviors",
    "Characters",
    "Concepts",
    "Motion",
    "Other",
    "Styles",
    "Utility_Enhancers"
) | Sort-Object # Alphabetized

# --- Create subfolders within StableDiffusion directory (for main checkpoints) ---
Write-Log "Creating top-level base model folders within: $stableDiffusionDir"
foreach ($folderName in $baseModelTypesToProcess) { # Use $baseModelTypesToProcess here
    $targetPath = Join-Path -Path $stableDiffusionDir -ChildPath $folderName
    if (-not (Test-Path $targetPath)) {
        Write-Log "Proposed: Creating directory: $targetPath"
        if (-not $IsDryRun) {
            New-Item -Path $targetPath -ItemType Directory | Out-Null
        }
    } else {
        Write-Log "Directory already exists: $targetPath"
    }

    # Special handling for WAN, Hunyuan, and SVD to add I2V/T2V subfolders
    if ($folderName -eq "WAN" -or $folderName -eq "Hunyuan" -or $folderName -eq "SVD") {
        $videoSubTypes = @("I2V", "T2V")
        foreach ($subType in $videoSubTypes) {
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
# This 'Unsorted' folder is always created regardless of selected base model types
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
foreach ($baseType in $baseModelTypesToProcess) { # Use $baseModelTypesToProcess here
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
# This 'Unsorted' folder is always created regardless of selected base model types
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
