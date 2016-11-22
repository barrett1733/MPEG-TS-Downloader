
function DownloadFiles([string[]] $list, [string] $server_dir, [string] $client_dir) {
	# tests for file, if doesn't exist, downloads it
	write-host ("Downloading files . . .")
	$counter = 0
	foreach ($item in $list) {
		$counter++
		if(Test-Path ($client_dir + $item)) {
			"(" + $counter + "/" + $list.count + ") Downloaded: " + $item
			}
		else {
			"(" + $counter + "/" + $list.count + ") Downloading: " + $item
			Invoke-WebRequest ($server_dir + $item) -OutFile ($client_dir + $item)
		}
	}
	write-host ("Finished`r`n")
}

function UrlLoader ([string] $url, [regex] $regex) {
	# download file
	write-host -NoNewline ("Loading " + $url + " . . . ")
	$contents = (Invoke-WebRequest -uri ($url)).tostring()
	write-host ("Finished`r`n")

	# parse file with regex into list
	write-host -NoNewline ("Parsing . . . ")
	$list = $contents | Select-String $regex -AllMatches | % { $_.Matches.Value } | select -uniq
	write-host ("Finished`r`n")

	if($list.count -ne 1) {
		write-host ("Found " + $list.count + " items.`r`n")
	}
	else {
		write-host ("Found " + $list.count + " item.`r`n")
	}
	
	if($list.count -gt 1) {
		# pick which file to load
		return PromptListLoad $list
	}
	
	return $list
}

function RecursiveFileLoader ([string] $server_dir, [string] $filename, [regex] $regex) {
	# download file
	write-host -NoNewline ("Loading " + $server_dir + $filename + " . . . ")
	$contents = (Invoke-WebRequest -uri ($server_dir + $filename)).tostring()
	write-host ("Finished`r`n")

	# parse file with regex into list
	write-host -NoNewline ("Parsing . . . ")
	$list = $contents | Select-String $regex -AllMatches | % { $_.Matches.Value } | select -uniq
	write-host ("Finished`r`n")

	if($list.count -ne 1) {
		write-host ("Found " + $list.count + " items.`r`n")
	}
	else {
		write-host ("Found " + $list.count + " item.`r`n")
	}
	
	if($list.count -gt 1) {
		# pick which file to load
		$filetoload = PromptListLoad $list
		return RecursiveFileLoader $server_dir $filetoload $regex # Warning: infinite recursion possible
	}
	return $contents
}

function PromptListLoad ([string[]] $list) {
	$string = "Pick a file to load.`r`n"
	$count = 0
	foreach ($item in $list) {
		$count++
		$string += ([string] $count + ": " + $item + "`r`n")
	}
	do {
		$answ = Read-Host -Prompt $string
	}
	until ([int]$answ -ge 1 -and [int]$answ -le $list.count)

	return $list[[int] $answ - 1]
}

function CombineFiles([string[]] $list, [string] $client_dir, [string] $filename) {
	# creates new file for combining, checks for file
	write-host ("Combining files . . .")
		
	if(Test-Path ($filename)) {
		$answ = Read-Host -Prompt ($filename + " detected. Overwrite (Y/N)")
		if($answ -eq "N" -or $answ -eq "n") {
			write-host ("Aborted`r`n")
			return
		}
	}
	
	# creates new file
	$combinedfile = New-Item $filename -type file -force
			
	# combines files into specified file
	$count = 0
	foreach ($item in $list) {
		$loadedfile = Get-Content ($client_dir + $item) -Encoding Byte -ReadCount 0

		Add-Content -Path $combinedfile -Value $loadedfile -Encoding Byte
		$count++
		"(" + $count + "/" + $list.count + ") Finished: " + $item
	}
	write-host ("Finished`r`n")
}

$regex_url_m3u8 = [regex] '.*\.m3u8'
$regex_page_m3u8 = [regex] '([\w\d-_.:\/\\]+\/)([\w\d-_.\\]+)\.m3u8'
$regex_file_m3u8 = [regex] '([\w\d-_.\\]+)\.m3u8'
$regex_file_ts = [regex] '([\w\d-_.\\]+)\.ts'
$regex_server_dir = [regex] '([\w\d-_.:\/\\]+\/)'

$url = [System.Uri] $args[0]
$page = [string]
$filename = $args[1]
$server_dir = [string]
$client_dir = [string]
$m3u8_list = [string] @()
$ts_list = @()

if ($args[0] -eq $null) {
	Write-Host ("No url supplied.")
	break
}

if ($args[1] -eq $null) {
	Write-Host ("No filename supplied.")
	break
}

# make new folder
if(-not (Test-Path $url.Host)) {
	write-host ("Creating directory " + $url.Host + ".`r`n")
	# store folder path
	$client_dir = (New-Item $url.Host -type directory).tostring() + "\"
}
else {
	write-host ("Directory " + $url.Host + " found.`r`n")
	$client_dir = (Get-Item $url.Host).tostring() + "\"
}

# check the url for .m3u8
if($regex_url_m3u8.ismatch($url.tostring())) {
	$m3u8_list = $url.tostring()
}
# load .m3u8
# parse all unique .m3u8 urls from page
# if more than one, prompt which m3u8 file to load
else {
	$m3u8_list = UrlLoader $url $regex_page_m3u8
}

if($m3u8_list.count -eq 0) {
	write-host ("Nothing Found.")
	return;
}

# set parent directory and filename
$server_dir = $regex_server_dir.match($m3u8_list).value
$m3u8_filename = $regex_file_m3u8.match($m3u8_list).value

# load file, search for more .m3u8 in file, if none return file
# all in same server directory
$m3u8 = RecursiveFileLoader $server_dir $m3u8_filename $regex_file_m3u8

# parse .m3u8 for .ts files
write-host -NoNewline ("Parsing . . . ")
$ts_list = $m3u8 | Select-String $regex_file_ts -AllMatches | % { $_.Matches.Value } | select -uniq
write-host -NoNewline ("Finished`r`n")

# downloads list of files from server directory to client directory
DownloadFiles $ts_list $server_dir $client_dir

# combines list of files into one file
CombineFiles $ts_list $client_dir $filename

# delete downloaded files
$answ = Read-Host -Prompt ("Cleanup? (Y/N)")
if($answ -eq "Y" -or $answ -eq "y") {
	Remove-Item -Recurse -Force $client_dir
}

