<#

    Download and create Windows 11 Pro and Enterprise WIMs

#>


# Where to save the VHDx files.
# --
$VHDXPath  = "C:\TS-Data\_Reference"
$DiskImage = "C:\TS-Data\Windows11-x64.iso"


if (!(Test-Path $VHDXPath)) {
    New-Item -Path $VHDXPath -ItemType Directory | Out-Null
}


# Get Latest Windows Client version.
# --------------------------------------------------------------------------------------------------
$Links = Invoke-WebRequest -uri "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise" -UseBasicParsing
$URLData = $Links.Links.outerHTML | Where {$_ -like "*Download Windows 11 Enterprise ISO 64-bit (en-US)*"}
$URLData -Match('href="([^"]+)"')

Invoke-WebRequest -Uri $matches[1] -OutFile $DiskImage -UseBasicParsing


# Create Refrence VIM
# --------------------------------------------------------------------------------------------------
if (Test-Path $DiskImage) {
	Mount-DiskImage -ImagePath $DiskImage | Out-Null
	$MountDrive = $((Get-DiskImage -ImagePath $DiskImage | get-volume).DriveLetter) + ":"
}

$WinVersions = Get-WindowsImage -ImagePath "$MountDrive\Sources\install.wim"


# Create New VHDx
$VHDFileName = $WinVersions.ImageName -replace(" Evaluation","")
$VHDXFile = Join-Path -Path $VHDXPath -ChildPath $($VHDFileName + ".vhdx")

if (!(Test-Path $VHDXFile)) {

	# Create New VHDx
	New-VHD -Path $VHDXFile -Dynamic -SizeBytes 50Gb | Out-Null
	Mount-DiskImage -ImagePath $VHDXFile
	$VHDXDisk = Get-DiskImage -ImagePath $VHDXFile | Get-Disk
	$VHDXDiskNumber = [string]$VHDXDisk.Number

	# Create Partitions
	Initialize-Disk -Number $VHDXDiskNumber -PartitionStyle GPT -Verbose
	$VHDXDrive1 = New-Partition -DiskNumber $VHDXDiskNumber -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" -Size 499MB
	$VHDXDrive1 | Format-Volume -FileSystem FAT32 -NewFileSystemLabel System -Confirm:$false | Out-Null
	$VHDXDrive2 = New-Partition -DiskNumber $VHDXDiskNumber -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}" -Size 128MB
	$VHDXDrive3 = New-Partition -DiskNumber $VHDXDiskNumber -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" -UseMaximumSize
	$VHDXDrive3 | Format-Volume -FileSystem NTFS -NewFileSystemLabel OSDisk -Confirm:$false | Out-Null
	Add-PartitionAccessPath -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive1.PartitionNumber -AssignDriveLetter
	$VHDXDrive1 = Get-Partition -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive1.PartitionNumber
	Add-PartitionAccessPath -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive3.PartitionNumber -AssignDriveLetter
	$VHDXDrive3 = Get-Partition -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive3.PartitionNumber
	$VHDXVolume1 = [string]$VHDXDrive1.DriveLetter+":"
	$VHDXVolume3 = [string]$VHDXDrive3.DriveLetter+":"

	# Extract image, and apply to VHDx
	Expand-WindowsImage -ImagePath "$MountDrive\Sources\install.wim" -Index 1 -ApplyPath $VHDXVolume3\ -ErrorAction Stop -LogPath Out-Null

	# Apply BootFiles
	cmd /c "$VHDXVolume3\Windows\system32\bcdboot $VHDXVolume3\Windows /s $VHDXVolume1 /f ALL"

	# Change ID on FAT32 Partition
	$DiskPartTextFile = New-Item "diskpart.txt" -type File -force
	Set-Content $DiskPartTextFile "select disk $VHDXDiskNumber"
	Add-Content $DiskPartTextFile "Select Partition 2"
	Add-Content $DiskPartTextFile "Set ID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b OVERRIDE"
	Add-Content $DiskPartTextFile "GPT Attributes=0x8000000000000000"
	cmd /c "diskpart.exe /s .\diskpart.txt"

	Dismount-DiskImage -ImagePath $VHDXFile
}

Dismount-DiskImage -ImagePath $DiskImage
