$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output 'PROGRESS|5|正在初始化'
$ProgressPreference = 'SilentlyContinue'
function Fmt-Size([double]$mb){ if($mb -ge 1024){ return ('{0:N1} GB' -f ($mb/1024)) }; return ('{0:N1} MB' -f $mb) }
function Pct-Class([double]$pct){ if($pct -ge 90){return 'bad'}; if($pct -ge 70){return 'warn'}; return 'ok' }
function Get-DirSizeMB([string]$path){
  if(-not (Test-Path -LiteralPath $path)){ return 0 }
  try{ $bytes=(Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum; return [math]::Round($bytes/1MB,1) }catch{ return 0 }
}
$disks = @()
$diskMaxPct = 0.0
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  $tot=[math]::Round($_.Size/1GB,1); $free=[math]::Round($_.FreeSpace/1GB,1); $used=[math]::Round($tot-$free,1)
  $pct=if($tot -gt 0){[math]::Round($used/$tot*100,1)}else{0}
  if($pct -gt $diskMaxPct){$diskMaxPct=$pct}
  $disks += [pscustomobject]@{Device=$_.DeviceID;TotalGB=$tot;UsedGB=$used;FreeGB=$free;Pct=$pct;Cls=(Pct-Class $pct)}
}
Write-Output 'PROGRESS|10|正在读取磁盘分区信息'
$diskNote = if($diskMaxPct -gt 85){"部分分区空间较紧张，建议及时清理。"}else{"所有分区使用率均低于 85%，磁盘空间充裕。"}
$user=$env:USERPROFILE
$tmpSys=Get-DirSizeMB 'C:\Windows\Temp'; $tmpUser=Get-DirSizeMB $env:TEMP
Write-Output 'PROGRESS|12|正在统计临时文件'
$cacheChrome=Get-DirSizeMB "$user\AppData\Local\Google\Chrome\User Data\Default\Cache"; $cacheChrome2=Get-DirSizeMB "$user\AppData\Local\Google\Chrome\User Data\Default\Code Cache"
$cacheEdge=Get-DirSizeMB "$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache"; $cacheEdge2=Get-DirSizeMB "$user\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"
$cacheAll=[math]::Round($cacheChrome+$cacheChrome2+$cacheEdge+$cacheEdge2,1)
Write-Output 'PROGRESS|14|正在统计浏览器缓存'
$recycle=Get-DirSizeMB 'C:\$Recycle.Bin'; $winsxsDL=Get-DirSizeMB 'C:\Windows\SoftwareDistribution\Download'
Write-Output 'PROGRESS|16|正在统计回收站与更新缓存'
$wer=Get-DirSizeMB 'C:\ProgramData\Microsoft\Windows\WER'; $crash=Get-DirSizeMB "$user\AppData\Local\CrashDumps"; $logAll=[math]::Round($wer+$crash,1)
Write-Output 'PROGRESS|18|正在统计应用日志与崩溃转储'
$mini=Get-DirSizeMB 'C:\Windows\Minidump'; $lkr=Get-DirSizeMB 'C:\Windows\LiveKernelReports'; $dmpAll=[math]::Round($mini+$lkr,1)
Write-Output 'PROGRESS|20|正在统计系统崩溃转储'
$winOld=Get-DirSizeMB 'C:\Windows.old'
Write-Output 'PROGRESS|22|正在检查旧系统备份'
$hiber=0; if(Test-Path 'C:\hiberfil.sys'){ try{$hiber=[math]::Round((Get-Item 'C:\hiberfil.sys' -Force).Length/1MB,1)}catch{$hiber=-1} }
Write-Output 'PROGRESS|24|正在检查休眠文件'
$pagef=0; if(Test-Path 'C:\pagefile.sys'){ try{$pagef=[math]::Round((Get-Item 'C:\pagefile.sys' -Force).Length/1MB,1)}catch{$pagef=-1} }
Write-Output 'PROGRESS|26|正在检查页面文件'
$clearable=[math]::Round($tmpSys+$tmpUser+$cacheAll+$recycle+$winsxsDL+$logAll+$dmpAll,1)
Write-Output 'PROGRESS|28|正在计算可清理空间'
function Junk-Obj($name,$sizeMB,$tip,$cls){ if($sizeMB -lt 0){return [pscustomobject]@{Name=$name;Size='受限未读取';Tip='系统保护，不推荐处理';Cls='ok'}}; if($sizeMB -eq 0){return [pscustomobject]@{Name=$name;Size='0 MB';Tip=$tip;Cls='ok'}}; return [pscustomobject]@{Name=$name;Size=(Fmt-Size $sizeMB);Tip='可清理';Cls=$cls} }
$junkRows = @()
$junkRows += Junk-Obj '系统临时文件（C:\Windows\Temp）' $tmpSys '无需处理' 'warn'
$junkRows += Junk-Obj '用户临时文件（%TEMP%）' $tmpUser '无需处理' 'warn'
$junkRows += Junk-Obj '浏览器缓存（Chrome/Edge）' $cacheAll '无需处理' 'warn'
$junkRows += Junk-Obj '回收站' $recycle '可清理（清空前请确认）' 'warn'
$junkRows += Junk-Obj 'Windows 更新备份（SoftwareDistribution\Download）' $winsxsDL '无需处理' 'warn'
$junkRows += Junk-Obj '应用日志 / 崩溃转储（WER + CrashDumps）' $logAll '无需处理' 'warn'
$junkRows += Junk-Obj '系统崩溃转储（Minidump / LiveKernelReports）' $dmpAll '无需处理' 'ok'
$junkRows += Junk-Obj 'Windows.old 旧系统备份' $winOld '不存在' 'ok'
$junkRows += Junk-Obj '休眠文件（hiberfil.sys）' $hiber '系统保护，不推荐处理' 'ok'
$junkRows += Junk-Obj '页面文件（pagefile.sys）' $pagef '系统保护，不推荐处理' 'ok'
$junkTip = "预计可释放空间：约 $(Fmt-Size $clearable)（临时文件 + 浏览器缓存 + 回收站 + 更新备份 + 崩溃转储）。"
Write-Output 'PROGRESS|30|正在统计待扫描文件'
$cutoff=(Get-Date).AddDays(-60)
$bigList=New-Object System.Collections.Generic.List[object]
$scanRoots=@('C:\Users','C:\')
$totalEst=0
$estSeen=New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach($root in $scanRoots){
  if(-not (Test-Path -LiteralPath $root)){continue}
  if($estSeen.Contains($root)){continue}; [void]$estSeen.Add($root)
  try{ $totalEst += (Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count }catch{}
}
$totalEst=[Math]::Max(1,$totalEst)
Write-Output 'PROGRESS|31|开始扫描大文件'
$processed=New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$scanCount=0
$lastScanPct=31
foreach($root in $scanRoots){
  if(-not (Test-Path -LiteralPath $root)){continue}
  if($processed.Contains($root)){continue}; [void]$processed.Add($root)
  try{
    Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
      ForEach-Object {
        $scanCount++
        if(($scanCount % 300) -eq 0){
          $sp=[math]::Min(54,[math]::Round(31 + 23*$scanCount/$totalEst))
          if($sp -ge $lastScanPct){
            $lastScanPct=$sp
            Write-Output ("PROGRESS|{0}|正在扫描大文件（已扫描 {1} / 约 {2} 个文件）" -f $sp, $scanCount, $totalEst)
          }
        }
        if($_.Length -gt 500MB -and $_.LastWriteTime -lt $cutoff){ $bigList.Add([pscustomobject]@{FullName=$_.FullName;SizeMB=[math]::Round($_.Length/1MB,1);LastWriteTime=$_.LastWriteTime;LastAccessTime=$_.LastAccessTime}) }
      }
  }catch{}
}
Write-Output 'PROGRESS|55|正在整理大文件结果'
$big = $bigList | Sort-Object SizeMB -Descending | Select-Object -First 10
$bigFiles=@(); $i=0
foreach($f in $big){ $i++; $szCls=if($f.SizeMB -ge 10000){'bad'}elseif($f.SizeMB -ge 2000){'warn'}else{'ok'}
  $bigFiles += [pscustomobject]@{Idx=$i;Path=$f.FullName;Size=(Fmt-Size $f.SizeMB);Cls=$szCls;LastWrite=$f.LastWriteTime.ToString('yyyy-MM-dd');LastAccess=$f.LastAccessTime.ToString('yyyy-MM-dd')} }
$bigWarn = if($big.Count -eq 0){"近 60 天内未发现超过 500MB 且长期未修改的大文件。"}else{"以上为超大且长期未修改文件。删除 / 归档前请务必确认文件内容，避免误删重要数据。"}
Write-Output 'PROGRESS|56|正在检测系统性能'
$cpuTxt='N/A'
try{ $c1=(Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2).CounterSamples.CookedValue | Measure-Object -Average; $cpuTxt=('{0:N0}%' -f $c1.Average) }catch{ $cpuTxt=(Get-CimInstance Win32_Processor).LoadPercentage.ToString()+'%' }
Write-Output 'PROGRESS|58|正在检测 CPU 占用'
$os=Get-CimInstance Win32_OperatingSystem
$memTotal=[math]::Round($os.TotalVisibleMemorySize/1MB,1); $memFree=[math]::Round($os.FreePhysicalMemory/1MB,1); $memUsed=[math]::Round($memTotal-$memFree,1)
$memPct=if($memTotal -gt 0){[math]::Round($memUsed/$memTotal*100,1)}else{0}
Write-Output 'PROGRESS|60|正在检测内存占用'
$procCount=(Get-Process).Count
Write-Output 'PROGRESS|62|正在统计运行进程'
$cpuName=(Get-CimInstance Win32_Processor).Name; $cpuCores=(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
Write-Output 'PROGRESS|64|正在读取处理器信息'
$startups=Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location
Write-Output 'PROGRESS|66|正在读取自启动项'
$safeStart=@('SecurityHealth','Windows Defender','Marvis','OneDrive','Microsoft','Windows','explorer')
$startupRows=@(); $disableCnt=0
foreach($s in $startups){
  $rec='ok'; $recTxt='建议保留'; $hit=$false
  foreach($k in @('Edge','IDMan','Download','WeChat','QQ','Wukong','Xunlei','BaiduNet','WPS','Bilibili','Discord','Steam','NVIDIA')){ if($s.Name -match $k){$hit=$true;break} }
  $sys=$false; foreach($k in $safeStart){ if($s.Name -match $k){$sys=$true;break} }
  if($hit -and -not $sys){ $rec='warn'; $recTxt='建议禁用（开机自启非必需）'; $disableCnt++ }
  $startupRows += [pscustomobject]@{Name=$s.Name;State='已开启';Rec=$rec;RecTxt=$recTxt}
}
$startupNote = "自启动项共 $($startups.Count) 项" + $(if($disableCnt -gt 0){"，建议禁用 $disableCnt 项以加快开机速度。"}else{"，均为系统必需，无需调整。"})
Write-Output 'PROGRESS|70|正在检测电池健康'
Write-Output 'PROGRESS|72|正在读取电池信息'
$hasBattery=$true
$bss=Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
$bcc=Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
$batStatus=Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not $bss -and -not $batStatus){$hasBattery=$false}
$design=$full=$healthPct=$cycle=$plug=$bright=$powerPlan=$battSaver=''
if($hasBattery){
  if($bss){$design=[math]::Round([double]$bss.DesignedCapacity/1000,0)}
  if($bcc){$full=[math]::Round([double]$bcc.FullChargedCapacity/1000,0)}
  $brFile=''
  if($design -le 0 -or $full -le 0){
    try{
      $brFile=Join-Path $env:TEMP ("br-{0}.html" -f ([guid]::NewGuid().ToString('N'))); powercfg /batteryreport /output $brFile | Out-Null
      if(Test-Path $brFile){ $brHtml=Get-Content -LiteralPath $brFile -Raw -Encoding Unicode
        if($design -le 0 -and $brHtml -match 'Design Capacity</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $design=[math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($design -le 0 -and $brHtml -match '设计容量</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $design=[math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($full -le 0 -and $brHtml -match 'Full Charge Capacity</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $full=[math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
        if($full -le 0 -and $brHtml -match '满充电容量</td>\s*<td>([0-9,\s]+)' -and $Matches[1]){ $full=[math]::Round([double]($Matches[1] -replace '[,\s]','')/1000,0) }
      }
    }catch{}
  }
  if($design -gt 0 -and $full -gt 0){ $healthPct=[math]::Round($full/$design*100,1) }
Write-Output 'PROGRESS|74|正在计算电池健康度'
  try{
    if(-not $brFile -or -not (Test-Path $brFile)){ $brFile=Join-Path $env:TEMP ("br-{0}.html" -f ([guid]::NewGuid().ToString('N'))); powercfg /batteryreport /output $brFile | Out-Null }
    if(Test-Path $brFile){ $brHtml=Get-Content -LiteralPath $brFile -Raw -Encoding Unicode; if($brHtml -match 'Cycle Count</td>\s*<td>([0-9]+)' -or $brHtml -match '循环次数</td>\s*<td>([0-9]+)'){ $cycle=$Matches[1] } }
  }catch{}
Write-Output 'PROGRESS|78|正在统计循环次数'
  if(Test-Path $brFile){ Remove-Item -LiteralPath $brFile -Force -ErrorAction SilentlyContinue }
  if($batStatus){ $bs=$batStatus.BatteryStatus; $plug=if($bs -eq 2){'长期插电使用'}else{'当前使用电池'} }
  $bri=Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue | Select-Object -First 1
  if($bri){ $bright=$bri.CurrentBrightness.ToString()+'%' }
Write-Output 'PROGRESS|80|正在读取屏幕亮度'
  try{ $aps=powercfg /getactivescheme; $powerPlan=($aps -split '\(')[1].TrimEnd(')') }catch{}
Write-Output 'PROGRESS|82|正在读取电源计划'
  $battSaver=if($plug -like '*插电*'){'未单独启用（当前插电）'}else{'跟随电源计划自动'}
Write-Output 'PROGRESS|84|正在整理电池数据'
  if($healthPct -eq ''){ $healthPct = 'N/A' }
}
Write-Output 'PROGRESS|85|正在统计使用习惯与评分'
$bootCount=0; $totalMin=0
try{
  $ev=Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-General'; Id=12,13} -MaxEvents 400 -ErrorAction Stop
  $boot=@{}; $sorted=$ev | Sort-Object TimeCreated
  foreach($e in $sorted){ if($e.Id -eq 12){$boot[$e.TimeCreated]='up'}elseif($e.Id -eq 13){$boot[$e.TimeCreated]='down'} }
  $cut7=(Get-Date).AddDays(-7)
  $ups=($boot.GetEnumerator() | Where-Object {$_.Value -eq 'up' -and $_.Key -ge $cut7} | Sort-Object Key)
  $downs=($boot.GetEnumerator() | Where-Object {$_.Value -eq 'down' -and $_.Key -ge $cut7} | Sort-Object Key)
  $bootCount=$ups.Count
  foreach($u in $ups){ $d=$downs | Where-Object {$_.Key -gt $u.Key} | Select-Object -First 1; if($d){$totalMin += [math]::Round((($d.Key)-($u.Key)).TotalMinutes,0)} else { $totalMin += [math]::Round(((Get-Date)-($u.Key)).TotalMinutes,0) } }
}catch{}
Write-Output 'PROGRESS|88|正在统计开机记录'
$lastBoot=$os.LastBootUpTime; $upH=[math]::Round(((Get-Date)-$lastBoot).TotalHours,1); $upDays=[math]::Round($upH/24,1)
$avgH=if($bootCount -gt 0){[math]::Round($totalMin/60/$bootCount,1)}else{0}; $totalH=[math]::Round($totalMin/60,1)
Write-Output 'PROGRESS|90|正在计算使用时长'
$diskScore=0
try{ $cDisk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop; $cPct=[math]::Round(($cDisk.Size-$cDisk.FreeSpace)/$cDisk.Size*100,1)
  if($cPct -le 50){$diskScore=25}elseif($cPct -le 70){$diskScore=20}elseif($cPct -le 85){$diskScore=12}else{$diskScore=5} }catch{$diskScore=20}
$cpuNum=0.0; if($cpuTxt -match '([0-9.]+)'){$cpuNum=[double]$Matches[1]}
$perfScore=0
if($cpuNum -lt 50 -and $memPct -lt 70){$perfScore=25}elseif($cpuNum -lt 80 -and $memPct -lt 85){$perfScore=18}else{$perfScore=10}
$batScore=20; $hp=0.0; if($hasBattery){ if($healthPct -match '([0-9.]+)'){$hp=[double]$Matches[1]}; if($hp -ge 90){$batScore=25}elseif($hp -ge 80){$batScore=20}elseif($hp -ge 70){$batScore=14}else{$batScore=8} }
$cleanScore=25; if($clearable -ge 10240){$cleanScore=10}elseif($clearable -ge 3072){$cleanScore=16}elseif($clearable -ge 512){$cleanScore=21}
Write-Output 'PROGRESS|93|正在计算综合评分'
$score=[math]::Min(100,[math]::Round($diskScore+$perfScore+$batScore+$cleanScore))
$scoreCls=if($score -ge 90){'ok'}elseif($score -ge 75){'primary'}elseif($score -ge 60){'warn'}else{'bad'}
$scoreTxt=if($score -ge 90){'电脑整体状态优秀'}elseif($score -ge 75){'电脑整体状态良好'}elseif($score -ge 60){'电脑状态一般，建议按建议优化'}else{'电脑状态较差，请优先处理高优建议'}
$verdict=if($score -ge 75){"磁盘、内存、CPU 资源均处于健康水平。主要优化空间集中在：垃圾文件约 $(Fmt-Size $clearable) 可释放" + $(if($disableCnt -gt 0){", $disableCnt 项自启动项建议禁用"}else{''}) + "。"}else{"系统存在需要关注的问题，请按下方建议优先处理高优项。"}
if($hasBattery){ $verdict += "电池健康度 $healthPct% " + $(if($hp -ge 80){'属正常老化范围。'}else{'明显衰减，建议关注养护。'}) }
$diskCls=if($diskScore -ge 20){'ok'}elseif($diskScore -ge 12){'warn'}else{'bad'}
$perfCls=if($perfScore -ge 20){'ok'}elseif($perfScore -ge 12){'warn'}else{'bad'}
$batCls=if($hasBattery){if($batScore -ge 20){'ok'}elseif($batScore -ge 12){'warn'}else{'bad'}}else{'ok'}
$cleanCls=if($cleanScore -ge 20){'ok'}elseif($cleanScore -ge 12){'warn'}else{'bad'}
$dims=[pscustomobject]@{Disk=$diskScore;DiskCls=$diskCls;Perf=$perfScore;PerfCls=$perfCls;Battery=$batScore;BatteryCls=$batCls;Clean=$cleanScore;CleanCls=$cleanCls}
Write-Output 'PROGRESS|95|正在生成优化建议'
$suggestions=@()
$suggestions += [pscustomobject]@{Prio='高';Cls='warn';Text=$(if($big.Count -gt 0){"清理 / 归档前 10 大未修改文件（共约 $(Fmt-Size (($big | Measure-Object SizeMB -Sum).Sum))）"}else{'磁盘空间充足，无需紧急处理'});Gain='释放磁盘空间'}
$suggestions += [pscustomobject]@{Prio='中';Cls='warn';Text="清理约 $(Fmt-Size $clearable) 垃圾文件（临时文件、浏览器缓存、回收站、更新备份、崩溃转储）";Gain='释放磁盘空间，保持系统整洁'}
if($disableCnt -gt 0){ $suggestions += [pscustomobject]@{Prio='中';Cls='warn';Text="禁用 $disableCnt 项非必需自启动项";Gain='加快开机速度，降低后台占用'} }
Write-Output 'PROGRESS|97|正在汇总体检结果'
$suggestions += [pscustomobject]@{Prio='低';Cls='ok';Text="定期重启系统（当前已连续运行 $upDays 天）";Gain='清理内存缓存，保持系统流畅'}
$cs=Get-CimInstance Win32_ComputerSystem
$result=[pscustomobject]@{
  Device=("$($cs.Manufacturer) $($cs.Model)");
  Os=("$($os.Caption)（Build $($os.BuildNumber)）");
  Time=(Get-Date).ToString('yyyy-MM-dd HH:mm');
  Score=$score; ScoreCls=$scoreCls; ScoreTxt=$scoreTxt; Verdict=$verdict; Dims=$dims;
  Disks=$disks; DiskNote=$diskNote;
  JunkRows=$junkRows; JunkTip=$junkTip;
  BigFiles=$bigFiles; BigWarn=$bigWarn;
  CpuName=$cpuName; CpuCores=$cpuCores; CpuTxt=$cpuTxt;
  MemTotal=$memTotal; MemUsed=$memUsed; MemFree=$memFree; MemPct=$memPct; ProcCount=$procCount;
  StartupRows=$startupRows; StartupNote=$startupNote;
  HasBattery=$hasBattery; HealthPct=("$healthPct"); Design=$design; Full=$full; Cycle=("$cycle"); Plug=$plug; Bright=$bright; PowerPlan=$powerPlan; BattSaver=$battSaver;
  BootCount=$bootCount; TotalH=$totalH; AvgH=$avgH; LastBoot=$lastBoot.ToString('yyyy-MM-dd HH:mm'); UpH=$upH; UpDays=$upDays;
  Suggestions=$suggestions
}
Write-Output 'PROGRESS|100|体检完成'
$json = $result | ConvertTo-Json -Depth 6 -Compress
$jsonPath = Join-Path $env:TEMP ("scan_result_{0}.json" -f ([guid]::NewGuid().ToString('N')))
[System.IO.File]::WriteAllText($jsonPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output $jsonPath