<#
.SYNOPSIS
    Creates a predefined multi-level subfolder structure within StabilityMatrix's main 'models' directory.

.DESCRIPTION
    This script is designed to be run from the root of your StabilityMatrix installation (e.g., X:\stabilitymatrix\).
    It will first perform a DRY RUN, logging all proposed folder creations.

    If the -Models, -Categories, or -CustomLoraCategories parameters are provided, it will create specific subfolders
    for the selected base model types and LoRA subcategories.
    For WAN, Hunyuan, and SVD checkpoints, it adds further 'I2V' and 'T2V' subdivisions.
    For LoRAs, it creates nested subfolders (e.g., 'Character', 'Style', 'Motion', 'Behaviors') within each selected base model type folder.

    If no parameters are provided, the script will display instructions and then guide the user through an interactive menu.

    After the dry run output, the script will prompt the user for final confirmation ("Would you like to go ahead with creating these folders? (y/n)").
    Only if 'y' is entered will the actual directories be created.

.PARAMETER StabilityMatrixPath
    The root path of your StabilityMatrix installation. Defaults to the current directory if not specified.

.PARAMETER Models
    A comma-separated string or array of integers specifying the numbers (a, b, c...) of the base model types to create folders for.
    Refer to the list provided by running the script without parameters.
    Example: -Models "a,c,e" (for Flux, Illustrious, Pony) or "all"

.PARAMETER Categories
    A comma-separated string or array of integers specifying the numbers (a, b, c...) of the LoRA subcategories to create folders for.
    Refer to the list provided by running the script without parameters (or your custom list if -CustomLoraCategories is used).
    Example: -Categories "a,b,d" (for Behaviors, Characters, Motion) or "all"

.PARAMETER CustomLoraCategories
    A comma-separated string or array of strings providing custom names for LoRA subcategories.
    If provided, this list will override the default LoRA subcategories.
    Example: -CustomLoraCategories "My Custom Style,My Characters,Another Category"

.EXAMPLE
    # Display instructions and then guide through interactive menu
    .\Create-StabilityMatrixModelFolders-Detailed.ps1

.EXAMPLE
    # Create folders for SDXL and WAN models, and default Behaviors, Characters, Styles LoRA subcategories
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -Models "h,k" -Categories "a,b,f"

.EXAMPLE
    # Use custom LoRA categories for all models, selecting specific custom categories
    .\Create-StabilityMatrixModelFolders-Detailed.ps1 -Models "all" -CustomLoraCategories "MyStyle,MyCharacters" -Categories "a,b"

.NOTES
    Author: Gemini (Google)
    Version: 9.4
    Date: 2025-07-29
    This script only creates directories and does not affect existing files until confirmed by the user.
    Remember to manually sort your files into these new subfolders.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$StabilityMatrixPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$Models, # Changed to string to handle "all" or comma-separated letters

    [Parameter(Mandatory=$false)]
    [string]$Categories, # Changed to string to handle "all" or comma-separated letters

    [Parameter(Mandatory=$false)]
    [string]$CustomLoraCategories # New parameter for custom category names
)

# Global flag to control live execution based on user confirmation
$PerformLiveCreation = $false
# Flag to control if Clear-Host should run before displaying the menu
$clearScreenForMenu = $true

# Script-scope variable to indicate if currently in dry run mode for Write-Log
$Script:IsDryRunMode = $false

# Define colors for the tree display
$treeColors = @("White", "Green", "Yellow", "DarkGreen", "White", "DarkCyan", "DarkGreen", "DarkMagenta", "DarkYellow")

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Ensure WARN and ERROR messages are always displayed
    if ($Level -eq "WARN" -or $Level -eq "ERROR") {
        Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor Yellow # Warnings in Yellow
        if ($Level -eq "ERROR") { Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor Red } # Errors in Red
    }
    # For INFO messages, only display if not in dry run mode (to avoid cluttering dry run output)
    # or if it's a critical startup/shutdown message.
    elseif (-not $Script:IsDryRunMode -and $Level -eq "INFO") {
        Write-Host "[$Timestamp] [$Level] $Message"
    }
    # Allow specific info messages to pass through for dry run initial/final messages
    elseif ($Script:IsDryRunMode -and $Level -eq "INFO" -and ($Message -like "*Processing a dry run*" -or $Message -like "*DRY RUN COMPLETE*")) {
         Write-Host "[$Timestamp] [$Level] $Message"
    }
}

# Define the full list of base model types for top-level folders (alphabetized)
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
) | Sort-Object

# Define common LoRA sub-categories with descriptions (alphabetized by name, with "Other" last)
$defaultLoraSubCategoriesWithDescriptions = @(
    @{ Name = "Behaviors"; Description = "LoRAs that guide character-specific movements (e.g., twirl in a skirt)." },
    @{ Name = "Characters"; Description = "LoRAs that define specific characters or character styles (e.g., Iron Man, cheerleader, baby)." },
    @{ Name = "Concepts"; Description = "LoRAs that introduce specific objects, creatures, or thematic elements into a scene (e.g., steampunk gear, dark and stormy night, Pikmin)." },
    @{ Name = "Motion"; Description = "LoRAs that guide scene or camera movements (e.g., POV driving)." },
    @{ Name = "Styles"; Description = "LoRAs that apply distinct visual aesthetics or artistic styles (e.g., Anime, Claymation, Cyberpunk)." },
    @{ Name = "Tools"; Description = "LoRAs that provide general quality improvements, utility functions, or specific control mechanisms (e.g., Fix hands, Eye size Slider, Detail Enhancer)." },
    @{ Name = "Other"; Description = "A fallback for LoRAs that don't fit other categories." } # Moved to end
)

# Extract just the names for selection purposes
$defaultLoraSubCategoryNames = $defaultLoraSubCategoriesWithDescriptions | Select-Object -ExpandProperty Name

# Define an alphabet array for easy letter-based numbering
$alphabet = [char[]]("abcdefghijklmnopqrstuvwxyz")

# --- Initial Setup for Processing ---
$baseModelTypesToProcess = @()
$loraSubCategoriesToProcess = @()
$activeLoraSubCategoryNames = $defaultLoraSubCategoryNames # This will be the list used for selection/processing

# Function to parse comma-separated letters or "all"
function Parse-SelectionInput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString,

        [Parameter(Mandatory=$true)]
        [string[]]$AvailableOptions,

        [Parameter(Mandatory=$true)]
        [string]$SelectionType # e.g., "model type" or "LoRA subcategory"
    )
    $parsedSelection = @()
    $invalidEntries = @()
    $duplicateEntries = @()
    $seenNormalizedEntries = @{} # For tracking duplicates using normalized (lowercase) item

    # Check for completely malformed input (e.g., numbers, special chars not in alpha/comma)
    if (-not ($InputString -eq "all" -or $InputString -match "^[a-zA-Z,\s]+$")) {
        Clear-Host # Clear before showing error for invalid format
        Write-Log "Invalid input format for ${SelectionType}: '${InputString}'. Please use comma-separated letters (e.g., 'a,c,e'), full names (e.g., 'Flux, SDXL'), or 'all'.", "ERROR"
        Read-Host "Press any key to continue..." | Out-Null # Pause after error
        return $false, @() # Return $false and empty array to indicate overall failure
    }

    if ($InputString -eq "all") {
        $parsedSelection = $AvailableOptions
    } else {
        $items = $InputString -split ',' | ForEach-Object { $_.Trim() } # Trim each item
        foreach ($item in $items) {
            $normalizedItem = $item.ToLower() # Normalize for internal comparison

            # Check for duplicates *among the valid options already processed or about to be processed*
            if ($seenNormalizedEntries.ContainsKey($normalizedItem)) {
                $duplicateEntries += $item
                continue # Skip to next item if already seen
            }

            $foundMatch = $false
            $matchedOption = $null

            # Try to match by letter first (only if it's a single character)
            if ($item.Length -eq 1) {
                $index = [int][char]$normalizedItem - [int][char]'a'
                if ($index -ge 0 -and $index -lt $AvailableOptions.Count) {
                    $matchedOption = $AvailableOptions[$index]
                    $foundMatch = true
                }
            }

            # If not matched by letter, try to match by full name (case-insensitive)
            if (-not $foundMatch) {
                # Use -ieq for case-insensitive comparison to find the correctly cased option
                $foundOptionList = $AvailableOptions | Where-Object { $_ -ieq $item }
                if ($foundOptionList.Count -gt 0) {
                    $matchedOption = $foundOptionList[0] # Take the first match (should be unique)
                    $foundMatch = true
                }
            }

            if ($foundMatch) {
                $parsedSelection += $matchedOption
                $seenNormalizedEntries[$normalizedItem] = true # Mark as seen
            } else {
                $invalidEntries += $item
            }
        }
    }

    # Report issues
    if ($invalidEntries.Count -gt 0 -or $duplicateEntries.Count -gt 0) {
        $message = ""
        if ($parsedSelection.Count -gt 0) {
            $message += "The following entries are valid and added: $($parsedSelection -join ', '). "
        }
        if ($invalidEntries.Count -gt 0) {
            $message += "The following entries were invalid and discarded: $($invalidEntries -join ', '). "
        }
        if ($duplicateEntries.Count -gt 0) {
            $message += "The following entries were duplicates and discarded: $($duplicateEntries -join ', '). "
        }
        $message += "Please double check for accuracy before executing."

        Write-Log $message, "WARN"
        Read-Host "Press any key to continue..." | Out-Null
    }

    return $true, ($parsedSelection | Select-Object -Unique) # Return $true for overall format validity, and unique parsed selections
}

# Function to format paths into a graphical tree structure
function Format-FolderTree {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Paths,

        [Parameter(Mandatory=$true)]
        [string]$RootPath # The common root path to remove for display
    )

    $treeOutputObjects = @() # Initialize array to collect custom objects (text + depth)
    $sortedPaths = $Paths | Sort-Object

    # Create a hash table to store the nodes and their children
    $tree = @{}

    # Populate the tree structure
    foreach ($path in $sortedPaths) {
        $relativePath = $path.Replace($RootPath, "").TrimStart("\")
        $components = $relativePath.Split("\")

        $currentLevel = $tree
        for ($i = 0; $i -lt $components.Length; $i++) {
            $component = $components[$i]
            if (-not $currentLevel.ContainsKey($component)) {
                $currentLevel[$component] = @{}
            }
            $currentLevel = $currentLevel[$component]
        }
    }

    # Helper function to recursively build the tree string and return lines with depth
    function _Build-TreeStringRecursive {
        param(
            [Parameter(Mandatory=$true)]
            [hashtable]$Node,
            [string]$Prefix = "", # Made optional with default empty string
            [int]$Depth = 0 # Current depth in the tree
        )
        $lines = @()
        $keys = $Node.Keys | Sort-Object
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $key = $keys[$i]
            $isLast = ($i -eq ($keys.Count - 1))
            $linePrefix = $Prefix + $(if ($isLast) { "└── " } else { "├── " })
            $childPrefix = $Prefix + $(if ($isLast) { "    " } else { "│   " })

            $lines += [PSCustomObject]@{ Text = "$linePrefix$key"; Depth = $Depth }
            $lines += (_Build-TreeStringRecursive -Node $Node[$key] -Prefix $childPrefix -Depth ($Depth + 1))
        }
        return $lines
    }

    $treeOutputObjects += [PSCustomObject]@{ Text = "$RootPath"; Depth = 0 } # Start with the root path
    $treeOutputObjects += (_Build-TreeStringRecursive -Node $tree -Prefix "" -Depth 1) # Collect all lines from recursive calls

    return $treeOutputObjects
}


# Function to perform folder creation (either dry run or live)
function Perform-FolderCreation {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$BaseModelTypes,

        [Parameter(Mandatory=$true)]
        [bool]$IsDryRunMode,

        [Parameter(Mandatory=$true)]
        [string]$StableDiffusionDir,

        [Parameter(Mandatory=$true)]
        [string]$LoraDir,

        [Parameter(Mandatory=$true)]
        [string[]]$LoraSubCategories
    )

    # Set a script-scope variable to indicate dry run mode for Write-Log
    $Script:IsDryRunMode = $IsDryRunMode

    $proposedPaths = @() # Collect paths for graphical tree

    # --- Collect paths for StableDiffusion directory (for main checkpoints) ---
    foreach ($folderName in $BaseModelTypes) {
        $targetPath = Join-Path -Path $StableDiffusionDir -ChildPath $folderName
        $proposedPaths += $targetPath # Always add to list for dry run

        # Special handling for WAN, Hunyuan, and SVD to add I2V/T2V subfolders
        if ($folderName -eq "WAN" -or $folderName -eq "Hunyuan" -or $folderName -eq "SVD") {
            $videoSubTypes = @("I2V", "T2V")
            foreach ($subType in $videoSubTypes) {
                $subTargetPath = Join-Path -Path $targetPath -ChildPath $subType
                $proposedPaths += $subTargetPath # Always add to list for dry run
            }
        }
    }
    # Add an 'Unsorted' folder for checkpoints that don't fit a specific category
    $unsortedCheckpointsPath = Join-Path -Path $StableDiffusionDir -ChildPath "Unsorted"
    $proposedPaths += $unsortedCheckpointsPath # Always add to list for dry run


    # --- Collect paths for Lora directory ---
    foreach ($baseType in $BaseModelTypes) {
        $baseTypeLoraPath = Join-Path -Path $LoraDir -ChildPath $baseType
        $proposedPaths += $baseTypeLoraPath # Always add to list for dry run

        # Now create the sub-categories within each base type LoRA folder
        foreach ($subCategory in $LoraSubCategories) {
            $targetPath = Join-Path -Path $baseTypeLoraPath -ChildPath $subCategory
            $proposedPaths += $targetPath # Always add to list for dry run
        }
    }
    # Add an 'Unsorted' folder for LoRAs that don't fit a specific category
    $unsortedLorasPath = Join-Path -Path $LoraDir -ChildPath "Unsorted"
    $proposedPaths += $unsortedLorasPath # Always add to list for dry run

    # If it's a dry run, format and display the collected paths
    if ($IsDryRunMode) {
        Write-Host "`nExecuting would create the following folder structure:`n" -ForegroundColor Cyan
        # Determine the common root for the tree display
        $commonRoot = ""
        if ($proposedPaths.Count -gt 0) {
            $firstPath = $proposedPaths[0]
            $parts = $firstPath.Split("\")
            # Find the common root, assuming it's up to 'models'
            for ($i = 0; $i -lt $parts.Length; $i++) {
                $commonRoot += $parts[$i] + "\"
                if ($parts[$i] -eq "models") {
                    break
                }
            }
            $commonRoot = $commonRoot.TrimEnd("\")
        }

        $treeObjects = Format-FolderTree -Paths $proposedPaths -RootPath $commonRoot
        foreach ($obj in $treeObjects) {
            Write-Host $obj.Text -ForegroundColor $treeColors[$obj.Depth % $treeColors.Length]
        }

    }
    # If it's a live run, actually create the folders
    else {
        Write-Log "Proceeding with live folder creation...", "INFO"
        # Iterate through the *collected* proposedPaths to create them
        foreach ($path in $proposedPaths | Select-Object -Unique) { # Ensure unique paths
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
            }
        }

        Write-Host "`nSuccessfully created the following folder structure:`n" -ForegroundColor Green
        # Determine the common root for the tree display of *all proposed* paths (which are now created)
        $commonRoot = "" # Recalculate common root based on proposedPaths
        if ($proposedPaths.Count -gt 0) {
            $firstPath = $proposedPaths[0]
            $parts = $firstPath.Split("\")
            for ($i = 0; $i -lt $parts.Length; $i++) {
                $commonRoot += $parts[$i] + "\"
                if ($parts[$i] -eq "models") {
                    break
                }
            }
            $commonRoot = $commonRoot.TrimEnd("\")
        }
        $treeObjects = Format-FolderTree -Paths $proposedPaths -RootPath $commonRoot
        foreach ($obj in $treeObjects) {
            Write-Host $obj.Text -ForegroundColor $treeColors[$obj.Depth % $treeColors.Length]
            Start-Sleep -Milliseconds 50 # Add a small delay for dramatic flair
        }
        Write-Log "LIVE run finished. Please check your model folders; the structure should now be created.", "INFO"
    }
}

# --- Handle Parameter Input vs. Interactive Menu ---
if ($Models -or $Categories -or $CustomLoraCategories) {
    # Parameters provided, skip interactive menu

    # Handle Custom LoRA Categories first
    if ($CustomLoraCategories) {
        $activeLoraSubCategoryNames = $CustomLoraCategories -split ',' | ForEach-Object { $_.Trim() } | Sort-Object
        if ($activeLoraSubCategoryNames.Count -eq 0) {
            Write-Log "No valid custom LoRA categories provided via -CustomLoraCategories parameter. Using default categories.", "WARN"
            $activeLoraSubCategoryNames = $defaultLoraSubCategoryNames
        } else {
            Write-Log "Using custom LoRA categories: $($activeLoraSubCategoryNames -join ', ')"
        }
    }

    # Process Models parameter
    if ($Models) {
        $isValid, $baseModelTypesToProcess = Parse-SelectionInput -InputString $Models -AvailableOptions $allBaseModelTypes -SelectionType "model type"
        if (-not $isValid) { exit 1 } # Exit if initial parameter parsing failed
    } else {
        # If -Models not provided, but other parameters are, assume all models if not specified
        $baseModelTypesToProcess = $allBaseModelTypes
        Write-Log "No specific model types provided via -Models parameter. Processing ALL model types.", "INFO"
    }

    # Process Categories parameter (using activeLoraSubCategoryNames for mapping)
    if ($Categories) {
        $isValid, $loraSubCategoriesToProcess = Parse-SelectionInput -InputString $Categories -AvailableOptions $activeLoraSubCategoryNames -SelectionType "LoRA subcategory"
        if (-not $isValid) { exit 1 } # Exit if initial parameter parsing failed
    } else {
        # If -Categories not provided, but other parameters are, assume all active categories if not specified
        $loraSubCategoriesToProcess = $activeLoraSubCategoryNames
        Write-Log "No specific LoRA subcategories provided via -Categories parameter. Processing ALL active LoRA subcategories.", "INFO"
    }

    # Final validation before Dry Run/Execute
    if ($baseModelTypesToProcess.Count -eq 0 -or $loraSubCategoriesToProcess.Count -eq 0) {
        Write-Log "Insufficient selections made. Please ensure you select at least one model type and one LoRA subcategory. Script will exit.", "ERROR"
        exit 1
    }

    Write-Log "Selected base model types: $($baseModelTypesToProcess -join ', ')"
    Write-Log "Selected LoRA subcategories: $($loraSubCategoriesToProcess -join ', ')"

    # --- DEBUGGING PATHS FOR PARAMETER MODE ---
    Write-Log "DEBUG (Parameter Mode): StabilityMatrixPath: '$StabilityMatrixPath'"
    Write-Log "DEBUG (Parameter Mode): dataModelsPath: '$(Join-Path -Path $StabilityMatrixPath -ChildPath "models")'"
    Write-Log "DEBUG (Parameter Mode): stableDiffusionDir: '$(Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "StableDiffusion")'"
    Write-Log "DEBUG (Parameter Mode): loraDir: '$(Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "Lora")'"
    # --- END DEBUGGING ---

    # --- DRY RUN PHASE (for parameter-driven) ---
    Write-Host "`n--- DRY RUN: Proposed Folder Structure Changes ---`n" -ForegroundColor Cyan
    Perform-FolderCreation -BaseModelTypes $baseModelTypesToProcess -IsDryRunMode $true `
        -StableDiffusionDir (Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "StableDiffusion") `
        -LoraDir (Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "Lora") `
        -LoraSubCategories $loraSubCategoriesToProcess
    Write-Host "`n--- DRY RUN COMPLETE ---`n" -ForegroundColor Cyan
    Read-Host "Press any key to continue..." | Out-Null

    # --- FINAL CONFIRMATION (for parameter-driven) ---
    $confirm = Read-Host "Would you like to go ahead with creating these folders? (y/N)" # Changed to (y/N)
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        $PerformLiveCreation = true
        Write-Host "`n--- PROCEEDING WITH LIVE FOLDER CREATION ---`n" -ForegroundColor Green
        $Script:IsDryRunMode = $false # Reset for live run
        Perform-FolderCreation -BaseModelTypes $baseModelTypesToProcess -IsDryRunMode $false `
            -StableDiffusionDir (Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "StableDiffusion") `
            -LoraDir (Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "Lora") `
            -LoraSubCategories $loraSubCategoriesToProcess
        Write-Log "LIVE run finished. Please check your model folders; the structure should now be created.", "INFO"
    } else {
        Write-Log "Folder creation aborted by user. No changes were made to your file system.", "INFO"
    }

} else {
    # No parameters provided, go interactive menu

    $currentSelectionModels = @()
    $currentSelectionLoraCategories = @()
    $actionChosen = $false # Flag to know when to exit menu loop

    # Define paths here so they can be updated if user changes StabilityMatrixPath
    # These are the *working* variables for the interactive mode
    $dataModelsPathInteractive = Join-Path -Path $StabilityMatrixPath -ChildPath "models"
    $stableDiffusionDirInteractive = Join-Path -Path $dataModelsPathInteractive -ChildPath "StableDiffusion"
    $loraDirInteractive = Join-Path -Path $dataModelsPathInteractive -ChildPath "Lora"

    do {
        if ($clearScreenForMenu) {
            Clear-Host # Clear console only if needed
        }
        $clearScreenForMenu = $true # Reset for next iteration

        Write-Host "`n--- Script Usage Instructions ---" -ForegroundColor Magenta
        Write-Host "`nThis script will create a set of nested folders within your StabilityMatrix 'models' folder (`"$StabilityMatrixPath\models`") so you can organize your files." -ForegroundColor Magenta

        # Define image-focused and video-focused models for display
        $imageFocusedModels = @("Flux", "Illustrious", "NooB_AI", "Pony", "SD15", "SD2x", "SDXL", "SSD1B") | Sort-Object
        $videoFocusedModels = @("Hunyuan", "SVD", "WAN") | Sort-Object

        Write-Host "`n--- Image-focused Model Types ---" -ForegroundColor DarkYellow
        foreach ($model in $imageFocusedModels) {
            $index = $allBaseModelTypes.IndexOf($model)
            $char = $alphabet[$index]
            Write-Host "$char) " -NoNewline -ForegroundColor White # Letter designation in White
            Write-Host "$model" -ForegroundColor Cyan
        }

        Write-Host "`n--- Video-focused Model Types (will create I2V and T2V subfolders within Model and LoRA folders) ---" -ForegroundColor DarkYellow
        foreach ($model in $videoFocusedModels) {
            $index = $allBaseModelTypes.IndexOf($model)
            $char = $alphabet[$index]
            Write-Host "$char) " -NoNewline -ForegroundColor White # Letter designation in White
            Write-Host "$model" -ForegroundColor Cyan
        }

        Write-Host "`n--- LoRA Subfolders ---" -ForegroundColor DarkYellow
        for ($i = 0; $i -lt $activeLoraSubCategoryNames.Count; $i++) {
            $char = $alphabet[$i] # Use the alphabet array
            # Find the description for the current active category name
            $description = ($defaultLoraSubCategoriesWithDescriptions | Where-Object { $_.Name -eq $activeLoraSubCategoryNames[$i] } | Select-Object -ExpandProperty Description)
            Write-Host "$char) " -NoNewline -ForegroundColor White # Letter designation in White
            Write-Host "$($activeLoraSubCategoryNames[$i])" -NoNewline -ForegroundColor DarkGreen # LoRA subfolder title in DarkGreen
            Write-Host " - $description"
        }

        Write-Host "`n--- Main Menu ---" -ForegroundColor DarkYellow
        Write-Host "1) Select StabilityMatrix Root Directory (Current: '" -NoNewline -ForegroundColor Yellow # Start of the string in Yellow
        Write-Host "$StabilityMatrixPath" -NoNewline -ForegroundColor Cyan # Path in Cyan
        Write-Host "')" -ForegroundColor Yellow # Closing parenthesis and single quote in Yellow
        Write-Host "2) Select Models (Currently selected: " -NoNewline -ForegroundColor Yellow # Menu option text in Yellow
        if ($currentSelectionModels.Count -eq 0) {
            Write-Host "None" -ForegroundColor Red
        } else {
            Write-Host "$($currentSelectionModels -join ', ')" -ForegroundColor Cyan # Selections in Cyan
        }
        Write-Host "3) Select LoRA (Currently selected: " -NoNewline -ForegroundColor Yellow # Menu option text in Yellow
        if ($currentSelectionLoraCategories.Count -eq 0) {
            Write-Host "None" -ForegroundColor Red
        } else {
            Write-Host "$($currentSelectionLoraCategories -join ', ')" -ForegroundColor Cyan # Selections in Cyan
        }
        Write-Host "4) Customize LoRA List" -ForegroundColor Yellow
        Write-Host "5) Dry Run" -ForegroundColor Yellow
        Write-Host "6) Execute" -ForegroundColor Yellow
        Write-Host "0) Quit" -ForegroundColor Yellow
        Write-Host "Enter your choice (0-6):" -NoNewline # Updated prompt
        $menuChoice = Read-Host

        switch ($menuChoice) {
            "1" { # Handle new "Select StabilityMatrix Root Directory" option
                $newPathInput = Read-Host "Enter the new StabilityMatrix root directory (e.g., 'C:\StabilityMatrix'). Press Enter to keep current: '$StabilityMatrixPath'"
                if (-not [string]::IsNullOrWhiteSpace($newPathInput)) {
                    # Validate path existence before setting
                    if (Test-Path $newPathInput -PathType Container) {
                        $StabilityMatrixPath = $newPathInput
                        # Recalculate dependent paths for interactive mode
                        $dataModelsPathInteractive = Join-Path -Path $StabilityMatrixPath -ChildPath "models"
                        $stableDiffusionDirInteractive = Join-Path -Path $dataModelsPathInteractive -ChildPath "StableDiffusion"
                        $loraDirInteractive = Join-Path -Path $dataModelsPathInteractive -ChildPath "Lora"
                        Write-Log "StabilityMatrix Root Directory updated to: '$StabilityMatrixPath'", "INFO"
                    } else {
                        Write-Log "Invalid path entered: '$newPathInput'. Directory does not exist. Keeping current path.", "WARN"
                    }
                } else {
                    Write-Log "No new path entered. Keeping current StabilityMatrix Root Directory: '$StabilityMatrixPath'", "INFO"
                }
            }
            "2" {
                $modelsInput = Read-Host "Enter the letters or full names of the Model Types you want to create (e.g., 'a, c, e' or 'Flux, SDXL'). Press Enter for ALL."
                if (-not $modelsInput) { $modelsInput = "all" }
                $isValid, $newSelection = Parse-SelectionInput -InputString $modelsInput -AvailableOptions $allBaseModelTypes -SelectionType "model type"
                if ($isValid) {
                    $currentSelectionModels = $newSelection
                }
            }
            "3" {
                $categoriesInput = Read-Host "Enter the letters or full names of the LoRA Subcategories you want to create (e.g., 'a, b, d' or 'Characters, Styles'). Press Enter for ALL."
                if (-not $categoriesInput) { $categoriesInput = "all" }
                $isValid, $newSelection = Parse-SelectionInput -InputString $categoriesInput -AvailableOptions $activeLoraSubCategoryNames -SelectionType "LoRA subcategory"
                if ($isValid) {
                    $currentSelectionLoraCategories = $newSelection
                }
            }
            "4" {
                $customNamesInput = Read-Host "Enter your custom LoRA subcategory names, separated by commas (e.g., 'My Style, My Characters'). Press Enter to use defaults."
                if (-not [string]::IsNullOrWhiteSpace($customNamesInput)) {
                    $newCustomNames = $customNamesInput -split ',' | ForEach-Object { $_.Trim() } | Sort-Object | Select-Object -Unique
                    if ($newCustomNames.Count -eq 0) {
                        Clear-Host
                        Write-Log "No valid custom names entered. Reverting to default LoRA subcategories.", "WARN"
                        Read-Host "Press any key to continue..." | Out-Null # Pause after warning
                        $activeLoraSubCategoryNames = $defaultLoraSubCategoryNames
                    } else {
                        $activeLoraSubCategoryNames = $newCustomNames
                        Write-Log "Using custom LoRA subcategories: $($activeLoraSubCategoryNames -join ', ')", "INFO"
                        Read-Host "Press any key to continue..." | Out-Null # Pause after info
                    }
                } else {
                    Write-Log "No custom names entered. Reverting to default LoRA subcategories.", "INFO"
                    Read-Host "Press any key to continue..." | Out-Null # Pause after info
                    $activeLoraSubCategoryNames = $defaultLoraSubCategoryNames
                }
                # Clear previous selections for LoRA categories if custom list changes
                $currentSelectionLoraCategories = @()
            }
            "5" {
                # Validate selections before dry run
                if ($currentSelectionModels.Count -eq 0 -or $currentSelectionLoraCategories.Count -eq 0) {
                    Clear-Host
                    Write-Log "Please select at least one Model Type and one LoRA Subcategory before performing a Dry Run.", "WARN"
                    Read-Host "Press any key to continue..." | Out-Null
                    $clearScreenForMenu = true # Ensure menu clears on next redraw
                    continue # Go back to menu
                }
                # Assign selected values to the variables used by Perform-FolderCreation
                $baseModelTypesToProcess = $currentSelectionModels
                $loraSubCategoriesToProcess = $currentSelectionLoraCategories

                # Set flags and break loop to proceed to dry run execution after the menu loop
                $actionChosen = "DryRun"
                $clearScreenForMenu = $false # Do NOT clear screen before dry run output
                break # Exit the do-while loop to proceed to dry run execution
            }
            "6" {
                # Validate selections before execution
                if ($currentSelectionModels.Count -eq 0 -or $currentSelectionLoraCategories.Count -eq 0) {
                    Clear-Host
                    Write-Log "Please select at least one Model Type and one LoRA Subcategory before executing.", "WARN"
                    Read-Host "Press any key to continue..." | Out-Null
                    $clearScreenForMenu = true # Ensure menu clears on next redraw
                    continue # Go back to menu
                }

                # Assign selected values to the variables used by Perform-FolderCreation
                $baseModelTypesToProcess = $currentSelectionModels
                $loraSubCategoriesToProcess = $currentSelectionLoraCategories

                # Interactive mode's FINAL CONFIRMATION
                $confirmExecute = Read-Host "Would you like to go ahead with creating these folders? (y/N)" # Changed to (y/N)
                if ($confirmExecute -eq 'y' -or $confirmExecute -eq 'Y') {
                    $PerformLiveCreation = true
                    Write-Host "`n--- PROCEEDING WITH LIVE FOLDER CREATION ---`n" -ForegroundColor Green
                    $Script:IsDryRunMode = $false # Reset for live run

                    # --- DEBUGGING PATHS FOR INTERACTIVE LIVE RUN ---
                    Write-Log "DEBUG (Interactive Live Run): StabilityMatrixPath: '$StabilityMatrixPath'"
                    Write-Log "DEBUG (Interactive Live Run): dataModelsPathInteractive: '$dataModelsPathInteractive'"
                    Write-Log "DEBUG (Interactive Live Run): stableDiffusionDirInteractive: '$stableDiffusionDirInteractive'"
                    Write-Log "DEBUG (Interactive Live Run): loraDirInteractive: '$loraDirInteractive'"
                    # --- END DEBUGGING ---

                    Perform-FolderCreation -BaseModelTypes $baseModelTypesToProcess -IsDryRunMode $false `
                        -StableDiffusionDir $stableDiffusionDirInteractive -LoraDir $loraDirInteractive -LoraSubCategories $loraSubCategoriesToProcess
                    Write-Log "LIVE run finished. Please check your model folders; the structure should now be created.", "INFO"

                    $actionChosen = true # Set to $true to exit the main do-while loop
                    break # Exit the switch
                } else {
                    Write-Log "Folder creation aborted by user. Returning to main menu.", "INFO"
                    Read-Host "Press any key to continue..." | Out-Null
                    # $actionChosen remains $false, so the do-while loop will continue
                    $clearScreenForMenu = true # Ensure menu clears on next redraw
                    continue # Go back to menu
                }
            }
            "0" { # Handle Quit option
                Write-Log "Quitting script. No changes will be made.", "INFO"
                exit 0 # Exit the script immediately
            }
            default {
                Write-Log "Invalid choice. Please enter a number between 0 and 6.", "WARN"
                Read-Host "Press any key to continue..." | Out-Null # Pause after invalid choice
            }
        }
    } while (-not $actionChosen) # Loop until $actionChosen is $true (meaning Execute was confirmed and completed, or Quit was chosen)

    # This block will now only run if parameters were provided or if interactive Execute was confirmed.
    # The interactive Dry Run path and interactive Execute (declined) path return to the menu.
}

Write-Log "Selected base model types: $($baseModelTypesToProcess -join ', ')"
Write-Log "Selected LoRA subcategories: $($loraSubCategoriesToProcess -join ', ')"


# --- FINAL CONFIRMATION (applies only to parameter-driven execution) ---
# This block is only reached if parameters were provided and the script didn't exit earlier.
if ($Models -or $Categories -or $CustomLoraCategories) {
    $confirm = Read-Host "Would you like to go ahead with creating these folders? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        $PerformLiveCreation = true
        Write-Host "`n--- PROCEEDING WITH LIVE FOLDER CREATION ---`n" -ForegroundColor Green
        $Script:IsDryRunMode = $false # Reset for live run
        # Use the appropriate paths based on whether it was parameter-driven or interactive
        $finalStableDiffusionDir = Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "StableDiffusion"
        $finalLoraDir = Join-Path -Path (Join-Path -Path $StabilityMatrixPath -ChildPath "models") -ChildPath "Lora"

        Perform-FolderCreation -BaseModelTypes $baseModelTypesToProcess -IsDryRunMode $false `
            -StableDiffusionDir $finalStableDiffusionDir -LoraDir $finalLoraDir -LoraSubCategories $loraSubCategoriesToProcess
        Write-Log "LIVE run finished. Please check your model folders; the structure should now be created.", "INFO"
    } else {
        Write-Log "Folder creation aborted by user. No changes were made to your file system.", "INFO"
    }
}

Write-Log "Script execution completed."
