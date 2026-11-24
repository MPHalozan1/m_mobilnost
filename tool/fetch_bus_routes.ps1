# Routes every line direction as ONE bus trip through all its stops (Valhalla,
# costing=bus), then writes one OSRM-shaped file per stop pair so the existing
# generator (tool/build_road_geometry_test.dart) can consume it via OSRM_DIR.
param(
  [string]$Pairs = "$PSScriptRoot\..\build\stop_pairs.json",
  [string]$Raw = "$PSScriptRoot\..\build\route_raw",
  [string]$Out = "$PSScriptRoot\..\build\route_responses"
)
$ProgressPreference = 'SilentlyContinue'
$inv = [Globalization.CultureInfo]::InvariantCulture
New-Item -ItemType Directory -Force $Raw, $Out | Out-Null
$j = Get-Content $Pairs -Raw -Encoding UTF8 | ConvertFrom-Json
$stops = @{}; foreach ($s in $j.stops) { $stops[$s.id] = $s }

# Routing-only location overrides for stops whose map coordinate sits away from
# the road (e.g. inside a building). They only steer where the router meets the
# road; the stop marker in the app keeps its own coordinate.
$routingOverrides = @{
  'europark' = @{ lat = 46.55451; lng = 15.65147 }  # OSM "Europark" bus stop
}
foreach ($id in @($routingOverrides.Keys)) {
  if ($stops.ContainsKey($id)) {
    $stops[$id] = [pscustomobject]@{ id = $id; lat = $routingOverrides[$id].lat; lng = $routingOverrides[$id].lng }
  }
}

function Decode6([string]$enc) {
  $pts = New-Object System.Collections.Generic.List[double[]]
  $i = 0; $lat = 0; $lng = 0
  while ($i -lt $enc.Length) {
    foreach ($axis in 0, 1) {
      $shift = 0; $result = 0
      do { $b = [int][char]$enc[$i] - 63; $i++; $result = $result -bor (($b -band 0x1f) -shl $shift); $shift += 5 } while ($b -ge 0x20)
      $d = if ($result -band 1) { -bnot ($result -shr 1) } else { $result -shr 1 }
      if ($axis -eq 0) { $lat += $d } else { $lng += $d }
    }
    $pts.Add(@(($lng / 1e6), ($lat / 1e6)))
  }
  return ,$pts
}
function Dist($lat1,$lon1,$lat2,$lon2) {
  $r = 6371000; $p = [Math]::PI/180
  $a = [Math]::Pow([Math]::Sin(($lat2-$lat1)*$p/2),2) + [Math]::Cos($lat1*$p)*[Math]::Cos($lat2*$p)*[Math]::Pow([Math]::Sin(($lon2-$lon1)*$p/2),2)
  return 2*$r*[Math]::Asin([Math]::Sqrt($a))
}

# Rebuild ordered stop sequences per direction from the pairs.
$dirPairs = @{}
foreach ($p in $j.pairs) { foreach ($d in $p.lines) { if (-not $dirPairs[$d]) { $dirPairs[$d] = @() }; $dirPairs[$d] += $p } }
$written = 0
foreach ($dir in ($dirPairs.Keys | Sort-Object)) {
  $ps = $dirPairs[$dir]
  $tos = $ps | ForEach-Object { $_.to }
  $start = ($ps | Where-Object { $tos -notcontains $_.from } | Select-Object -First 1).from
  if (-not $start) { $start = $ps[0].from }  # circular line
  $seq = @($start); $guard = 0; $used = @{}
  while ($guard -lt 100) {
    $guard++
    $nx = $ps | Where-Object { $_.from -eq $seq[-1] -and -not $used["$($_.from)>$($_.to)"] } | Select-Object -First 1
    if (-not $nx) { break }
    $used["$($nx.from)>$($nx.to)"] = $true
    $seq += $nx.to
  }

  $rawFile = Join-Path $Raw "$dir.json"
  if (-not (Test-Path $rawFile)) {
    $locs = ($seq | ForEach-Object { [string]::Format($inv, '{{"lat":{0},"lon":{1},"type":"break","radius":35}}', [double]$stops[$_].lat, [double]$stops[$_].lng) }) -join ','
    $body = '{"locations":[' + $locs + '],"costing":"bus","units":"kilometers"}'
    for ($t = 0; $t -lt 3; $t++) {
      # Last attempt: drop the snap radius (stops in pedestrian zones have no
      # bus road within 35 m).
      if ($t -eq 2) { $body = $body.Replace(',"radius":35', '') }
      try {
        $r = Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'https://valhalla1.openstreetmap.de/route' -Body $body -ContentType 'application/json' -TimeoutSec 60 -Headers @{ 'User-Agent' = 'm-mobilnost-geometry-builder/1.0' }
        [IO.File]::WriteAllText($rawFile, $r.Content); break
      } catch { Start-Sleep -Seconds (3 + 3 * $t) }
    }
    Start-Sleep -Milliseconds 1500
  }
  if (-not (Test-Path $rawFile)) {
    # Whole-line request rejected: route pair by pair and stitch the legs.
    Write-Output "whole-line failed for $dir, routing pairwise"
    $legs = @()
    for ($i = 0; $i -lt $seq.Count - 1; $i++) {
      $a = $stops[$seq[$i]]; $b = $stops[$seq[$i + 1]]
      $pb = [string]::Format($inv, '{{"locations":[{{"lat":{0},"lon":{1},"type":"break"}},{{"lat":{2},"lon":{3},"type":"break"}}],"costing":"bus","units":"kilometers"}}', [double]$a.lat, [double]$a.lng, [double]$b.lat, [double]$b.lng)
      try {
        $pr = Invoke-RestMethod -Method Post -Uri 'https://valhalla1.openstreetmap.de/route' -Body $pb -ContentType 'application/json' -TimeoutSec 60 -Headers @{ 'User-Agent' = 'm-mobilnost-geometry-builder/1.0' }
        $legs += $pr.trip.legs[0]
      } catch { $legs += $null }
      Start-Sleep -Milliseconds 1200
    }
    if ($legs -contains $null) { Write-Output "FAILED $dir"; continue }
    [IO.File]::WriteAllText($rawFile, (@{ trip = @{ legs = $legs } } | ConvertTo-Json -Depth 10 -Compress))
  }
  $trip = (Get-Content $rawFile -Raw | ConvertFrom-Json).trip
  if ($trip.legs.Count -ne ($seq.Count - 1)) { Write-Output "LEG MISMATCH $dir legs=$($trip.legs.Count) stops=$($seq.Count)"; continue }
  for ($i = 0; $i -lt $trip.legs.Count; $i++) {
    $from = $seq[$i]; $to = $seq[$i + 1]
    $file = Join-Path $Out "${from}__${to}.json"
    $coords = Decode6 $trip.legs[$i].shape
    $len = [double]$trip.legs[$i].summary.length * 1000
    if (Test-Path $file) {
      # Same pair on several lines: keep the shorter, more direct variant.
      $old = Get-Content $file -Raw | ConvertFrom-Json
      if ($old.routes[0].distance -le $len) { continue }
    }
    $snapA = Dist $stops[$from].lat $stops[$from].lng $coords[0][1] $coords[0][0]
    $snapB = Dist $stops[$to].lat $stops[$to].lng $coords[$coords.Count-1][1] $coords[$coords.Count-1][0]
    $obj = [ordered]@{
      code = 'Ok'
      routes = @(@{ distance = $len; geometry = @{ type = 'LineString'; coordinates = $coords } })
      waypoints = @(@{ distance = $snapA }, @{ distance = $snapB })
      source = "valhalla bus, $dir"
    }
    [IO.File]::WriteAllText($file, ($obj | ConvertTo-Json -Depth 8 -Compress))
    $written++
  }
}
Write-Output "DONE pairs written: $written, files: $((Get-ChildItem $Out).Count)"
