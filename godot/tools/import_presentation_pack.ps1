param(
    [Parameter(Mandatory = $true)]
    [string]$PackPath,
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

function Get-OptionalValue($Object, [string]$Name, $DefaultValue) {
    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

$pack = (Resolve-Path -LiteralPath $PackPath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifestPath = Join-Path $project "data\presentation_manifest.json"
if (-not (Test-Path -LiteralPath (Join-Path $project "project.godot"))) {
    throw "ProjectPath is not a Godot project: $project"
}
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing presentation manifest: $manifestPath"
}

$packInfoPath = Join-Path $pack "pack.json"
$packInfo = $null
if (Test-Path -LiteralPath $packInfoPath) {
    $packInfo = Get-Content -Raw -LiteralPath $packInfoPath | ConvertFrom-Json
}
$packName = [string](Get-OptionalValue $packInfo "id" (Split-Path -Leaf $pack))
if ($packName -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Pack id must use only letters, digits, underscore or dash. Add a valid id to pack.json."
}

$targetRelative = "assets/presentation_imported/$packName"
$target = Join-Path $project ($targetRelative -replace '/', '\')
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $pack "*") -Destination $target -Recurse -Force

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($requiredSection in @("actors", "items", "decor")) {
    if ($null -eq (Get-OptionalValue $manifest $requiredSection $null)) {
        Add-Member -InputObject $manifest -MemberType NoteProperty -Name $requiredSection -Value ([pscustomobject]@{})
    }
}

$actorsRoot = Join-Path $target "actors"
if (Test-Path -LiteralPath $actorsRoot) {
    foreach ($actorDir in Get-ChildItem -LiteralPath $actorsRoot -Directory) {
        $actorInfo = $null
        $actorInfoPath = Join-Path $actorDir.FullName "actor.json"
        if (Test-Path -LiteralPath $actorInfoPath) {
            $actorInfo = Get-Content -Raw -LiteralPath $actorInfoPath | ConvertFrom-Json
        }
        $actor = @{
            pixel_size = [double](Get-OptionalValue $actorInfo "pixel_size" 0.002)
            visual_y = [double](Get-OptionalValue $actorInfo "visual_y" 0.85)
            animations = @{}
        }
        foreach ($stateDir in Get-ChildItem -LiteralPath $actorDir.FullName -Directory) {
            $files = @(Get-ChildItem -LiteralPath $stateDir.FullName -File -Filter "*.png" | Sort-Object Name)
            if ($files.Count -eq 0) { continue }
            $animationSettings = Get-OptionalValue $actorInfo "animations" $null
            $stateSettings = Get-OptionalValue $animationSettings $stateDir.Name $null
            $fps = [double](Get-OptionalValue $stateSettings "fps" 8.0)
            $loop = [bool](Get-OptionalValue $stateSettings "loop" ($stateDir.Name -in @("idle", "move")))
            $actor.animations[$stateDir.Name] = @{
                frames = @($files | ForEach-Object { "res://$targetRelative/actors/$($actorDir.Name)/$($stateDir.Name)/$($_.Name)" })
                fps = $fps
                loop = $loop
            }
        }
        if (-not $actor.animations.ContainsKey("idle")) {
            throw "Actor '$($actorDir.Name)' has no actors/$($actorDir.Name)/idle/*.png frames."
        }
        Add-Member -InputObject $manifest.actors -MemberType NoteProperty -Name $actorDir.Name -Value ([pscustomobject]$actor) -Force
    }
}

foreach ($category in @("items", "decor")) {
    $categoryRoot = Join-Path $target $category
    if (-not (Test-Path -LiteralPath $categoryRoot)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $categoryRoot -File -Filter "*.png") {
        $key = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        Add-Member -InputObject $manifest.$category -MemberType NoteProperty -Name $key -Value "res://$targetRelative/$category/$($file.Name)" -Force
    }
}

Copy-Item -LiteralPath $manifestPath -Destination "$manifestPath.bak" -Force
$json = $manifest | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($manifestPath, $json, [Text.UTF8Encoding]::new($false))
Write-Host "Imported presentation pack '$packName'."
Write-Host "Manifest updated: $manifestPath"
Write-Host "Previous manifest: $manifestPath.bak"
Write-Host "Return to Godot and wait for the asset import to finish."
