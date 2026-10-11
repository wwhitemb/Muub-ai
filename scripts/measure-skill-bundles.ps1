[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$skillsRoot = Join-Path $RepositoryRoot 'skills'
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    throw "Skills directory not found: $skillsRoot"
}

function Get-TextStats {
    param([string[]]$Paths)

    $existing = @($Paths | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Leaf)
    })
    $text = ''
    foreach ($path in $existing) {
        $text += [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path)
        $text += "`n"
    }

    [PSCustomObject]@{
        Files = $existing.Count
        Lines = if ($text.Length -eq 0) { 0 } else { @($text -split "`r?`n").Count - 1 }
        Chars = $text.Length
        EstimatedTokens = [math]::Ceiling($text.Length / 4.0)
    }
}

$entryRows = @()
$skillFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter 'SKILL.md' | Sort-Object FullName)
foreach ($skillFile in $skillFiles) {
    $stats = Get-TextStats -Paths @($skillFile.FullName)
    $entryRows += [PSCustomObject]@{
        Skill = $skillFile.Directory.Name
        File = 'SKILL.md'
        Files = $stats.Files
        Lines = $stats.Lines
        Chars = $stats.Chars
        EstimatedTokens = $stats.EstimatedTokens
    }
}

Write-Output 'Skill entry sizes (SKILL.md only):'
$entryRows | Sort-Object Chars -Descending | Format-Table -AutoSize

Write-Output ''
Write-Output 'Reference file sizes (each file is loaded independently):'
$referenceRows = @()
foreach ($skillFile in $skillFiles) {
    $referenceRoot = Join-Path $skillFile.Directory.FullName 'references'
    if (-not (Test-Path -LiteralPath $referenceRoot -PathType Container)) {
        continue
    }

    $referenceFiles = @(Get-ChildItem -LiteralPath $referenceRoot -File -Filter '*.md' | Sort-Object Name)
    foreach ($referenceFile in $referenceFiles) {
        $stats = Get-TextStats -Paths @($referenceFile.FullName)
        $referenceRows += [PSCustomObject]@{
            Skill = $skillFile.Directory.Name
            File = "references/$($referenceFile.Name)"
            Files = $stats.Files
            Lines = $stats.Lines
            Chars = $stats.Chars
            EstimatedTokens = $stats.EstimatedTokens
        }
    }
}
$referenceRows | Sort-Object Chars -Descending | Format-Table -AutoSize

$bundles = [ordered]@{
    'cpp-core-module' = @(
        'coding-cpp-core/SKILL.md',
        'coding-cpp-core/references/cpp-naming-and-api.md',
        'coding-cpp-core/references/cpp-module-template.md'
    )
    'embedded-c-safety' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'coding-c-safety/references/embedded-c-safety-checklist.md'
    )
    'rtthread-arch' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'coding-rtthread-style/SKILL.md',
        'coding-rtthread-style/references/rtthread-ipc-templates.md',
        'embedded-arch/SKILL.md',
        'embedded-arch/references/architecture-adapter-templates.md'
    )
    'can-frame' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'coding-c-safety/references/embedded-c-safety-checklist.md',
        'can-bus-dev/SKILL.md',
        'can-bus-dev/references/can-frame-templates.md'
    )
    'meter-domain' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'coding-rtthread-style/SKILL.md',
        'can-bus-dev/SKILL.md',
        'can-bus-dev/references/can-frame-templates.md',
        'meter-datapool/SKILL.md',
        'meter-datapool/references/datapool-contract-templates.md',
        'meter-storage/SKILL.md',
        'meter-storage/references/persistence-templates.md'
    )
    'guider-1x-source' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'guider-engineering/SKILL.md',
        'guider-engineering/references/guider-1x-source-edit.md'
    )
    'guider-1x-project' = @(
        'guider-engineering/SKILL.md',
        'guider-engineering/references/guider-1x-project-edit.md'
    )
    'guider-2x-source' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'guider-engineering/SKILL.md',
        'guider-engineering/references/guider-2x-source-edit.md'
    )
    'guider-2x-project' = @(
        'guider-engineering/SKILL.md',
        'guider-engineering/references/guider-2x-project-edit.md'
    )
    'figma-motion' = @(
        'coding-cpp-core/SKILL.md',
        'coding-c-safety/SKILL.md',
        'figma-to-lvgl-motion/SKILL.md',
        'figma-to-lvgl-motion/references/animation-trace-template.md'
    )
    'lark-embedded-doc' = @(
        'lark-user-skill/SKILL.md',
        'lark-user-skill/references/embedded-doc-writing.md'
    )
    'taobao-inquiry' = @(
        'taobao-product-inquiry/SKILL.md',
        'taobao-product-inquiry/references/taobao-inquiry-workflow.md'
    )
}

Write-Output ''
Write-Output 'Typical route bundles (only explicitly selected references are included):'
$bundleRows = @()
foreach ($bundle in $bundles.GetEnumerator()) {
    $paths = @()
    foreach ($relativePath in $bundle.Value) {
        $path = Join-Path $skillsRoot $relativePath
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $paths += $path
        }
    }
    $stats = Get-TextStats -Paths $paths
    $bundleRows += [PSCustomObject]@{
        Bundle = $bundle.Key
        Files = $stats.Files
        Lines = $stats.Lines
        Chars = $stats.Chars
        EstimatedTokens = $stats.EstimatedTokens
    }
}
$bundleRows | Format-Table -AutoSize
