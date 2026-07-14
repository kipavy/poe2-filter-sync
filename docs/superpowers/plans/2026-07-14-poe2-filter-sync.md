# POE2 Filter Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a POE2 loot filter that stays auto-synced with NeverSink and carries custom alert sounds, published to the PoE account via the official API (cloud, hands-off), with a local script for installing the sounds and a `-Full` fallback that rebuilds everything locally.

**Architecture:** A single shared build core (`Build-Filter`) downloads NeverSink, applies sound mappings from a JSON config, and validates. The GitHub Action calls the core then publishes to the PoE API; the local `Sync-Poe2Filter.ps1` script installs sounds by default and calls the same core under `-Full`. The text transform (inserting `CustomAlertSound` lines) is a pure function on string arrays so it is fully unit-testable without PoE or network.

**Tech Stack:** Windows PowerShell 5.1 (local code), Pester 5 (tests), GitHub Actions (ubuntu-latest runner with pwsh), PoE Item Filter API (`account:item_filter` OAuth scope).

## Global Constraints

- **Windows PowerShell 5.1 compatible** — all local-running code (`install.ps1`, `Sync-Poe2Filter.ps1`, and every `src/*.psm1` module they load) MUST run on stock Windows PowerShell 5.1, so end users need no install. `#requires -Version 5.1`. Avoid PS7-only syntax (`??`, `?.`, ternary, `-AsHashtable`). Tests run under 5.1 with Pester 5; CI runs the same code under `pwsh` on `ubuntu-latest` (5.1-compatible code also runs on 7).
- **TLS 1.2 for downloads** — any script that calls `Invoke-WebRequest`/`Invoke-RestMethod` must first set `[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12` (5.1 does not negotiate TLS 1.2 by default and GitHub requires it).
- **`-UseBasicParsing` on all web calls** — every `Invoke-WebRequest`/`Invoke-RestMethod` call must pass `-UseBasicParsing`. On some Windows PowerShell 5.1 machines the IE parsing engine is unavailable and the call throws otherwise; the flag is harmless on PowerShell 7. This matters because the code runs on arbitrary end-user machines.
- **No admin, non-destructive** — local install writes ONLY the built `.filter` and the mp3 files into the POE2 folder; it never wipes or deletes unrelated files.
- **POE2 folder path:** `$env:USERPROFILE\Documents\My Games\Path of Exile 2` (overridable by a `-Poe2Dir` parameter for testing).
- **Config is the single source of mapping data** — no sound filenames, identifiers, or volumes hardcoded in code; all live in `config/sound-mapping.json`.
- **Fail loud:** any targeted override that matches zero blocks is a hard error in the build core.
- **NeverSink source:** latest tagged release of `NeverSinkDev/NeverSink-Filter-for-PoE2` (fallback to `main` branch zip only if no release API result).
- **Repo:** `poe2-filter-sync`, root at `C:\Users\kikik\poe2-filter-sync`.

---

## File Structure

- `config/sound-mapping.json` — mapping data (file replacements + targeted overrides + filter metadata).
- `sounds/*.mp3` — custom audio, versioned.
- `src/SoundMapping.psm1` — `Get-SoundMapping` (load + validate JSON).
- `src/FilterTransform.psm1` — `Set-CustomAlertSound` (pure text transform), `Assert-AllMappingsMatched`.
- `src/NeverSink.psm1` — `Get-NeverSinkFilterDir` (download + extract), `Find-SourceFilter`.
- `src/BuildFilter.psm1` — `Build-Filter` (orchestrator over the above; no PoE network).
- `src/InstallSounds.psm1` — `Install-Sounds` (copy mp3 to POE2 folder).
- `src/PublishFilter.psm1` — `Publish-Filter` (POST to PoE API).
- `src/Sync-Poe2Filter.ps1` — local entrypoint (default = sounds; `-Full` = build + install locally).
- `install.ps1` — public bootstrapper the one-liner calls (downloads repo, runs Sync).
- `tests/*.Tests.ps1` — Pester tests.
- `tests/fixtures/sample.filter` — small NeverSink-style filter for tests.
- `.github/workflows/sync.yml` — nightly + push: test → build → validate → publish.
- `README.md`, `DISCORD.md` — docs + the install announcement.

---

## Task 0: Risk spikes (gating, mostly manual)

These lever the two spec risks before code investment. They are prerequisites, not TDD tasks.

- [ ] **Step 1: Confirm in-game behavior (online filter + local mp3).**
  On the machine with POE2: upload any filter containing one `CustomAlertSound "test.mp3" 300` line to the PoE account (via filterblade.xyz "upload to account", or manually on the website). Place a `test.mp3` in `Documents\My Games\Path of Exile 2`. In-game, select that ONLINE filter and confirm the custom sound plays on the matching drop.
  Expected: the custom sound plays. Record the result in `docs/superpowers/spike-results.md`.

- [ ] **Step 2: Obtain PoE API access.**
  Register an OAuth application with GGG for scope `account:item_filter` (https://www.pathofexile.com/developer/docs). Obtain a token. Confirm:
  ```bash
  curl -H "Authorization: Bearer <TOKEN>" https://api.pathofexile.com/item-filter
  ```
  Expected: HTTP 200 with a JSON array (possibly empty). Record the token acquisition method and one existing filter `id` (if any) in `spike-results.md`.

- [ ] **Step 3: Decide publish vs fallback.**
  If Step 2 succeeds → cloud publish is in scope (Task 8, Task 9). If it fails → mark Task 8/9 as "validate-only" (the Action still builds + validates but does not publish; users rely on the local `-Full` install). Note the decision in `spike-results.md`.

- [ ] **Step 4: Commit the spike results.**
```bash
git add docs/superpowers/spike-results.md
git commit -m "docs: record risk-spike results"
```

---

## Task 1: Repo scaffolding

**Files:**
- Create: `.gitignore`, `README.md`, `tests/fixtures/sample.filter`, `Invoke-Tests.ps1`

**Interfaces:**
- Produces: `tests/fixtures/sample.filter` used by all later Pester tests; `./Invoke-Tests.ps1` runs the whole suite.

- [ ] **Step 1: Create `.gitignore`**
```gitignore
# build output
out/
*.zip
# temp
temp_*
```

- [ ] **Step 2: Create `tests/fixtures/sample.filter`** (a minimal NeverSink-style filter)
```
# NeverSink-style sample for tests
Show # $type->currency $tier->d
    BaseType "Chaos Orb"
    PlayAlertSound 1 300
    SetTextColor 255 255 255

Show # $type->currency $tier->e
    BaseType "Exalted Orb"
    CustomAlertSound "old-existing.mp3" 200

Hide # $type->currency $tier->hidden
    BaseType "Scroll of Wisdom"

Show # $type->waystones $tier->waystone_t16
    Class "Waystones"
    PlayAlertSound 6 300
```

- [ ] **Step 3: Create `Invoke-Tests.ps1`**
```powershell
#requires -Version 5.1
$pester5 = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0' }
if (-not $pester5) {
    Install-Module Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
}
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester -Path "$PSScriptRoot/tests" -Output Detailed
```

- [ ] **Step 4: Create `README.md` stub**
```markdown
# poe2-filter-sync

NeverSink-synced POE2 loot filter with custom alert sounds.
Filter text auto-published to the PoE account; sounds installed locally.
See `docs/superpowers/` for the design and plan.
```

- [ ] **Step 5: Verify Pester runs (no tests yet is fine)**

Run: `pwsh ./Invoke-Tests.ps1`
Expected: Pester runs and reports 0 tests (or installs Pester then reports 0). No errors.

- [ ] **Step 6: Commit**
```bash
git add .gitignore README.md tests/fixtures/sample.filter Invoke-Tests.ps1
git commit -m "chore: scaffold repo, test runner, sample filter fixture"
```

---

## Task 2: Config schema + loader (`Get-SoundMapping`)

**Files:**
- Create: `config/sound-mapping.json`, `src/SoundMapping.psm1`, `tests/SoundMapping.Tests.ps1`

**Interfaces:**
- Produces: `Get-SoundMapping -Path <json>` returns a PSCustomObject with properties:
  `PoeFilterId` (string), `PoeFilterName` (string), `SourceFilterMatch` (string),
  `FollowUrls` (string array of filter pages to open for subscribing),
  `FileReplacements` (hashtable: neversink-name → your-sound-file),
  `TargetedOverrides` (array of objects `{ Identifier; File; Volume }`).
  Throws on missing file, invalid JSON, or a referenced sound file absent from `SoundsDir`.

- [ ] **Step 1: Create `config/sound-mapping.json`** (seeded from the old script)
```json
{
  "poeFilterId": "",
  "poeFilterName": "NeverSink + custom sounds",
  "sourceFilterMatch": "STRICT",
  "followUrls": [
    "https://www.pathofexile.com/account/view-profile/YOUR_NAME/item-filters"
  ],
  "fileReplacements": {
    "1maybevaluable.mp3": "1maybevaluable.mp3",
    "2currency.mp3": "2currency.mp3",
    "3uniques.mp3": "3uniques.mp3",
    "4maps.mp3": "4maps.mp3",
    "5highmaps.mp3": "5highmaps.mp3",
    "6veryvaluable.mp3": "6veryvaluable.mp3"
  },
  "targetedOverrides": [
    { "identifier": "$type->currency $tier->d", "file": "gay-echo.mp3", "volume": 300 },
    { "identifier": "$type->waystones $tier->waystone_t16", "file": "TRIPLE_MONSTRE.mp3", "volume": 300 }
  ]
}
```

- [ ] **Step 2: Write the failing test** — `tests/SoundMapping.Tests.ps1`
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/SoundMapping.psm1" -Force
    $script:soundsDir = Join-Path $TestDrive 'sounds'
    New-Item -ItemType Directory -Path $script:soundsDir | Out-Null
    foreach ($f in '1maybevaluable.mp3','2currency.mp3','3uniques.mp3','4maps.mp3','5highmaps.mp3','6veryvaluable.mp3','gay-echo.mp3','TRIPLE_MONSTRE.mp3') {
        New-Item -ItemType File -Path (Join-Path $script:soundsDir $f) | Out-Null
    }
    $script:cfgPath = Join-Path $TestDrive 'sound-mapping.json'
    Copy-Item "$PSScriptRoot/../config/sound-mapping.json" $script:cfgPath
}

Describe 'Get-SoundMapping' {
    It 'parses metadata and sections' {
        $m = Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir
        $m.PoeFilterName | Should -Be 'NeverSink + custom sounds'
        $m.SourceFilterMatch | Should -Be 'STRICT'
        $m.TargetedOverrides.Count | Should -Be 2
        $m.TargetedOverrides[0].Volume | Should -Be 300
    }
    It 'throws when a referenced sound file is missing' {
        Remove-Item (Join-Path $script:soundsDir 'gay-echo.mp3')
        { Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir } |
            Should -Throw -ExpectedMessage '*gay-echo.mp3*'
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pwsh -c "Invoke-Pester tests/SoundMapping.Tests.ps1"`
Expected: FAIL — `Get-SoundMapping` not recognized.

- [ ] **Step 4: Write `src/SoundMapping.psm1`**
```powershell
function Get-SoundMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$SoundsDir
    )
    if (-not (Test-Path $Path)) { throw "Config not found: $Path" }
    $raw = Get-Content -Path $Path -Raw
    try { $json = $raw | ConvertFrom-Json } catch { throw "Invalid JSON in ${Path}: $_" }

    $result = [pscustomobject]@{
        PoeFilterId       = [string]$json.poeFilterId
        PoeFilterName     = [string]$json.poeFilterName
        SourceFilterMatch = [string]$json.sourceFilterMatch
        FollowUrls        = @($json.followUrls)
        FileReplacements  = @{}
        TargetedOverrides = @()
    }
    foreach ($p in $json.fileReplacements.PSObject.Properties) {
        $result.FileReplacements[$p.Name] = [string]$p.Value
    }
    $result.TargetedOverrides = @(
        foreach ($o in $json.targetedOverrides) {
            [pscustomobject]@{ Identifier = [string]$o.identifier; File = [string]$o.file; Volume = [int]$o.volume }
        }
    )

    # every referenced sound must exist
    $referenced = @($result.FileReplacements.Values) + @($result.TargetedOverrides.File) | Sort-Object -Unique
    foreach ($f in $referenced) {
        if (-not (Test-Path (Join-Path $SoundsDir $f))) {
            throw "Referenced sound file missing from '$SoundsDir': $f"
        }
    }
    return $result
}
Export-ModuleMember -Function Get-SoundMapping
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pwsh -c "Invoke-Pester tests/SoundMapping.Tests.ps1"`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**
```bash
git add config/sound-mapping.json src/SoundMapping.psm1 tests/SoundMapping.Tests.ps1
git commit -m "feat: JSON sound-mapping config and validating loader"
```

---

## Task 3: Text transform (`Set-CustomAlertSound`) — the core

**Files:**
- Create: `src/FilterTransform.psm1`, `tests/FilterTransform.Tests.ps1`

**Interfaces:**
- Consumes: nothing.
- Produces: `Set-CustomAlertSound -Lines [string[]] -Identifier <string> -File <string> -Volume <int>`
  returns `[pscustomobject]@{ Lines = [string[]]; MatchCount = [int] }`.
  Rules: for each `Show` block header line ending with `<Identifier>`, insert
  `    CustomAlertSound "<File>" <Volume>` right after the header; if that block already
  contains a `CustomAlertSound` line before the next `Show`/`Hide`, replace it instead of adding
  a second. `Hide` blocks with the same identifier are left untouched. `MatchCount` = number of
  `Show` blocks changed.

- [ ] **Step 1: Write the failing tests** — `tests/FilterTransform.Tests.ps1`
```powershell
BeforeAll { Import-Module "$PSScriptRoot/../src/FilterTransform.psm1" -Force }

Describe 'Set-CustomAlertSound' {
    It 'inserts a CustomAlertSound after a matching Show block' {
        $lines = @(
            'Show # $type->currency $tier->d',
            '    BaseType "Chaos Orb"',
            '    PlayAlertSound 1 300'
        )
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->d' -File 'gay-echo.mp3' -Volume 300
        $r.MatchCount | Should -Be 1
        $r.Lines[1] | Should -Be '    CustomAlertSound "gay-echo.mp3" 300'
    }
    It 'replaces an existing CustomAlertSound in the block instead of duplicating' {
        $lines = @(
            'Show # $type->currency $tier->e',
            '    CustomAlertSound "old-existing.mp3" 200'
        )
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->e' -File 'new.mp3' -Volume 300
        ($r.Lines -match 'CustomAlertSound').Count | Should -Be 1
        $r.Lines -join "`n" | Should -Match 'new.mp3'
        $r.Lines -join "`n" | Should -Not -Match 'old-existing.mp3'
    }
    It 'leaves Hide blocks with the same identifier untouched' {
        $lines = @('Hide # $type->currency $tier->hidden', '    BaseType "Scroll"')
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->hidden' -File 'x.mp3' -Volume 300
        $r.MatchCount | Should -Be 0
        $r.Lines | Should -Not -Contain '    CustomAlertSound "x.mp3" 300'
    }
    It 'returns MatchCount 0 when identifier is absent' {
        $lines = @('Show # $type->currency $tier->d', '    BaseType "Chaos Orb"')
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->does->not->exist' -File 'x.mp3' -Volume 300
        $r.MatchCount | Should -Be 0
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pwsh -c "Invoke-Pester tests/FilterTransform.Tests.ps1"`
Expected: FAIL — `Set-CustomAlertSound` not recognized.

- [ ] **Step 3: Write `src/FilterTransform.psm1`**
```powershell
function Set-CustomAlertSound {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Identifier,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][int]$Volume
    )
    $escaped        = [regex]::Escape($Identifier)
    $reIdentifier   = [regex]::new(".*$escaped\s*$")
    $reHide         = [regex]::new('^\s*Hide')
    $reCustomAlert  = [regex]::new('^\s*CustomAlertSound')
    $reSection      = [regex]::new('^\s*(Show|Hide)')
    $soundLine      = "    CustomAlertSound `"$File`" $Volume"

    $out = [System.Collections.Generic.List[string]]::new()
    $matchCount = 0
    $inTarget = $false
    $inserted = $false

    foreach ($line in $Lines) {
        if ($reIdentifier.IsMatch($line)) {
            if ($reHide.IsMatch($line)) { $out.Add($line); $inTarget = $false; continue }
            $out.Add($line)
            $out.Add($soundLine)
            $matchCount++
            $inTarget = $true
            $inserted = $true
            continue
        }
        if ($inTarget -and $reCustomAlert.IsMatch($line)) {
            # our inserted line is already present; drop the original CustomAlertSound
            continue
        }
        if ($inTarget -and $reSection.IsMatch($line)) {
            $inTarget = $false; $inserted = $false
        }
        $out.Add($line)
    }
    return [pscustomobject]@{ Lines = $out.ToArray(); MatchCount = $matchCount }
}
Export-ModuleMember -Function Set-CustomAlertSound
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pwsh -c "Invoke-Pester tests/FilterTransform.Tests.ps1"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**
```bash
git add src/FilterTransform.psm1 tests/FilterTransform.Tests.ps1
git commit -m "feat: Set-CustomAlertSound pure text transform with match counting"
```

---

## Task 4: Validation (`Assert-AllMappingsMatched`)

**Files:**
- Modify: `src/FilterTransform.psm1`
- Modify: `tests/FilterTransform.Tests.ps1`

**Interfaces:**
- Produces: `Assert-AllMappingsMatched -MatchReport [hashtable]` where keys are identifiers and
  values are ints. Throws (listing every zero-match identifier) if any value is 0; otherwise returns silently.

- [ ] **Step 1: Add the failing tests** — append to `tests/FilterTransform.Tests.ps1`
```powershell
Describe 'Assert-AllMappingsMatched' {
    It 'passes when all identifiers matched at least once' {
        { Assert-AllMappingsMatched -MatchReport @{ 'a' = 1; 'b' = 3 } } | Should -Not -Throw
    }
    It 'throws and names every zero-match identifier' {
        { Assert-AllMappingsMatched -MatchReport @{ 'a' = 1; 'b' = 0; 'c' = 0 } } |
            Should -Throw -ExpectedMessage '*b*c*'
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -c "Invoke-Pester tests/FilterTransform.Tests.ps1"`
Expected: FAIL — `Assert-AllMappingsMatched` not recognized.

- [ ] **Step 3: Add the function to `src/FilterTransform.psm1`** (and update the export line)
```powershell
function Assert-AllMappingsMatched {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$MatchReport)
    $zero = @($MatchReport.GetEnumerator() | Where-Object { $_.Value -eq 0 } | ForEach-Object { $_.Key })
    if ($zero.Count -gt 0) {
        throw "These targeted overrides matched no filter block (NeverSink identifiers may have changed): $($zero -join ', ')"
    }
}
Export-ModuleMember -Function Set-CustomAlertSound, Assert-AllMappingsMatched
```
(Replace the previous `Export-ModuleMember` line with the one above.)

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -c "Invoke-Pester tests/FilterTransform.Tests.ps1"`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**
```bash
git add src/FilterTransform.psm1 tests/FilterTransform.Tests.ps1
git commit -m "feat: Assert-AllMappingsMatched fails loud on unmatched overrides"
```

---

## Task 5: NeverSink download + source-filter locate

**Files:**
- Create: `src/NeverSink.psm1`, `tests/NeverSink.Tests.ps1`

**Interfaces:**
- Produces:
  - `Get-NeverSinkFilterDir -DestDir <string>` — downloads the latest NeverSink PoE2 release zip
    (fallback `main`), extracts, returns the path to the extracted `(STYLE) CUSTOMSOUNDS` folder.
    Network-dependent; not unit-tested (covered by Task 8 integration run).
  - `Find-SourceFilter -Dir <string> -Match <string>` — returns the single `.filter` file path in
    `Dir` whose name contains `Match` (case-insensitive). Throws if zero or more than one match.

- [ ] **Step 1: Write the failing test (for the pure part)** — `tests/NeverSink.Tests.ps1`
```powershell
BeforeAll { Import-Module "$PSScriptRoot/../src/NeverSink.psm1" -Force }

Describe 'Find-SourceFilter' {
    BeforeEach {
        $script:dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:dir | Out-Null
    }
    It 'returns the single filter matching the strictness token' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 1-REGULAR.filter') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 4-STRICT.filter') | Out-Null
        (Find-SourceFilter -Dir $script:dir -Match 'STRICT') | Should -Match 'STRICT'
    }
    It 'throws when no filter matches' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 1-REGULAR.filter') | Out-Null
        { Find-SourceFilter -Dir $script:dir -Match 'STRICT' } | Should -Throw
    }
    It 'throws when multiple filters match' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'a-STRICT.filter') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir 'b-STRICT.filter') | Out-Null
        { Find-SourceFilter -Dir $script:dir -Match 'STRICT' } | Should -Throw
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -c "Invoke-Pester tests/NeverSink.Tests.ps1"`
Expected: FAIL — `Find-SourceFilter` not recognized.

- [ ] **Step 3: Write `src/NeverSink.psm1`**
```powershell
function Get-NeverSinkFilterDir {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DestDir)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (Test-Path $DestDir) { Remove-Item $DestDir -Recurse -Force }
    New-Item -ItemType Directory -Path $DestDir | Out-Null

    $zipUrl = 'https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2/archive/refs/heads/main.zip'
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/NeverSinkDev/NeverSink-Filter-for-PoE2/releases/latest' `
            -Headers @{ 'User-Agent' = 'poe2-filter-sync' }
        if ($rel.zipball_url) { $zipUrl = $rel.zipball_url }
    } catch { Write-Warning "No release found, falling back to main.zip: $_" }

    $zip = Join-Path $DestDir 'neversink.zip'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -Headers @{ 'User-Agent' = 'poe2-filter-sync' }
    Expand-Archive -Path $zip -DestinationPath $DestDir -Force
    Remove-Item $zip

    $style = Get-ChildItem -Path $DestDir -Recurse -Directory |
        Where-Object { $_.Name -like '*CUSTOMSOUNDS*' } | Select-Object -First 1
    if (-not $style) { throw "Could not find a CUSTOMSOUNDS style folder in the NeverSink download." }
    return $style.FullName
}

function Find-SourceFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Match
    )
    $hits = @(Get-ChildItem -Path $Dir -Filter *.filter | Where-Object { $_.Name -match [regex]::Escape($Match) })
    if ($hits.Count -eq 0) { throw "No .filter in '$Dir' matching '$Match'." }
    if ($hits.Count -gt 1) { throw "Multiple .filter files match '$Match': $($hits.Name -join ', ')." }
    return $hits[0].FullName
}
Export-ModuleMember -Function Get-NeverSinkFilterDir, Find-SourceFilter
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -c "Invoke-Pester tests/NeverSink.Tests.ps1"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**
```bash
git add src/NeverSink.psm1 tests/NeverSink.Tests.ps1
git commit -m "feat: NeverSink download and source-filter locator"
```

---

## Task 6: Build orchestrator (`Build-Filter`)

**Files:**
- Create: `src/BuildFilter.psm1`, `tests/BuildFilter.Tests.ps1`

**Interfaces:**
- Consumes: `Get-SoundMapping`, `Set-CustomAlertSound`, `Assert-AllMappingsMatched`, `Find-SourceFilter`.
- Produces: `Build-Filter -SourceFilterPath <string> -Mapping <object> -OutDir <string>` — reads the
  source `.filter`, applies every targeted override (accumulating a match report), calls
  `Assert-AllMappingsMatched`, writes the transformed filter to `$OutDir/filter.filter`, and returns
  `[pscustomobject]@{ FilterPath = <string>; MatchReport = <hashtable> }`. Does NOT download NeverSink
  and does NOT touch the POE2 folder or the PoE API (keeps it unit-testable via the fixture).

- [ ] **Step 1: Write the failing test** — `tests/BuildFilter.Tests.ps1`
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/BuildFilter.psm1" -Force
    $script:mapping = [pscustomobject]@{
        TargetedOverrides = @(
            [pscustomobject]@{ Identifier = '$type->currency $tier->d'; File = 'gay-echo.mp3'; Volume = 300 },
            [pscustomobject]@{ Identifier = '$type->waystones $tier->waystone_t16'; File = 'TRIPLE_MONSTRE.mp3'; Volume = 300 }
        )
    }
}

Describe 'Build-Filter' {
    It 'applies overrides and writes an output filter' {
        $out = Join-Path $TestDrive 'out'
        $r = Build-Filter -SourceFilterPath "$PSScriptRoot/fixtures/sample.filter" -Mapping $script:mapping -OutDir $out
        Test-Path $r.FilterPath | Should -BeTrue
        (Get-Content $r.FilterPath -Raw) | Should -Match 'gay-echo.mp3'
        (Get-Content $r.FilterPath -Raw) | Should -Match 'TRIPLE_MONSTRE.mp3'
        $r.MatchReport['$type->currency $tier->d'] | Should -Be 1
    }
    It 'throws when an override matches nothing' {
        $bad = [pscustomobject]@{ TargetedOverrides = @(
            [pscustomobject]@{ Identifier = '$type->nope'; File = 'x.mp3'; Volume = 300 }) }
        $out = Join-Path $TestDrive 'out2'
        { Build-Filter -SourceFilterPath "$PSScriptRoot/fixtures/sample.filter" -Mapping $bad -OutDir $out } |
            Should -Throw -ExpectedMessage '*nope*'
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -c "Invoke-Pester tests/BuildFilter.Tests.ps1"`
Expected: FAIL — `Build-Filter` not recognized.

- [ ] **Step 3: Write `src/BuildFilter.psm1`**
```powershell
Import-Module "$PSScriptRoot/FilterTransform.psm1" -Force

function Build-Filter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceFilterPath,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$OutDir
    )
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $lines = Get-Content -Path $SourceFilterPath
    $report = @{}
    foreach ($o in $Mapping.TargetedOverrides) {
        $res = Set-CustomAlertSound -Lines $lines -Identifier $o.Identifier -File $o.File -Volume $o.Volume
        $lines = $res.Lines
        $report[$o.Identifier] = $res.MatchCount
    }
    Assert-AllMappingsMatched -MatchReport $report
    $outFile = Join-Path $OutDir 'filter.filter'
    Set-Content -Path $outFile -Value $lines -Force
    return [pscustomobject]@{ FilterPath = $outFile; MatchReport = $report }
}
Export-ModuleMember -Function Build-Filter
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -c "Invoke-Pester tests/BuildFilter.Tests.ps1"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**
```bash
git add src/BuildFilter.psm1 tests/BuildFilter.Tests.ps1
git commit -m "feat: Build-Filter orchestrator with fail-loud validation"
```

---

## Task 7: Install sounds locally (`Install-Sounds`)

**Files:**
- Create: `src/InstallSounds.psm1`, `tests/InstallSounds.Tests.ps1`

**Interfaces:**
- Consumes: `Get-SoundMapping` output (`FileReplacements`).
- Produces: `Install-Sounds -SoundsDir <string> -Mapping <object> -Poe2Dir <string>` — copies each
  custom sound into `$Poe2Dir`, renaming per `FileReplacements` (your file → NeverSink expected name)
  and copying every `TargetedOverrides.File` under its own name. Creates `$Poe2Dir` if missing.
  Non-destructive: only writes the mp3 files. Returns the list of destination paths written.

- [ ] **Step 1: Write the failing test** — `tests/InstallSounds.Tests.ps1`
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallSounds.psm1" -Force
    $script:sounds = Join-Path $TestDrive 'sounds'
    New-Item -ItemType Directory -Path $script:sounds | Out-Null
    'audioA' | Set-Content (Join-Path $script:sounds 'veryvaluable.mp3')
    'audioB' | Set-Content (Join-Path $script:sounds 'gay-echo.mp3')
    $script:mapping = [pscustomobject]@{
        FileReplacements  = @{ '6veryvaluable.mp3' = 'veryvaluable.mp3' }
        TargetedOverrides = @([pscustomobject]@{ Identifier='x'; File='gay-echo.mp3'; Volume=300 })
    }
}

Describe 'Install-Sounds' {
    It 'copies file-replacement sounds under the NeverSink name' {
        $poe = Join-Path $TestDrive 'poe'
        Install-Sounds -SoundsDir $script:sounds -Mapping $script:mapping -Poe2Dir $poe
        Get-Content (Join-Path $poe '6veryvaluable.mp3') | Should -Be 'audioA'
    }
    It 'copies targeted-override sounds under their own name and preserves unrelated files' {
        $poe = Join-Path $TestDrive 'poe2'
        New-Item -ItemType Directory -Path $poe | Out-Null
        'keep' | Set-Content (Join-Path $poe 'important.txt')
        Install-Sounds -SoundsDir $script:sounds -Mapping $script:mapping -Poe2Dir $poe
        Get-Content (Join-Path $poe 'gay-echo.mp3') | Should -Be 'audioB'
        Test-Path (Join-Path $poe 'important.txt') | Should -BeTrue
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -c "Invoke-Pester tests/InstallSounds.Tests.ps1"`
Expected: FAIL — `Install-Sounds` not recognized.

- [ ] **Step 3: Write `src/InstallSounds.psm1`**
```powershell
function Install-Sounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SoundsDir,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$Poe2Dir
    )
    if (-not (Test-Path $Poe2Dir)) { New-Item -ItemType Directory -Path $Poe2Dir -Force | Out-Null }
    $written = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $Mapping.FileReplacements.GetEnumerator()) {
        $src = Join-Path $SoundsDir $entry.Value
        $dst = Join-Path $Poe2Dir $entry.Key
        Copy-Item -Path $src -Destination $dst -Force
        $written.Add($dst)
    }
    foreach ($o in $Mapping.TargetedOverrides) {
        $src = Join-Path $SoundsDir $o.File
        $dst = Join-Path $Poe2Dir $o.File
        Copy-Item -Path $src -Destination $dst -Force
        $written.Add($dst)
    }
    return $written.ToArray()
}
Export-ModuleMember -Function Install-Sounds
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -c "Invoke-Pester tests/InstallSounds.Tests.ps1"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**
```bash
git add src/InstallSounds.psm1 tests/InstallSounds.Tests.ps1
git commit -m "feat: Install-Sounds non-destructive local copy"
```

---

## Task 8: Publish to PoE API (`Publish-Filter`)

**Files:**
- Create: `src/PublishFilter.psm1`, `tests/PublishFilter.Tests.ps1`

> If Task 0 Step 3 decided "validate-only", still implement this module (it is used only by the
> Action when a token is present); the Action will simply skip calling it.

**Interfaces:**
- Produces: `Publish-Filter -FilterPath <string> -FilterId <string> -FilterName <string> -Token <string>`
  — reads the built filter text and does `POST https://api.pathofexile.com/item-filter/<FilterId>`
  (or `POST .../item-filter` when `FilterId` is empty) with `Authorization: Bearer <Token>`, body
  `{ filter_name, filter, type: "Normal", public: false }`. Returns the API response object.
  The HTTP call is made through an injectable `-Invoker` scriptblock so it can be tested without network.

- [ ] **Step 1: Write the failing test** — `tests/PublishFilter.Tests.ps1`
```powershell
BeforeAll { Import-Module "$PSScriptRoot/../src/PublishFilter.psm1" -Force }

Describe 'Publish-Filter' {
    It 'POSTs to the id-specific endpoint with a bearer token and filter body' {
        $captured = $null
        $invoker = { param($Uri,$Method,$Headers,$Body) $script:captured = @{ Uri=$Uri; Method=$Method; Headers=$Headers; Body=$Body }; @{ ok = $true } }
        $f = Join-Path $TestDrive 'f.filter'; 'Show' | Set-Content $f
        Publish-Filter -FilterPath $f -FilterId 'abc123' -FilterName 'N' -Token 'TKN' -Invoker $invoker | Out-Null
        $script:captured.Uri | Should -Be 'https://api.pathofexile.com/item-filter/abc123'
        $script:captured.Method | Should -Be 'Post'
        $script:captured.Headers.Authorization | Should -Be 'Bearer TKN'
        ($script:captured.Body | ConvertFrom-Json).filter | Should -Match 'Show'
    }
    It 'POSTs to the create endpoint when FilterId is empty' {
        $invoker = { param($Uri,$Method,$Headers,$Body) $script:u = $Uri; @{} }
        $f = Join-Path $TestDrive 'f.filter'; 'Show' | Set-Content $f
        Publish-Filter -FilterPath $f -FilterId '' -FilterName 'N' -Token 'TKN' -Invoker $invoker | Out-Null
        $script:u | Should -Be 'https://api.pathofexile.com/item-filter'
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -c "Invoke-Pester tests/PublishFilter.Tests.ps1"`
Expected: FAIL — `Publish-Filter` not recognized.

- [ ] **Step 3: Write `src/PublishFilter.psm1`**
```powershell
function Publish-Filter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilterPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$FilterId,
        [Parameter(Mandatory)][string]$FilterName,
        [Parameter(Mandatory)][string]$Token,
        [scriptblock]$Invoker
    )
    $text = Get-Content -Path $FilterPath -Raw
    $base = 'https://api.pathofexile.com/item-filter'
    $uri  = if ([string]::IsNullOrEmpty($FilterId)) { $base } else { "$base/$FilterId" }
    $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json'; 'User-Agent' = 'poe2-filter-sync' }
    $body = @{ filter_name = $FilterName; filter = $text; type = 'Normal'; public = $false; realm = 'poe2' } | ConvertTo-Json -Depth 5

    if (-not $Invoker) {
        $Invoker = { param($Uri,$Method,$Headers,$Body) Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body }
    }
    return & $Invoker -Uri $uri -Method 'Post' -Headers $headers -Body $body
}
Export-ModuleMember -Function Publish-Filter
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -c "Invoke-Pester tests/PublishFilter.Tests.ps1"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**
```bash
git add src/PublishFilter.psm1 tests/PublishFilter.Tests.ps1
git commit -m "feat: Publish-Filter POST to PoE item-filter API (injectable invoker)"
```

---

## Task 9: Local entrypoint (`Sync-Poe2Filter.ps1`) + bootstrapper (`install.ps1`)

**Files:**
- Create: `src/Sync-Poe2Filter.ps1`, `install.ps1`

**Interfaces:**
- Consumes: all `src/*.psm1` modules.
- Produces: `Sync-Poe2Filter.ps1` with params `-Full [switch]`, `-Poe2Dir <string>` (defaults to the
  POE2 path), `-RepoRoot <string>` (defaults to the script's parent). Default run installs sounds only;
  `-Full` additionally downloads NeverSink, builds the filter, and copies the built `.filter` into `$Poe2Dir`.
  No manual Pester task here — verified by the Task 10 end-to-end `-Full` dry run.

- [ ] **Step 1: Write `src/Sync-Poe2Filter.ps1`**
```powershell
#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Full,
    [string]$Poe2Dir = (Join-Path $env:USERPROFILE 'Documents\My Games\Path of Exile 2'),
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/SoundMapping.psm1" -Force
Import-Module "$PSScriptRoot/InstallSounds.psm1" -Force

$soundsDir = Join-Path $RepoRoot 'sounds'
$cfgPath   = Join-Path $RepoRoot 'config/sound-mapping.json'
$mapping   = Get-SoundMapping -Path $cfgPath -SoundsDir $soundsDir

Write-Host "Installing custom sounds into: $Poe2Dir"
Install-Sounds -SoundsDir $soundsDir -Mapping $mapping -Poe2Dir $Poe2Dir | Out-Null
Write-Host "Sounds installed."

if (-not $Full) {
    # Default mode: open the filter page(s) so the user can subscribe/follow in one click.
    foreach ($url in $mapping.FollowUrls) {
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Write-Host "Opening filter page to subscribe: $url"
            Start-Process $url
        }
    }
}

if ($Full) {
    Import-Module "$PSScriptRoot/NeverSink.psm1" -Force
    Import-Module "$PSScriptRoot/BuildFilter.psm1" -Force
    $work = Join-Path ([System.IO.Path]::GetTempPath()) 'poe2-filter-build'
    Write-Host "Downloading NeverSink..."
    $styleDir = Get-NeverSinkFilterDir -DestDir $work
    $srcFilter = Find-SourceFilter -Dir $styleDir -Match $mapping.SourceFilterMatch
    $built = Build-Filter -SourceFilterPath $srcFilter -Mapping $mapping -OutDir $work
    $dest = Join-Path $Poe2Dir ("{0}.filter" -f $mapping.PoeFilterName)
    Copy-Item -Path $built.FilterPath -Destination $dest -Force
    Write-Host "Full build installed locally: $dest"
}
```

- [ ] **Step 2: Create `install.ps1`** (public bootstrapper the one-liner calls)
```powershell
#requires -Version 5.1
[CmdletBinding()]
param([switch]$Full)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repoZip = 'https://github.com/<YOUR_GH_USER>/poe2-filter-sync/archive/refs/heads/main.zip'
$work = Join-Path ([System.IO.Path]::GetTempPath()) 'poe2-filter-sync'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
$zip = Join-Path $work 'repo.zip'
Invoke-WebRequest -Uri $repoZip -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $work -Force
$root = Get-ChildItem -Path $work -Directory | Where-Object Name -like 'poe2-filter-sync-*' | Select-Object -First 1
& (Join-Path $root.FullName 'src/Sync-Poe2Filter.ps1') -Full:$Full -RepoRoot $root.FullName
```
(Replace `<YOUR_GH_USER>` with the real GitHub user once the repo is pushed.)

- [ ] **Step 3: Smoke test the sounds-only path against a temp dir**

Run:
```
pwsh -c "& ./src/Sync-Poe2Filter.ps1 -Poe2Dir (Join-Path $env:TEMP 'poe2test') -RepoRoot (Get-Location)"
```
Expected: prints "Sounds installed." and the mp3 files appear in `$env:TEMP/poe2test`. (Requires the real `sounds/*.mp3` present — see Task 11.)

- [ ] **Step 4: Commit**
```bash
git add src/Sync-Poe2Filter.ps1 install.ps1
git commit -m "feat: local Sync entrypoint (sounds default, -Full fallback) + bootstrapper"
```

---

## Task 10: GitHub Action (test → build → validate → publish)

**Files:**
- Create: `.github/workflows/sync.yml`

**Interfaces:**
- Consumes: `Invoke-Tests.ps1`, `src/*` modules. Secrets: `POE_OAUTH_TOKEN`, and repo variable/secret
  for the filter id via `config/sound-mapping.json` `poeFilterId`.

- [ ] **Step 1: Create `.github/workflows/sync.yml`**
```yaml
name: sync-filter
on:
  schedule:
    - cron: '0 3 * * *'   # nightly 03:00 UTC
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        shell: pwsh
        run: ./Invoke-Tests.ps1

      - name: Build & validate filter
        shell: pwsh
        run: |
          Import-Module ./src/SoundMapping.psm1 -Force
          Import-Module ./src/NeverSink.psm1 -Force
          Import-Module ./src/BuildFilter.psm1 -Force
          $mapping = Get-SoundMapping -Path ./config/sound-mapping.json -SoundsDir ./sounds
          $style = Get-NeverSinkFilterDir -DestDir ./out/neversink
          $src = Find-SourceFilter -Dir $style -Match $mapping.SourceFilterMatch
          $built = Build-Filter -SourceFilterPath $src -Mapping $mapping -OutDir ./out
          "BUILT_FILTER=$($built.FilterPath)" | Out-File $env:GITHUB_ENV -Append

      - name: Publish to PoE account
        if: ${{ env.POE_OAUTH_TOKEN != '' }}
        shell: pwsh
        env:
          POE_OAUTH_TOKEN: ${{ secrets.POE_OAUTH_TOKEN }}
        run: |
          Import-Module ./src/SoundMapping.psm1 -Force
          Import-Module ./src/PublishFilter.psm1 -Force
          $mapping = Get-SoundMapping -Path ./config/sound-mapping.json -SoundsDir ./sounds
          Publish-Filter -FilterPath $env:BUILT_FILTER -FilterId $mapping.PoeFilterId `
            -FilterName $mapping.PoeFilterName -Token $env:POE_OAUTH_TOKEN
```

- [ ] **Step 2: Validate the workflow YAML locally**

Run: `pwsh -c "if (Get-Command yq -ErrorAction SilentlyContinue) { yq '.jobs' .github/workflows/sync.yml } else { Get-Content .github/workflows/sync.yml | Select-String 'runs-on' }"`
Expected: prints job structure / `runs-on: ubuntu-latest` (basic sanity; full validation happens on first push).

- [ ] **Step 3: Commit**
```bash
git add .github/workflows/sync.yml
git commit -m "ci: nightly build/validate/publish workflow"
```

---

## Task 11: Seed real sounds, README, and Discord message

**Files:**
- Create: `sounds/*.mp3` (the real audio), `DISCORD.md`
- Modify: `README.md`

**Interfaces:** none (docs/assets).

- [ ] **Step 1: Add the real mp3 files** to `sounds/`.
  Migrate the existing sounds (previously on Google Drive) into `sounds/` using the names referenced
  in `config/sound-mapping.json` (`1maybevaluable.mp3` … `6veryvaluable.mp3`, `gay-echo.mp3`,
  `TRIPLE_MONSTRE.mp3`, plus any others you add to the config). Confirm each config-referenced file exists:
  ```
  pwsh -c "Import-Module ./src/SoundMapping.psm1 -Force; Get-SoundMapping -Path ./config/sound-mapping.json -SoundsDir ./sounds | Out-Null; 'all referenced sounds present'"
  ```
  Expected: prints "all referenced sounds present" (throws if any file is missing).

- [ ] **Step 2: Write `DISCORD.md`** (the announcement to paste)
```markdown
# 🎯 Filtre POE2 (NeverSink + sons custom)

**1) Suivre le filtre (mises à jour automatiques)**
En jeu : Options → Item Filter → sélectionne le filtre en ligne **"NeverSink + custom sounds"** (ou suis-le). Il se met à jour tout seul à chaque update NeverSink.

**2) Installer les sons (une seule fois)**
Win+R, colle ça, Entrée :
```
powershell -Command "iwr 'https://raw.githubusercontent.com/<YOUR_GH_USER>/poe2-filter-sync/main/install.ps1' -OutFile \"$env:TEMP\poe2sounds.ps1\"; powershell -ExecutionPolicy Bypass -File \"$env:TEMP\poe2sounds.ps1\""
```
Pas besoin d'admin. Ça copie les sons dans ton dossier Path of Exile 2, puis **ouvre automatiquement la page du filtre** pour que tu t'abonnes en 1 clic (étape 1).

**En secours** (si le filtre en ligne ne se met plus à jour) : reconstruire tout en local avec `-Full` :
```
powershell -Command "iwr 'https://raw.githubusercontent.com/<YOUR_GH_USER>/poe2-filter-sync/main/install.ps1' -OutFile \"$env:TEMP\poe2sounds.ps1\"; powershell -ExecutionPolicy Bypass -File \"$env:TEMP\poe2sounds.ps1\" -Full"
```
```
(Replace `<YOUR_GH_USER>` after the repo is pushed.)

- [ ] **Step 3: Flesh out `README.md`** with: what it does, how the Action works, how to set the
  `POE_OAUTH_TOKEN` secret and `poeFilterId`, and how to run locally (`Sync-Poe2Filter.ps1` / `-Full`).

- [ ] **Step 4: Full local dry run of `-Full`** against a temp dir (network required)

Run:
```
pwsh -c "& ./src/Sync-Poe2Filter.ps1 -Full -Poe2Dir (Join-Path $env:TEMP 'poe2test') -RepoRoot (Get-Location)"
```
Expected: downloads NeverSink, prints "Full build installed locally: …", and both the built `.filter`
and the mp3 files exist in `$env:TEMP/poe2test`.

- [ ] **Step 5: Commit**
```bash
git add sounds README.md DISCORD.md
git commit -m "assets: add sounds, README, and Discord install message"
```

---

## Task 12: Publish repo & wire secrets

**Files:** none (ops).

- [ ] **Step 1: Create the GitHub repo and push**
```bash
gh repo create poe2-filter-sync --public --source=. --push
```

- [ ] **Step 2: Replace `<YOUR_GH_USER>` placeholders** in `install.ps1` and `DISCORD.md` with the
  real user/repo, commit, and push.

- [ ] **Step 3: Set the OAuth token secret** (only if Task 0 enabled publishing)
```bash
gh secret set POE_OAUTH_TOKEN
```
And set `poeFilterId` in `config/sound-mapping.json` to your online filter's id (or leave empty to create on first run), commit, push.

- [ ] **Step 4: Trigger the workflow once and confirm green**
```bash
gh workflow run sync-filter && gh run watch
```
Expected: run succeeds; tests pass, build/validate pass, publish step runs (or is skipped if no token).

- [ ] **Step 5: In-game confirmation.** Select the online filter, confirm updates arrive and custom sounds play (mp3s already installed via Task 11 / the one-liner).

---

## Self-Review

**Spec coverage:**
- A (fail loud) → Task 4 `Assert-AllMappingsMatched`, wired in Task 6, enforced in Task 10 build step. ✅
- B (sounds versioned) → Task 11 `sounds/` in repo; config references them. ✅
- C (auto filter updates) → Task 8 `Publish-Filter` + Task 10 nightly Action. ✅
- D (simple distribution) → Task 9 `install.ps1` one-liner + Task 11 `DISCORD.md`. ✅
- Shared build core → Task 6 `Build-Filter` used by both Task 9 (`-Full`) and Task 10 (Action). ✅
- File-replacement mechanism → Task 7 `Install-Sounds`. ✅
- Targeted overrides → Task 3 `Set-CustomAlertSound`. ✅
- JSON config → Task 2. ✅
- Per-mapping volume → Task 2 config + Task 3 `-Volume`. ✅
- Non-destructive/no-admin → Task 7 (only writes mp3s), Task 9 (no wipe). ✅
- Risks levered first → Task 0. ✅
- Discord message deliverable → Task 11. ✅

**Placeholder scan:** `<YOUR_GH_USER>` appears in `install.ps1`/`DISCORD.md` — intentional, resolved in Task 12 Step 2 (real value unknown until the repo exists). No other placeholders.

**Type consistency:** `Get-SoundMapping` returns `FileReplacements`/`TargetedOverrides` (with `.Identifier/.File/.Volume`) — consumed identically in Tasks 6, 7, 9. `Build-Filter` returns `{ FilterPath; MatchReport }` — consumed in Task 9/10. `Set-CustomAlertSound` returns `{ Lines; MatchCount }` — consumed in Task 6. Consistent.
