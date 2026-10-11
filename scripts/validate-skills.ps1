[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
$failed = $false

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

function Add-Failure {
    param([string]$Message)
    Write-Warning $Message
    $script:failed = $true
}

function Add-Notice {
    param([string]$Message)
    Write-Warning "Notice: $Message"
}

function Get-StrictUtf8Text {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
    } catch {
        Add-Failure "Unable to read text file: $Path"
        return ''
    }

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Add-Failure "UTF-8 BOM is not allowed: $Path"
    }
    if ($bytes -contains 0) {
        Add-Failure "NUL byte found in text file: $Path"
    }

    try {
        $decoder = [Text.UTF8Encoding]::new($false, $true)
        $text = $decoder.GetString($bytes)
    } catch {
        Add-Failure "File is not valid UTF-8: $Path"
        return ''
    }

    if ($text.IndexOf([char]0xFFFD) -ge 0) {
        Add-Failure "Unicode replacement character found: $Path"
    }

    return $text
}

if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
    throw "Repository directory not found: $RepositoryRoot"
}

$skillsRoot = Join-Path $RepositoryRoot 'skills'
$maintenanceSkillDirectory = Join-Path $skillsRoot 'skill-repo-maintenance'
$maintenanceSkillFile = Join-Path $maintenanceSkillDirectory 'SKILL.md'
$maintenanceDocument = Join-Path $RepositoryRoot 'docs/skill-maintenance.md'
$excludedOfficialSkills = @(
    'lark-approval', 'lark-apps', 'lark-attendance', 'lark-base',
    'lark-calendar', 'lark-contact', 'lark-doc', 'lark-drive',
    'lark-event', 'lark-im', 'lark-mail', 'lark-markdown',
    'lark-minutes', 'lark-note', 'lark-okr', 'lark-openapi-explorer',
    'lark-shared', 'lark-sheets', 'lark-skill-maker', 'lark-slides',
    'lark-task', 'lark-vc', 'lark-vc-agent', 'lark-whiteboard',
    'lark-wiki', 'lark-workflow-meeting-summary',
    'lark-workflow-standup-report'
)
$removedSkillDirectories = @('coding-naming', 'coding-style')

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
        Add-Failure "skills directory not found: $skillsRoot"
} else {
    $skillFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Force -Filter 'SKILL.md' | Sort-Object FullName)
    $skillDirectories = @($skillFiles | ForEach-Object { $_.Directory } | Sort-Object FullName)
    if ($skillDirectories.Count -eq 0) {
        Add-Failure "No skills found under: $skillsRoot"
    }

    if (-not (Test-Path -LiteralPath $maintenanceSkillFile -PathType Leaf)) {
        Add-Failure "Skill repository maintenance entry is missing: $maintenanceSkillFile"
    }

    if (-not (Test-Path -LiteralPath $maintenanceDocument -PathType Leaf)) {
        Add-Failure "Skill maintenance document is missing: $maintenanceDocument"
    }

    foreach ($removedSkillDirectory in $removedSkillDirectories) {
        $removedSkillPath = Join-Path $skillsRoot $removedSkillDirectory
        if (Test-Path -LiteralPath $removedSkillPath) {
            Add-Failure "Removed compatibility Skill directory must not be present: $removedSkillPath"
        }
    }

    $expectedReferences = @{
        'coding-cpp-core' = @(
            'cpp-naming-and-api.md',
            'cpp-module-template.md'
        )
        'coding-c-safety' = @(
            'embedded-c-safety-checklist.md'
        )
        'coding-rtthread-style' = @(
            'rtthread-ipc-templates.md'
        )
        'can-bus-dev' = @(
            'can-frame-templates.md'
        )
        'embedded-arch' = @(
            'architecture-adapter-templates.md'
        )
        'meter-datapool' = @(
            'datapool-contract-templates.md'
        )
        'meter-storage' = @(
            'persistence-templates.md'
        )
        'figma-to-lvgl-motion' = @(
            'animation-trace-template.md'
        )
        'lark-user-skill' = @(
            'embedded-doc-writing.md'
        )
        'taobao-product-inquiry' = @(
            'taobao-inquiry-workflow.md'
        )
        'guider-engineering' = @(
            'guider-1x-project-edit.md',
            'guider-1x-source-edit.md',
            'guider-2x-project-edit.md',
            'guider-2x-source-edit.md'
        )
    }

    foreach ($skillDirectory in $skillDirectories) {
        if ($skillDirectory.Name -in $excludedOfficialSkills) {
            Add-Failure "Excluded official Lark skill found: $($skillDirectory.Name)"
        }

        $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'

        $content = Get-StrictUtf8Text -Path $skillFile
        $hasFrontmatter = $content.TrimStart().StartsWith('---')
        $hasName = $content -match '(?m)^name:\s*[^\r\n]+'
        $hasDescription = $content -match '(?m)^description:\s*[^\r\n]+'
        if (-not ($hasFrontmatter -and $hasName -and $hasDescription)) {
            Add-Failure "SKILL.md has invalid name/description frontmatter: $skillFile"
        }

        $nameMatch = [regex]::Match($content, '(?m)^name:\s*([^\r\n]+)')
        $declaredName = $nameMatch.Groups[1].Value.Trim().Trim('"', "'")
        if ($nameMatch.Success -and $declaredName -ne $skillDirectory.Name) {
            Add-Failure "Skill name does not match directory name: $skillFile"
        }

        if ($content.Length -gt 12000) {
            Add-Notice "Large Skill entry ($($content.Length) chars): $skillFile"
        }
        $codeFenceCount = ([regex]::Matches($content, '(?m)^```')).Count
        if ($codeFenceCount -gt 6) {
            Add-Notice "Skill has many code fences ($codeFenceCount): $skillFile"
        }

        $absolutePathPattern = '(?i)[A-Z]:\\|/Users/|/home/'
        if ($content -match $absolutePathPattern) {
            Add-Failure "Skill appears to contain a local absolute path: $skillFile"
        }

        if ($expectedReferences.ContainsKey($skillDirectory.Name)) {
            $referencesRoot = Join-Path $skillDirectory.FullName 'references'
            if (-not (Test-Path -LiteralPath $referencesRoot -PathType Container)) {
                Add-Failure "Skill references directory is missing: $referencesRoot"
            } else {
                foreach ($referenceName in $expectedReferences[$skillDirectory.Name]) {
                    $referenceFile = Join-Path $referencesRoot $referenceName
                    if (-not (Test-Path -LiteralPath $referenceFile -PathType Leaf)) {
                        Add-Failure "Required Skill reference is missing: $referenceFile"
                    } elseif ($content -notmatch [regex]::Escape("references/$referenceName")) {
                        Add-Failure "Skill entry does not declare required reference: $skillFile -> $referenceName"
                    }
                }
            }
        }

        $skillTextFiles = @(Get-ChildItem -LiteralPath $skillDirectory.FullName -Recurse -File -Force | Where-Object {
            $_.Extension -eq '.md'
        })
        foreach ($skillTextFile in $skillTextFiles) {
            $skillText = Get-StrictUtf8Text -Path $skillTextFile.FullName
            if ($skillText -match $absolutePathPattern) {
                Add-Failure "Skill appears to contain a local absolute path: $($skillTextFile.FullName)"
            }
        }
    }

    $legacySkillDirectory = Join-Path $skillsRoot 'guider-lvgl-port'
    if (Test-Path -LiteralPath $legacySkillDirectory) {
        Add-Failure "Legacy Guider Skill directory must not be present: $legacySkillDirectory"
    }

    $guiderSkillDirectory = Join-Path $skillsRoot 'guider-engineering'
    $guiderSkillFile = Join-Path $guiderSkillDirectory 'SKILL.md'
    if (Test-Path -LiteralPath $guiderSkillFile -PathType Leaf) {
        $guiderSkillContent = Get-StrictUtf8Text -Path $guiderSkillFile
        $guiderPermissionPatterns = @(
            'project-edit',
            'source-edit',
            'generated/',
            'custom/',
            '只读',
            '可写'
        )
        foreach ($pattern in $guiderPermissionPatterns) {
            if ($guiderSkillContent -notmatch $pattern) {
                Add-Failure "Guider Skill routing or permission marker is missing: $pattern"
            }
        }
        foreach ($referenceName in $expectedReferences['guider-engineering']) {
            if ($guiderSkillContent -notmatch [regex]::Escape($referenceName)) {
                Add-Failure "Guider Skill does not declare required reference: $referenceName"
            }
        }
    }

    $legacyRouteFiles = @(
        (Join-Path $RepositoryRoot 'prompts/global.md'),
        (Join-Path $RepositoryRoot 'prompts/two-wheeler-meter.md'),
        (Join-Path $RepositoryRoot 'project-rules/two-wheeler-meter/AGENTS.md'),
        (Join-Path $RepositoryRoot 'project-rules/two-wheeler-meter/README.md'),
        (Join-Path $RepositoryRoot 'skills/embedded-arch/SKILL.md'),
        (Join-Path $RepositoryRoot 'README.md')
    )
    foreach ($routeFile in $legacyRouteFiles) {
        if (Test-Path -LiteralPath $routeFile -PathType Leaf) {
            $routeContent = Get-StrictUtf8Text -Path $routeFile
            if ($routeContent -match 'guider-lvgl-port') {
                Add-Failure "Legacy Guider Skill name remains in an active route document: $routeFile"
            }
        }
    }

    $globalPromptPath = Join-Path $RepositoryRoot 'prompts/global.md'
    if (Test-Path -LiteralPath $globalPromptPath -PathType Leaf) {
        $globalPrompt = Get-StrictUtf8Text -Path $globalPromptPath
        foreach ($requiredRoute in @('coding-cpp-core', 'coding-c-safety', 'guider-engineering')) {
            if ($globalPrompt -notmatch [regex]::Escape($requiredRoute)) {
                Add-Failure "Global prompt is missing required route: $requiredRoute"
            }
        }
    }
}

$guiderSkillPath = Join-Path $skillsRoot 'guider-engineering'
$guiderSkillPrefix = $null
if (Test-Path -LiteralPath $guiderSkillPath -PathType Container) {
    $guiderSkillPrefix = ((Resolve-Path -LiteralPath $guiderSkillPath).Path.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar)
}

$unconditionalGeneratedPatterns = @(
    '(?i)generated/\s*(?:\u76ee\u5f55|directory|folder)?\s*(?:\u6574\u68f5|\u5168\u90e8|\u59cb\u7ec8)?\s*(?:\u53ea\u8bfb|read[- ]?only|\u7981\u6b62\u4fee\u6539)',
    '(?i)generated/\s*\u76ee\u5f55\u4e0b.*(?:\u53ea\u8bfb|\u7981\u6b62\u4fee\u6539|read[- ]?only)',
    '(?i)\u751f\u6210\u76ee\u5f55\s*(?:\u6574\u68f5|\u5168\u90e8|\u59cb\u7ec8)?\s*(?:\u53ea\u8bfb|read[- ]?only|\u7981\u6b62\u4fee\u6539)',
    '(?i)\u751f\u6210\u5c42\s*[\uff08(].*(?:\u53ea\u8bfb|\u7981\u6b62\u4fee\u6539|read[- ]?only)',
    '(?i)\u7981\u6b62\u4fee\u6539\s*generated/'
)
$documentationFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Force | Where-Object {
    $_.Extension -in @('.md', '.ps1', '.yml', '.yaml', '.json', '.toml')
})
$validationScriptPath = $null
if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) {
    $validationScriptPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
}
foreach ($documentationFile in $documentationFiles) {
    if ($null -ne $validationScriptPath -and $documentationFile.FullName -eq $validationScriptPath) {
        continue
    }

    if ($null -ne $guiderSkillPrefix -and $documentationFile.FullName.StartsWith($guiderSkillPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }

    $documentationLines = (Get-StrictUtf8Text -Path $documentationFile.FullName) -split "`r?`n"
    foreach ($documentationLine in $documentationLines) {
        $isUnconditional = $false
        foreach ($pattern in $unconditionalGeneratedPatterns) {
            if ($documentationLine -match $pattern) {
                $isUnconditional = $true
                break
            }
        }

        if ($isUnconditional -and $documentationLine -notmatch 'project-edit|source-edit') {
            Add-Failure "Unconditional generated/ read-only rule found; use task-specific routing: $($documentationFile.FullName)"
            break
        }
    }
}

function Test-MarkdownLinks {
    param([Parameter(Mandatory = $true)][string]$MarkdownFile)

    $markdownText = Get-StrictUtf8Text -Path $MarkdownFile
    $linkMatches = [regex]::Matches(
        $markdownText,
        '(?<!\!)\[[^\]\r\n]+\]\(\s*(?<target><[^>\r\n]+>|[^)\s]+)'
    )

    foreach ($linkMatch in $linkMatches) {
        $target = $linkMatch.Groups['target'].Value.Trim()
        if ($target.StartsWith('<') -and $target.EndsWith('>')) {
            $target = $target.Substring(1, $target.Length - 2)
        }

        if ([string]::IsNullOrWhiteSpace($target) -or $target.StartsWith('#')) {
            continue
        }

        if ($target -match '^(?i)(?:https?|ftp|mailto|tel|data|codex):') {
            continue
        }

        $target = $target.Split('#', 2)[0]
        if ([string]::IsNullOrWhiteSpace($target)) {
            continue
        }

        try {
            $target = [System.Uri]::UnescapeDataString($target)
        } catch {
            Add-Failure "Invalid URL-escaped Markdown link '$target' in: $MarkdownFile"
            continue
        }

        if ([IO.Path]::IsPathRooted($target) -or $target -match '^[A-Za-z]:[\\/]') {
            continue
        }

        $baseDirectory = Split-Path -Parent $MarkdownFile
        $resolvedTarget = [IO.Path]::GetFullPath((Join-Path $baseDirectory $target))
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            Add-Failure "Broken relative Markdown link '$target' in: $MarkdownFile"
        }
    }
}

$markdownFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Force | Where-Object {
    $_.Extension -eq '.md' -and $_.FullName -notlike "$(Join-Path $RepositoryRoot '.git')*"
})
foreach ($markdownFile in $markdownFiles) {
    Test-MarkdownLinks -MarkdownFile $markdownFile.FullName
}

$sensitiveFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Force | Where-Object {
    $_.Extension -in @('.db', '.sqlite', '.sqlite3') -or $_.Name -match '^(\.env|credentials|secrets)$'
})
foreach ($file in $sensitiveFiles) {
    Add-Failure "Sensitive or local state file found: $($file.FullName)"
}

$allTextFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Force | Where-Object {
    $_.Extension -in @('.md', '.ps1', '.yml', '.yaml', '.json', '.toml')
})
foreach ($file in $allTextFiles) {
    $text = Get-StrictUtf8Text -Path $file.FullName
    if ($text -match '(?i)(api[_-]?key|access[_-]?token|secret[_-]?key|password\s*[:=])') {
        Add-Failure "Possible secret or password field found: $($file.FullName)"
    }
}

if ($failed) {
    exit 1
}

Write-Output "Skill validation passed: $($skillDirectories.Count) skills."
