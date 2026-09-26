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

if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
    throw "Repository directory not found: $RepositoryRoot"
}

$skillsRoot = Join-Path $RepositoryRoot 'skills'
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

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
        Add-Failure "skills directory not found: $skillsRoot"
} else {
    $skillDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force | Sort-Object Name)
    if ($skillDirectories.Count -ne 13) {
        Add-Failure "Expected 13 skills, found $($skillDirectories.Count)."
    }

    foreach ($skillDirectory in $skillDirectories) {
        if ($skillDirectory.Name -in $excludedOfficialSkills) {
            Add-Failure "Excluded official Lark skill found: $($skillDirectory.Name)"
        }

        $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-Failure "SKILL.md is missing: $skillFile"
            continue
        }

        $content = Get-Content -LiteralPath $skillFile -Raw -Encoding UTF8
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

        $absolutePathPattern = '(?i)[A-Z]:\\|/Users/|/home/'
        if ($content -match $absolutePathPattern) {
            Add-Failure "Skill appears to contain a local absolute path: $skillFile"
        }
    }
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
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($text -match '(?i)(api[_-]?key|access[_-]?token|secret[_-]?key|password\s*[:=])') {
        Add-Failure "Possible secret or password field found: $($file.FullName)"
    }
}

if ($failed) {
    exit 1
}

Write-Output "Skill validation passed: $($skillDirectories.Count) skills."
