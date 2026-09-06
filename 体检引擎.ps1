$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$outDir = if($PSScriptRoot){ $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$reportPath = Join-Path $outDir '电脑体检报告.html'
$reportTime = Get-Date

Write-Host '[1/5] 采集磁盘空间与垃圾文件...' -ForegroundColor Cyan
# ---------- 工具函数 ----------
function Get-DirSizeMB([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    try {
        $bytes = (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
        return [math]::Round(($bytes / 1MB), 1)
    } catch { return 0 }
}
function Fmt-Size([double]$mb) {
    if ($mb -ge 1024) { return ('{0:N1} GB' -f ($mb/1024)) }
    return ('{0:N1} MB' -f $mb)
}
function Pct-Class([double]$pct) {
    if ($pct -ge 90) { return 'bad' }
    if ($pct -ge 70) { return 'warn' }
    return 'ok'
}
# ---------- 1. 磁盘 ----------
$diskRows = ''
$diskTotalFree = 0.0; $diskMaxPct = 0.0
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $tot = [math]::Round($_.Size/1GB,1); $free = [math]::Round($_.FreeSpace/1GB,1)
    $used = [math]::Round($tot-$free,1); $pct = if($tot -gt 0){[math]::Round($used/$tot*100,1)}else{0}
    $cls = Pct-Class $pct
    $diskTotalFree += $_.FreeSpace/1GB; if($pct -gt $diskMaxPct){ $diskMaxPct = $pct }
    $diskRows += "<tr><td>$($_.DeviceID)</td><td>$tot GB</td><td>$used GB</td><td>$free GB</td><td>$pct%<div class=`"progress`"><div style=`"width:$pct%;background:var(--$cls)`"></div></div></td></tr>"
}
$diskNote = if($diskMaxPct -gt 85){"部分分区空间较紧张，建议及时清理。"}else{"所有分区使用率均低于 85%，磁盘空间充裕。"}
# ---------- 2. 垃圾文件 ----------
$user = $env:USERPROFILE
$tmpSys = Get-DirSizeMB 'C:\Windows\Temp'
$tmpUser = Get-DirSizeMB $env:TEMP
$cacheChrome = Get-DirSizeMB "$user\AppData\Local\Google\Chrome\User Data\Default\Cache"
$cacheChrome2 = Get-DirSizeMB "$user\AppData\Local\Google\Chrome\User Data\Default\Code Cache"
$cacheEdge = Get-DirSizeMB "$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
$cacheEdge2 = Get-DirSizeMB "$user\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"
$cacheAll = [math]::Round($cacheChrome+$cacheChrome2+$cacheEdge+$cacheEdge2,1)
$recycle = Get-DirSizeMB 'C:\$Recycle.Bin'
$winsxsDL = Get-DirSizeMB 'C:\Windows\SoftwareDistribution\Download'
$wer = Get-DirSizeMB 'C:\ProgramData\Microsoft\Windows\WER'
$crash = Get-DirSizeMB "$user\AppData\Local\CrashDumps"
$logAll = [math]::Round($wer+$crash,1)
$mini = Get-DirSizeMB 'C:\Windows\Minidump'
$lkr = Get-DirSizeMB 'C:\Windows\LiveKernelReports'
$dmpAll = [math]::Round($mini+$lkr,1)
$winOld = Get-DirSizeMB 'C:\Windows.old'
$hiber = 0; if(Test-Path 'C:\hiberfil.sys'){ try{$hiber=[math]::Round((Get-Item 'C:\hiberfil.sys' -Force).Length/1MB,1)}catch{$hiber=-1} }
$pagef = 0; if(Test-Path 'C:\pagefile.sys'){ try{$pagef=[math]::Round((Get-Item 'C:\pagefile.sys' -Force).Length/1MB,1)}catch{$pagef=-1} }
$clearable = [math]::Round($tmpSys+$tmpUser+$cacheAll+$recycle+$winsxsDL+$logAll+$dmpAll,1)
function Junk-Row($name,$sizeMB,$tip,$cls){
  if($sizeMB -lt 0){ return "<tr><td>$name</td><td>受限未读取</td><td class=`"ok`">系统保护，不推荐处理</td></tr>" }
  if($sizeMB -eq 0){ return "<tr><td>$name</td><td>0 MB</td><td class=`"ok`">$tip</td></tr>" }
  return "<tr><td>$name</td><td>$(Fmt-Size $sizeMB)</td><td class=`"$cls`">可清理</td></tr>"
}
$junkRows = ""
$junkRows += Junk-Row '系统临时文件（C:\Windows\Temp）' $tmpSys '无需处理' 'warn'
$junkRows += Junk-Row '用户临时文件（%TEMP%）' $tmpUser '无需处理' 'warn'
$junkRows += Junk-Row '浏览器缓存（Chrome/Edge）' $cacheAll '无需处理' 'warn'
$junkRows += Junk-Row '回收站' $recycle '可清理（清空前请确认）' 'warn'
$junkRows += Junk-Row 'Windows 更新备份（SoftwareDistribution\Download）' $winsxsDL '无需处理' 'warn'
$junkRows += Junk-Row '应用日志 / 崩溃转储（WER + CrashDumps）' $logAll '无需处理' 'warn'
$junkRows += Junk-Row '系统崩溃转储（Minidump / LiveKernelReports）' $dmpAll '无需处理' 'ok'
$junkRows += Junk-Row 'Windows.old 旧系统备份' $winOld '不存在' 'ok'
$junkRows += Junk-Row '休眠文件（hiberfil.sys）' $hiber '系统保护，不推荐处理' 'ok'
$junkRows += Junk-Row '页面文件（pagefile.sys）' $pagef '系统保护，不推荐处理' 'ok'
$junkTip = "预计可释放空间：约 $(Fmt-Size $clearable)（临时文件 + 浏览器缓存 + 回收站 + 更新备份 + 崩溃转储）。"
# ---------- 3. 大文件扫描（>500MB 且超60天未修改，前10）----------
Write-Host '[2/5] 扫描大文件（>500MB 且 60 天未修改，可能需要几分钟）...' -ForegroundColor Cyan
$cutoff = (Get-Date).AddDays(-60)
$bigList = New-Object System.Collections.Generic.List[object]
$roots = @()
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { $roots += $_.DeviceID + '\' }
# 剔除 C:\ProgramData 避免事务异常；C 盘仅扫 C:\Users 与根级
$scanRoots = @("C:\Users", "C:\")
foreach($r in $scanRoots){ if(Test-Path -LiteralPath $r){ $roots += $r } }
$rootSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach($r in $roots){ [void]$rootSet.Add($r) }
$processed = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach($root in $rootSet){
  if($processed.Contains($root)){ continue }
  [void]$processed.Add($root)
  if($root -like 'C:\*' -and $root -notlike 'C:\Users*' -and $root -ne 'C:\'){ continue } # 仅 C:\ 根级文件
  try {
    Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Length -gt 500MB -and $_.LastWriteTime -lt $cutoff } |
      ForEach-Object { $item = [pscustomobject]@{FullName=$_.FullName;SizeMB=[math]::Round($_.Length/1MB,1);LastWriteTime=$_.LastWriteTime;LastAccessTime=$_.LastAccessTime}; $bigList.Add($item) }
  } catch { }
}
$big = $bigList | Sort-Object SizeMB -Descending | Select-Object -First 10
$bigRows = ''; $bigIdx = 0
foreach($f in $big){
  $bigIdx++
  $szCls = if($f.SizeMB -ge 10000){'bad'}elseif($f.SizeMB -ge 2000){'warn'}else{'ok'}
  $b = if($f.SizeMB -ge 10000){'<b>'}else{''}; $be = if($f.SizeMB -ge 10000){'</b>'}else{''}
  $bigRows += "<tr><td>$bigIdx</td><td><code>$($f.FullName)</code></td><td class=`"$szCls`">$b$(Fmt-Size $f.SizeMB)$be</td><td>$($f.LastWriteTime.ToString('yyyy-MM-dd'))</td><td>$($f.LastAccessTime.ToString('yyyy-MM-dd'))</td></tr>"
}
$bigWarn = if($big.Count -eq 0){'<div class="ok">近 60 天内未发现超过 500MB 且长期未修改的大文件。</div>'}else{"<div class=`"warn-box`"><b>重点关注：</b>以上为超大且长期未修改文件。删除 / 归档前请务必确认文件内容，避免误删重要数据。</div>"}
# ---------- 4. 性能 ----------
Write-Host '[3/5] 采集系统性能与自启动项...' -ForegroundColor Cyan
$cpuTxt = 'N/A'
try {
  $c1 = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2).CounterSamples.CookedValue | Measure-Object -Average
  $cpuTxt = ('{0:N0}%' -f $c1.Average)
} catch { $cpuTxt = (Get-CimInstance Win32_Processor).LoadPercentage.ToString() + '%' }
$os = Get-CimInstance Win32_OperatingSystem
$memTotal = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
$memFree = [math]::Round($os.FreePhysicalMemory/1MB,1)
$memUsed = [math]::Round($memTotal-$memFree,1)
$memPct = if($memTotal -gt 0){[math]::Round($memUsed/$memTotal*100,1)}else{0}
$procCount = (Get-Process).Count
$cpuName = (Get-CimInstance Win32_Processor).Name
$cpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$startups = Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location
$safeStart = @('SecurityHealth','Windows Defender','Marvis','OneDrive','Microsoft','Windows','explorer')
$startupRows = ''; $disableCnt = 0
foreach($s in $startups){
  $rec = 'ok'; $recTxt = '建议保留'
  $hit = $false
  foreach($k in @('Edge','IDMan','Download','WeChat','QQ','Wukong','Xunlei','BaiduNet','WPS','Bilibili','Discord','Steam','NVIDIA')){ if($s.Name -match $k){$hit=$true;break} }
  $sys = $false; foreach($k in $safeStart){ if($s.Name -match $k){$sys=$true;break} }
  if($hit -and -not $sys){ $rec='warn'; $recTxt='建议禁用（开机自启非必需）'; $disableCnt++ }
  $startupRows += "<tr><td>$($s.Name)</td><td>已开启</td><td class=`"$rec`">$recTxt</td></tr>"
}
$startupNote = "自启动项共 $($startups.Count) 项" + $(if($disableCnt -gt 0){"，建议禁用 $disableCnt 项以加快开机速度。"}else{"，均为系统必需，无需调整。"})
# ---------- 5. 电池健康 ----------
Write-Host '[4/5] 采集电池健康与使用习惯...' -ForegroundColor Cyan
$hasBattery = $true
$bss = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
$bcc = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
$batStatus = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not $bss -and -not $batStatus){ $hasBattery = $false }
$design = $full = $healthPct = $cycle = $plug = $bright = $powerPlan = $battSaver = ''
if($hasBattery){
  if($bss){ $design = [math]::Round([double]$bss.DesignedCapacity/1000,0) }
  if($bcc){ $full = [math]::Round([double]$bcc.FullChargedCapacity/1000,0) }
  if($design -le 0 -or $full -le 0){
    try {
      $brFile = Join-Path $env:TEMP ("br-{0}.html" -f ([guid]::NewGuid().ToString("N")))
      powercfg /batteryreport /output $brFile | Out-Null
      if(Test-Path $brFile){
        $brHtml = Get-Content -LiteralPath $brFile -Raw -Encoding Unicode
        if($design -le 0 -and $brHtml -match 'Design Capacity</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $design = [math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($design -le 0 -and $brHtml -match '设计容量</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $design = [math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($full -le 0 -and $brHtml -match 'Full Charge Capacity</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $full = [math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($full -le 0 -and $brHtml -match '满充电容量</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $full = [math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
      }
    } catch { }
  }
  if($design -gt 0 -and $full -gt 0){ $healthPct = [math]::Round($full/$design*100,1) }
  # 循环次数：解析 powercfg /batteryreport
  try {
    if(-not $brFile -or -not (Test-Path $brFile)){ $brFile = Join-Path $env:TEMP ("br-{0}.html" -f ([guid]::NewGuid().ToString("N"))); powercfg /batteryreport /output $brFile | Out-Null }
    if(Test-Path $brFile){ $brHtml = Get-Content -LiteralPath $brFile -Raw -Encoding Unicode; if($brHtml -match 'Cycle Count</td>\s*<td>([0-9]+)' -or $brHtml -match '循环次数</td>\s*<td>([0-9]+)'){ $cycle = $Matches[1] } }
  } catch { }
  if(Test-Path $brFile){ Remove-Item -LiteralPath $brFile -Force -ErrorAction SilentlyContinue }
  # 插电状态
  if($batStatus){ $bs = $batStatus.BatteryStatus; $plug = if($bs -eq 2){'长期插电使用'}else{'当前使用电池'} }
  # 亮度
  $bri = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue | Select-Object -First 1
  if($bri){ $bright = $bri.CurrentBrightness.ToString() + '%' }
  # 电源计划
  try { $aps = powercfg /getactivescheme; $powerPlan = ($aps -split '\(')[1].TrimEnd(')') } catch { }
  # 节电模式：插电时一般未单独启用
  $battSaver = if($plug -like '*插电*'){'未单独启用（当前插电）'}else{'跟随电源计划自动'}

  # 电池 SVG 环形进度
  $bp = if($healthPct -gt 0){$healthPct}else{0}
  $bCirc = "<svg width=`"120`" height=`"120`" viewBox=`"0 0 120 120`"><circle cx=`"60`" cy=`"60`" r=`"52`" fill=`"none`" stroke=`"#e8eaed`" stroke-width=`"12`"/><circle cx=`"60`" cy=`"60`" r=`"52`" fill=`"none`" stroke=`"var(--ok)`" stroke-width=`"12`" stroke-linecap=`"round`" stroke-dasharray=`"$([math]::Round(2*3.14159*52*$bp/100,1)) 327`" transform=`"rotate(-90 60 60)`"/><text x=`"60`" y=`"66`" text-anchor=`"middle`" font-size=`"20`" font-weight=`"700`" fill=`"#202124`">$bp%</text></svg>"
}
$bootCount = 0; $totalMin = 0
try {
  $ev = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-General'; Id=12,13} -MaxEvents 400 -ErrorAction Stop
  $boot = @{}; $sorted = $ev | Sort-Object TimeCreated
  foreach($e in $sorted){ if($e.Id -eq 12){ $boot[$e.TimeCreated]='up' } elseif($e.Id -eq 13){ $boot[$e.TimeCreated]='down' } }
  $cut7 = (Get-Date).AddDays(-7)
  $lastUp = $null
  foreach($t in ($boot.Keys | Sort-Object)){ if($t -ge $cut7){ if($boot[$t] -eq 'up' -and -not $lastUp){ $lastUp=$t } } }
  # 配对 ups/downs
  $ups = ($boot.GetEnumerator() | Where-Object {$_.Value -eq 'up' -and $_.Key -ge $cut7} | Sort-Object Key)
  $downs = ($boot.GetEnumerator() | Where-Object {$_.Value -eq 'down' -and $_.Key -ge $cut7} | Sort-Object Key)
  $bootCount = $ups.Count
  foreach($u in $ups){ $d = $downs | Where-Object {$_.Key -gt $u.Key} | Select-Object -First 1; if($d){ $totalMin += [math]::Round((($d.Key)-($u.Key)).TotalMinutes,0) } else { $totalMin += [math]::Round(((Get-Date)-($u.Key)).TotalMinutes,0) } }
} catch { }
$lastBoot = $os.LastBootUpTime
$upH = [math]::Round(((Get-Date) - $lastBoot).TotalHours,1)
$upDays = [math]::Round($upH/24,1)
$avgH = if($bootCount -gt 0){[math]::Round($totalMin/60/$bootCount,1)}else{0}
$totalH = [math]::Round($totalMin/60,1)
# ---------- 综合评分 ----------
$diskScore = 0
try {
  $cDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
  $cPct = [math]::Round(($cDisk.Size-$cDisk.FreeSpace)/$cDisk.Size*100,1)
  if($cPct -le 50){$diskScore=25}elseif($cPct -le 70){$diskScore=20}elseif($cPct -le 85){$diskScore=12}else{$diskScore=5}
} catch { $diskScore = 20 }
$cpuNum = 0.0; if($cpuTxt -match '([0-9.]+)'){ $cpuNum=[double]$Matches[1] }
$perfScore = 0
if($cpuNum -lt 50 -and $memPct -lt 70){$perfScore=25}elseif($cpuNum -lt 80 -and $memPct -lt 85){$perfScore=18}else{$perfScore=10}
$batScore = 20; if($hasBattery){ if($healthPct -ge 90){$batScore=25}elseif($healthPct -ge 80){$batScore=20}elseif($healthPct -ge 70){$batScore=14}else{$batScore=8} }
$cleanScore = 25; if($clearable -ge 10240){$cleanScore=10}elseif($clearable -ge 3072){$cleanScore=16}elseif($clearable -ge 512){$cleanScore=21}
$score = [math]::Min(100,[math]::Round($diskScore+$perfScore+$batScore+$cleanScore))
$scoreCls = if($score -ge 90){'ok'}elseif($score -ge 75){'var(--primary)'}elseif($score -ge 60){'var(--warn)'}else{'var(--bad)'}
$scoreTxt = if($score -ge 90){'电脑整体状态优秀'}elseif($score -ge 75){'电脑整体状态良好'}elseif($score -ge 60){'电脑状态一般，建议按建议优化'}else{'电脑状态较差，请优先处理高优建议'}
$verdict = if($score -ge 75){"磁盘、内存、CPU 资源均处于健康水平。主要优化空间集中在：垃圾文件约 $(Fmt-Size $clearable) 可释放" + $(if($disableCnt -gt 0){", $disableCnt 项自启动项建议禁用"}else{''}) + "。"}else{"系统存在需要关注的问题，请按下方建议优先处理高优项。"}
if($hasBattery){ $verdict += "电池健康度 $healthPct% " + $(if($healthPct -ge 80){'属正常老化范围。'}else{'明显衰减，建议关注养护。'}) }

# ---------- 生成 HTML ----------
$css = @"
:root{--bg:#f0f4f8;--card:#fff;--primary:#1a73e8;--ok:#188038;--warn:#e8710a;--bad:#d93025;--text:#202124;--sub:#5f6368;}
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:"Segoe UI","Microsoft YaHei",sans-serif;background:var(--bg);color:var(--text);line-height:1.6;}
.container{max-width:980px;margin:0 auto;padding:24px 16px 60px;}
header{background:linear-gradient(135deg,#1a73e8,#0d47a1);color:#fff;border-radius:16px;padding:32px 28px;margin-bottom:24px;}
header h1{font-size:26px;margin-bottom:8px;}
header p{opacity:.9;font-size:14px;}
.badge{display:inline-block;background:rgba(255,255,255,.2);border-radius:20px;padding:4px 14px;font-size:13px;margin-top:10px;}
.card{background:var(--card);border-radius:14px;padding:22px 24px;margin-bottom:20px;box-shadow:0 1px 4px rgba(0,0,0,.06);}
.card h2{font-size:19px;margin-bottom:16px;padding-left:12px;border-left:4px solid var(--primary);}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px;}
.metric{background:#f8fafc;border-radius:10px;padding:14px 16px;}
.metric .label{font-size:13px;color:var(--sub);}
.metric .value{font-size:22px;font-weight:600;margin-top:4px;}
table{width:100%;border-collapse:collapse;font-size:14px;}
th,td{text-align:left;padding:9px 12px;border-bottom:1px solid #e8eaed;}
th{background:#f8fafc;font-weight:600;}
.ok{color:var(--ok);}.warn{color:var(--warn);}.bad{color:var(--bad);}
.progress{background:#e8eaed;border-radius:8px;height:12px;overflow:hidden;margin-top:6px;}
.progress>div{height:100%;border-radius:8px;}
.tip{background:#e8f0fe;border-left:4px solid var(--primary);border-radius:8px;padding:12px 16px;margin-top:14px;font-size:14px;}
.warn-box{background:#fef7e0;border-left:4px solid var(--warn);border-radius:8px;padding:12px 16px;margin-top:14px;font-size:14px;}
.score{text-align:center;padding:8px 0;}
.score .num{font-size:48px;font-weight:700;}
footer{text-align:center;color:var(--sub);font-size:12px;margin-top:28px;}
code{background:#f1f3f4;padding:1px 6px;border-radius:4px;font-size:12px;}
.two-col{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
@media(max-width:720px){.two-col{grid-template-columns:1fr;}}
"@
$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Windows 11 电脑体检报告</title>
<style>
$css
</style>
</head>
<body>
<div class="container">
<header>
<h1>Windows 11 电脑体检报告</h1>
<p>设备：$((Get-CimInstance Win32_ComputerSystem).Manufacturer) $((Get-CimInstance Win32_ComputerSystem).Model) · 系统：$($os.Caption)（Build $($os.BuildNumber)）· 体检时间：$($reportTime.ToString('yyyy-MM-dd HH:mm'))</p>
<span class="badge">综合健康评分：$score / 100</span>
</header>
<div class="card">
<h2>综合评估</h2>
<div class="score"><div class="num" style="color:$scoreCls">$score</div><div>$scoreTxt</div></div>
<div class="tip"><b>核心结论：</b>$verdict</div>
</div>
<div class="card">
<h2>一、磁盘空间与垃圾文件</h2>
<table>
<tr><th>分区</th><th>总容量</th><th>已用</th><th>剩余</th><th>使用率</th></tr>
$diskRows
</table>
<p style="margin-top:12px;font-size:14px;color:var(--sub)">$diskNote</p>
<h2 style="margin-top:24px">垃圾文件统计与预计可释放空间</h2>
<table>
<tr><th>垃圾类别</th><th>占用空间</th><th>建议</th></tr>
$junkRows
</table>
<div class="tip"><b>$junkTip</b>磁盘空间充足，清理优先级不高，可按需执行。</div>
</div>
<div class="card">
<h2>二、大文件扫描（&gt;500MB 且超 60 天未修改 · 前 10）</h2>
<table>
<tr><th>#</th><th>文件路径</th><th>大小</th><th>最后修改</th><th>最后访问</th></tr>
$bigRows
</table>
$bigWarn
</div>
<div class="card">
<h2>三、系统性能</h2>
<div class="grid">
<div class="metric"><div class="label">CPU 型号</div><div class="value">$cpuName</div><div style="font-size:13px;color:var(--sub)">$cpuCores 逻辑核心</div></div>
<div class="metric"><div class="label">CPU 占用率</div><div class="value">$cpuTxt</div></div>
<div class="metric"><div class="label">物理内存</div><div class="value">$memTotal GB</div><div style="font-size:13px;color:var(--sub)">已用 $memUsed GB</div></div>
<div class="metric"><div class="label">内存占用率</div><div class="value">$memPct%</div><div style="font-size:13px;color:var(--sub)">剩余可用 $memFree GB</div></div>
<div class="metric"><div class="label">后台进程数</div><div class="value">$procCount 个</div></div>
</div>
<h2 style="margin-top:24px">自启动项（共 $($startups.Count) 项）</h2>
<table>
<tr><th>启动项</th><th>状态</th><th>建议</th></tr>
$startupRows
</table>
<div class="tip"><b>性能结论：</b>CPU 占用 $cpuTxt，内存占用 $memPct%。$startupNote</div>
</div>
<div class="card">
"@
# 电池健康 HTML 块（预计算变量，避免嵌套 here-string）
if($hasBattery){
$battBlock = @"
<div class="grid">
<div class="metric"><div class="label">电池健康度</div><div class="value">$healthPct%</div><div style="font-size:13px;color:var(--sub)">损耗率 $([math]::Round(100-$healthPct,1))%</div>$bCirc</div>
<div class="metric"><div class="label">设计 / 满充容量</div><div class="value">$design / $full mWh</div></div>
<div class="metric"><div class="label">循环次数</div><div class="value">$($(if($cycle){$cycle}else{'未知'})) 次</div></div>
<div class="metric"><div class="label">电源计划</div><div class="value">$($(if($powerPlan){$powerPlan}else{'平衡'}))</div></div>
<div class="metric"><div class="label">屏幕亮度</div><div class="value">$($(if($bright){$bright}else{'—'}))</div></div>
<div class="metric"><div class="label">节电模式</div><div class="value">$battSaver</div></div>
</div>
<div class="tip"><b>电池结论：</b>健康度 $healthPct%、$($(if($cycle){$cycle}else{'未知'})) 次循环，$($(if($healthPct -ge 80){'属正常老化阶段。'}else{'容量衰减明显，建议关注电池养护。'}))当前$($(if($plug -like '*插电*'){'接入电源（AC）使用'}else{'使用电池'}))。</div>
"@
} else {
$battBlock = '<div class="tip">本机未检测到电池，可能为台式机或电池异常，跳过电池评估。</div>'
}
$html += @"
<h2>四、电池健康（$($(if($hasBattery){'笔记本'}else{'无电池/台式机'}))）</h2>
$battBlock
</div>
<div class="card">
<h2>五、使用习惯分析</h2>
<div class="grid">
<div class="metric"><div class="label">近 7 天开机次数</div><div class="value">$bootCount 次</div></div>
<div class="metric"><div class="label">近 7 天累计在线时长</div><div class="value">约 $totalH 小时</div><div style="font-size:13px;color:var(--sub)">日均约 $avgH 小时</div></div>
<div class="metric"><div class="label">最近开机 / 重启时间</div><div class="value">$($lastBoot.ToString('yyyy-MM-dd HH:mm'))</div><div style="font-size:13px;color:var(--sub)">已连续运行约 $upH 小时（$upDays 天）</div></div>
<div class="metric"><div class="label">插电使用情况</div><div class="value">$($(if($plug){$plug}else{'—'}))</div></div>
</div>
<div class="tip"><b>习惯结论：</b>日均使用约 $avgH 小时。当前已连续运行约 $upDays 天，建议<u>定期重启系统</u>以清理内存缓存；$($(if($plug -like '*插电*'){'长期插电建议开启电池养护功能。'}else{'注意合理规划充电。'}))</div>
</div>
<div class="card">
<h2>六、综合优化建议</h2>
<table>
<tr><th>优先级</th><th>建议</th><th>预期收益</th></tr>
<tr><td class="warn"><b>高</b></td><td>$($(if($big.Count -gt 0){"清理 / 归档前 10 大未修改文件（共约 $(Fmt-Size (($big | Measure-Object SizeMB -Sum).Sum))）" }else{"磁盘空间充足，无需紧急处理"}))</td><td>释放磁盘空间</td></tr>
<tr><td class="warn"><b>中</b></td><td>清理约 $(Fmt-Size $clearable) 垃圾文件（临时文件、浏览器缓存、回收站、更新备份、崩溃转储）</td><td>释放磁盘空间，保持系统整洁</td></tr>
$($(if($disableCnt -gt 0){"<tr><td class=`"warn`"><b>中</b></td><td>禁用 $disableCnt 项非必需自启动项</td><td>加快开机速度，降低后台占用</td></tr>"}else{""}))
<tr><td class="ok"><b>低</b></td><td>定期重启系统（当前已连续运行 $upDays 天）</td><td>清理内存缓存，保持系统流畅</td></tr>
</table>
</div>
<footer>报告由 一键电脑体检工具 自动生成 · 数据采集时间 $($reportTime.ToString('yyyy-MM-dd HH:mm')) · 仅供参考，删除 / 清理操作请先自行备份确认</footer>
</div>
</body>
</html>
"@
[System.IO.File]::WriteAllText($reportPath, $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "报告已生成：$reportPath" -ForegroundColor Green
Write-Host "正在用浏览器打开报告..." -ForegroundColor Cyan
Start-Process $reportPath
Write-Host ""
Write-Host "体检完成，请查看浏览器中的报告。按任意键退出..." -ForegroundColor Yellow
