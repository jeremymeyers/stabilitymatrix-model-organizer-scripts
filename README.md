# stabilitymatrix-model-organizer-scripts
Scripts for StabilityMatrix to create a hierarchal organizational system for models and LORA. Note: This is Google Gemini-created code which I looked over for accuracy.
# `Create-StabilityMatrixModelFolders-Detailed.ps1`

This PowerShell script is designed to help you establish a highly organized and detailed subfolder structure within your StabilityMatrix `Data\Models` directory. This structure is optimized for managing a diverse collection of Stable Diffusion models and LoRAs across multiple UIs (like ComfyUI, Stable Diffusion WebUI Forge, SD.Next) that share models via StabilityMatrix.

## What it Does

The script will create a predefined set of subdirectories within `StabilityMatrix\Data\Models\StableDiffusion\` (for main checkpoints) and `StabilityMatrix\Data\Models\Lora\` (for LoRAs).

**Key features of the created structure:**

* **Top-Level Categorization:** Divides models by their base type (e.g., `SD15`, `SDXL`, `Pony`, `WAN`, `Hunyuan`, `Flux`, etc.).

* **WAN/Hunyuan Checkpoint Sub-division:** For `WAN` and `Hunyuan` main models, it creates further sub-levels for `I2V` (Image-to-Video) and `T2V` (Text-to-Video) to distinguish specific model variants.

* **Detailed LoRA Sub-categorization:** Within each base model type's LoRA folder, it creates granular sub-categories to organize LoRAs by their primary function:

    * `Characters`: For LoRAs that define specific characters.

    * `Concepts`: For LoRAs that introduce abstract concepts or specific objects.

    * `Styles`: For LoRAs that apply distinct visual aesthetics.

    * `Motion`: For LoRAs that guide scene or camera movements (e.g., POV driving).

    * `Behaviors`: For LoRAs that guide character-specific movements (e.g., twirl in a skirt).

    * `Utility_Enhancers`: For LoRAs that provide general quality improvements or utility functions.

    * `Other`: A fallback for LoRAs that don't fit other categories.

* **Unsorted Folders:** Creates an `Unsorted` folder in both `StableDiffusion` and `Lora` for files that don't match any predefined category during manual sorting or if you use a separate auto-sorting script later.

**Important Note:** This script **ONLY creates the directories**. It **DOES NOT move or affect any existing files**. After running this script, you will need to manually sort your existing model files into the appropriate new subfolders, or use a separate file-moving script (like the `Organize-StabilityMatrixModels.ps1` script, adapted to target these deeper paths, or a similar tool).

## How to Use

1.  **Save the Script:**

    * Copy the entire PowerShell script content into a text editor.

    * Save the file as `Create-StabilityMatrixModelFolders-Detailed.ps1` (or any `.ps1` name) directly in the root directory of your StabilityMatrix installation (e.g., `X:\stabilitymatrix\`).

2.  **Open PowerShell:**

    * Navigate to your StabilityMatrix installation folder in File Explorer (e.g., `X:\stabilitymatrix\`).

    * In the address bar of File Explorer, type `powershell` and press `Enter`. This will open a PowerShell window with the correct working directory.

3.  **Run a Dry Run (Recommended First):**

    * To see exactly which folders the script *would* create without actually making any changes, run the script without any flags:

        ```
        .\Create-StabilityMatrixModelFolders-Detailed.ps1
        
        ```

    * Review the output in the PowerShell window. It will show messages like "Proposed: Creating directory: ..."

4.  **Perform Live Folder Creation:**

    * Once you are satisfied with the dry run output, execute the script with the `-LiveRun` flag to create the directories:

        ```
        .\Create-StabilityMatrixModelFolders-Detailed.ps1 -LiveRun
        
        ```

    * The script will log its actions, creating the folders.

## Sample Folder Tree Created

After running the script with `-LiveRun`, your `StabilityMatrix\Data\Models\` directory will have a structure similar to this (only showing relevant parts for brevity):
```
StabilityMatrix/
├── models/
│   ├── StableDiffusion/  <-- Main Checkpoints
│   │   ├── Flux/
│   │   ├── Hunyuan/
│   │   │   ├── I2V/      <-- Hunyuan Checkpoints (Image-to-Video)
│   │   │   ├── T2V/      <-- Hunyuan Checkpoints (Text-to-Video)
│   │   │   └── Combination/  <-- Hunyuan Checkpoints (I2V/T2V Combination)
│   │   ├── Illustrious/
│   │   ├── NooB_AI/
│   │   ├── Pony/
│   │   ├── SD15/
│   │   ├── SD2x/
│   │   ├── SDXL/
│   │   ├── SSD1B/
│   │   ├── SVD/
│   │   │   ├── I2V/      <-- SVD Checkpoints (Image-to-Video)
│   │   │   ├── T2V/      <-- SVD Checkpoints (Text-to-Video)
│   │   │   └── Combination/  <-- SVD Checkpoints (I2V/T2V Combination)
│   │   ├── WAN/
│   │   │   ├── I2V/      <-- WAN Checkpoints (Image-to-Video)
│   │   │   ├── T2V/      <-- WAN Checkpoints (Text-to-Video)
│   │   │   └── Combination/  <-- WAN Checkpoints (I2V/T2V Combination)
│   │   └── Unsorted/     <-- For Checkpoints that don't fit a category
│   ├── Lora/             <-- LoRAs
│   │   ├── Flux/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── Hunyuan/
│   │   │   ├── I2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   ├── T2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   └── Combination/
│   │   │       ├── Behaviors/
│   │   │       ├── Characters/
│   │   │       ├── Concepts/
│   │   │       ├── Motion/
│   │   │       ├── Styles/
│   │   │       ├── Tools/
│   │   │       └── Other/
│   │   ├── Illustrious/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── NooB_AI/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── Pony/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── SD15/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── SD2x/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── SDXL/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── SSD1B/
│   │   │   ├── Behaviors/
│   │   │   ├── Characters/
│   │   │   ├── Concepts/
│   │   │   ├── Motion/
│   │   │   ├── Styles/
│   │   │   ├── Tools/
│   │   │   └── Other/
│   │   ├── SVD/
│   │   │   ├── I2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   ├── T2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   └── Combination/
│   │   │       ├── Behaviors/
│   │   │       ├── Characters/
│   │   │       ├── Concepts/
│   │   │       ├── Motion/
│   │   │       ├── Styles/
│   │   │       ├── Tools/
│   │   │       └── Other/
│   │   ├── WAN/
│   │   │   ├── I2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   ├── T2V/
│   │   │   │   ├── Behaviors/
│   │   │   │   ├── Characters/
│   │   │   │   ├── Concepts/
│   │   │   │   ├── Motion/
│   │   │   │   ├── Styles/
│   │   │   │   ├── Tools/
│   │   │   │   └── Other/
│   │   │   └── Combination/
│   │   │       ├── Behaviors/
│   │   │       ├── Characters/
│   │   │       ├── Concepts/
│   │   │       ├── Motion/
│   │   │       ├── Styles/
│   │   │       ├── Tools/
│   │   │       └── Other/
│   │   └── Unsorted/     <-- For LoRAs that don't fit a base model type
│   ├── VAE/
│   ├── CLIP/
│   ├── TextEncoders/
│   └── (other model type folders like ControlNet, embeddings, etc.)

```
