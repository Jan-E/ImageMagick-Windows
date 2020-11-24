function GetConfig($platform, $name, $vcversion, $toolset)
{
  $config = $null
  $options = "/includeOptional /installedSupport /deprecated"

  if ($name -eq "dll-Q8")
  {
    $config = @{options="/dmt /noHdri /Q8 $options";perl=$true;type="installer";solution="VisualDynamicMT.sln"}
  }
  elseif ($name -eq "dll-Q16")
  {
    $config = @{options="/dmt /noHdri /Q16 $options";perl=$true;type="installer";solution="VisualDynamicMT.sln"}
  }
  elseif ($name -eq "static-Q8")
  {
    $config = @{options="/smtd /noHdri /Q8 $options";perl=$false;type="installer";solution="VisualStaticMTD.sln"}
  }
  elseif ($name -eq "static-Q16")
  {
    $config = @{options="/smtd /noHdri /Q16 $options";perl=$false;type="installer";solution="VisualStaticMTD.sln"}
  }

  elseif ($name -eq "hdri-dll-Q16")
  {
    $config = @{options="/dmt /hdri /Q16 $options";perl=$true;type="installer";solution="VisualDynamicMT.sln"}
  }
  elseif ($name -eq "hdri-static-Q16")
  {
    $config = @{options="/smtd /hdri /Q16 $options";perl=$false;type="installer";solution="VisualStaticMTD.sln"}
  }

  elseif ($name -eq "portable-Q16")
  {
    $config = @{options="/smt /noOpenMP /Q16";perl=$false;type="portable";solution="VisualStaticMT.sln"}
  }

  if ($config -ne $null)
  {
    $config.platform = $platform
    $config.name = $name
    $config.vcversion = $vcversion
    $config.toolset = $toolset
  }

  return $config
}

function GetVersion()
{
  $version = "7.x.x"
  $addendum = "-x"

  foreach ($line in [System.IO.File]::ReadLines("../ImageMagick/version.sh"))
  {
    if ($line.StartsWith("PACKAGE_RELEASE="))
    {
      $addendum = "-" + $line.SubString(17, $line.Length - 18)
    }
    elseif ($line.StartsWith("PACKAGE_VERSION="))
    {
      $version = $line.SubString(17, $line.Length - 18)
    }
  }

  return "$version$addendum"
}

function CheckExitCode($msg)
{
  if ($LastExitCode -ne 0)
  {
    Throw $msg
  }
}

function BuildConfigure()
{
  Set-Location ../VisualMagick/configure
  devenv /upgrade configure.vcxproj
  msbuild configure.sln /m:4 /t:Rebuild ("/p:Configuration=Release,Platform=Win32")
  CheckExitCode "Failed to build: configure.exe"

  Set-Location ../../AppVeyor
}

function BuildConfiguration($config)
{
  $platformName = "Win32"
  $options = $config.options
  if ($config.platform -eq "x64")
  {
    $platformName = "x64"
    $options = "$options /x64"
  }

  Set-Location ../VisualMagick/configure
  Write-Host "configure.exe /noWizard /VS2019 $options"
  Start-Process configure.exe -ArgumentList "/noWizard /VS2015 $options" -wait

  Set-Location ..
  foreach ($f in gci -r -include "*.vcxproj*") 
    { (gc $f.fullname) |
       foreach { $_ -replace "v141_xp" ,"$($config.toolset)" } |
       foreach { $_ -replace "v140_xp" ,"$($config.toolset)" } |
       foreach { $_ -replace "v120_xp" ,"$($config.toolset)" } |
       foreach { $_ -replace "v110_xp" ,"$($config.toolset)" } |
       foreach { $_ -replace "v100_xp" ,"$($config.toolset)" } |
       foreach { $_ -replace "v141"    ,"$($config.toolset)" } |
       foreach { $_ -replace "v140"    ,"$($config.toolset)" } |
       foreach { $_ -replace "v120"    ,"$($config.toolset)" } |
       foreach { $_ -replace "v110"    ,"$($config.toolset)" } |
       foreach { $_ -replace "v100"    ,"$($config.toolset)" } |
       sc $f.fullname 
    }
  devenv $config.solution /Build "Release|$platformName"
  CheckExitCode "Failed to build: $($config.name)"

  Set-Location ../AppVeyor

  if ($config.perl -eq $true)
  {
    BuildPerlMagick $platform
  }
}

function BuildPerlMagick($platform)
{
  $folder = "C:\Strawberry"
  $env:Path = "$($env:Path);$folder\c\bin"

  Set-Location ../ImageMagick/PerlMagick

  & "$folder\perl\bin\perl.exe" "Makefile.PL" "MAKE=nmake"
  CheckExitCode "Failed to create Makefile: $($name)"

  & "nmake"
  CheckExitCode "Failed to build PerlMagick"

  & "nmake" "release"
  CheckExitCode "Failed to build PerlMagick release"

  Set-Location ../../AppVeyor
}

function CreatePackage($config, $version)
{
  if ($config.type -eq "installer")
  {
    CreateInstaller $config
    CreateDeps $config $version
  }
  elseif ($config.type -eq "deps")
  {
    CreateDeps $config $version
  }
  elseif ($config.type -eq "portable")
  {
    CreatePortable $config $version
  }
  elseif ($config.type -eq "source")
  {
    CreateSource
  }
}

function CreateInstaller($config)
{
  & "C:\Program Files (x86)\Inno Setup 5\iscc.exe" "..\VisualMagick\installer\im-$($config.platform)-$($config.name).iss"
  CheckExitCode "Failed to create setup executable."

  Get-ChildItem -Path ..\VisualMagick\installer\output\*.exe -Recurse | Move-Item -Destination ..\Windows-Distribution
}

function CreateZipFile($fileName, $directory)
{
  Write-Host "Creating: $($fileName)"
  Add-Type -Assembly System.IO.Compression.FileSystem
  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
  [System.IO.Compression.ZipFile]::CreateFromDirectory($directory, $fileName, $compressionLevel, $false)
}

function CreatePortable($config, $version)
{
  New-Item -ItemType directory -Path .\Portable | Out-Null

  Copy-Item ..\VisualMagick\bin\*.exe .\Portable
  Copy-Item ..\ImageMagick\config\colors.xml .\Portable
  Copy-Item ..\ImageMagick\config\english.xml .\Portable
  Copy-Item ..\ImageMagick\config\locale.xml .\Portable
  Copy-Item ..\ImageMagick\config\log.xml .\Portable
  Copy-Item ..\ImageMagick\config\mime.xml .\Portable
  Copy-Item ..\ImageMagick\config\quantization-table.xml .\Portable
  Copy-Item ..\VisualMagick\bin\configure.xml .\Portable
  Copy-Item ..\VisualMagick\bin\ImageMagick.rdf .\Portable
  Copy-Item ..\VisualMagick\bin\delegates.xml .\Portable
  Copy-Item ..\VisualMagick\bin\policy.xml .\Portable
  Copy-Item ..\VisualMagick\bin\sRGB.icc .\Portable
  Copy-Item ..\VisualMagick\bin\thresholds.xml .\Portable
  Copy-Item ..\VisualMagick\bin\type-ghostscript.xml .\Portable
  Copy-Item ..\VisualMagick\bin\type.xml .\Portable

  Copy-Item ..\ImageMagick\ChangeLog .\Portable
  Copy-Item ..\ImageMagick\images .\Portable -recurse
  Copy-Item ..\ImageMagick\index.html .\Portable
  Copy-Item ..\ImageMagick\LICENSE .\Portable\LICENSE.txt
  Copy-Item ..\VisualMagick\NOTICE.txt .\Portable
  Copy-Item ..\ImageMagick\README.txt .\Portable
  Copy-Item ..\ImageMagick\www .\Portable -recurse

  CheckExitCode "Failed to copy files."

  $output = "..\Windows-Distribution\ImageMagick-$($version)-$($config.name)-$($config.platform).zip"
  CreateZipFile $output ".\Portable"
}

function CreateDeps($config, $version)
{
  New-Item -ItemType directory -Path .\Deps | Out-Null
  New-Item -ItemType directory -Path .\Deps\bin | Out-Null	
  New-Item -ItemType directory -Path .\Deps\lib | Out-Null
  New-Item -ItemType directory -Path .\Deps\include | Out-Null
  New-Item -ItemType directory -Path .\Deps\include\MagickWand | Out-Null
  New-Item -ItemType directory -Path .\Deps\include\MagickCore | Out-Null
  New-Item -ItemType directory -Path .\Deps\include\Magick++ | Out-Null

  Copy-Item ..\VisualMagick\bin\*.* .\Deps\bin
  Copy-Item ..\VisualMagick\lib\*.* .\Deps\lib
  Copy-Item ..\ImageMagick\MagickWand\*.h .\Deps\include\MagickWand -recurse
  Copy-Item ..\ImageMagick\MagickCore\*.h .\Deps\include\MagickCore -recurse
  Copy-Item ..\ImageMagick\Magick++\lib\Magick++.h .\Deps\include
  Copy-Item ..\ImageMagick\Magick++\lib\Magick++\*.h .\Deps\include\Magick++ -recurse
  Copy-Item ..\ImageMagick\LICENSE .\Deps\LICENSE.txt

  CheckExitCode "Failed to copy files."

  $output = "..\Windows-Distribution\ImageMagick-$($version)-$($config.vcversion)-$($config.platform).zip"
  CreateZipFile $output ".\Deps"
}

function CreateSource($version)
{
  $folder = ".\Source\ImageMagick-$version"
  New-Item -ItemType directory -Path $folder | Out-Null

  $root = Get-Item ..
  ForEach ($dir in $root.GetDirectories())
  {
    if ($dir.Name -eq "AppVeyor" -Or $dir.Name -eq "Windows-Distribution")
    {
      continue;
    }

    if ($dir.Name -ne "dcraw")
    {
      Remove-Item "$($dir.FullName)\.git" -recurse -force
    }
    Write-Host "Adding $($dir.Name)"
    Copy-Item $dir.FullName $folder -recurse
  }

  $output = "..\Windows-Distribution\ImageMagick-Windows-$($version).zip"
  CreateZipFile $output ".\Source"
}

function CheckUpload()
{
#  $day = (Get-Date).DayOfWeek
#  if ($day -ne "Saturday" -And $day -ne "Sunday")
#  {
#    Write-Host "Only uploading in the weekend."
#    Remove-Item ..\Windows-Distribution\*
#  }
}

$platform = $args[0]
$name = $args[1]
$vcversion = $args[2]
$toolset = $args[3]

$version = GetVersion

New-Item -ItemType directory -Path ..\Windows-Distribution | Out-Null

if ($name -eq "source")
{
  CreateSource $version
}
else
{
  $config = GetConfig $platform $name $vcversion $toolset
  if ($config -eq $null)
  {
    throw "Unknown configuration: $name"
  }

  BuildConfigure
  BuildConfiguration $config
  CreatePackage $config $version
  CheckUpload
}
