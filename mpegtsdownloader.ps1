
function GetFilename ([System.Uri] $url) {
	$match = ([regex] '(.*(?:\\|\/)+)?((.*)(\.([^?\s]*)))\??(.*)?').match($url)
	return $match.groups[2].value
}

function DownloadFiles ([System.Uri[]] $url_list, [string] $client_dir) {
	# tests for file, if doesn't exist, downloads it
	write-host ("Downloading files . . .")
	$counter = 0
	foreach ($item in $url_list) {
		$counter++
		$filename = GetFilename($item)
		if(Test-Path ($client_dir + $filename)) {
			"(" + $counter + "/" + $url_list.count + ") Downloaded: " + $filename
			}
		else {
			"(" + $counter + "/" + $url_list.count + ") Downloading: " + $filename
			Invoke-WebRequest -uri ($item) -OutFile ($client_dir + $filename)
		}
	}
	write-host ("Finished`r`n")
}

function FileDownloader ([System.Uri] $url) {
	# download file
	write-host -NoNewline ("Loading " + $url + " . . . ")
	$contents = (Invoke-WebRequest -uri ($url)).tostring()
	write-host ("Finished`r`n")
	return $contents
}

function FileParser ([string] $file, [regex] $regex){
	# parse file with regex into list
	write-host -NoNewline ("Parsing . . . ")
	$list = $file | Select-String $regex -AllMatches | % { $_.Matches.Value } | select -uniq
	write-host ("Finished`r`n")
	return $list
}

function PromptUrlToLoad ([System.Uri[]] $list) {
	$string = "Pick a file to load.`r`n"
	$count = 0
	foreach ($item in $list) {
		$count++
		$string += ([string] $count + ": " + $item.tostring() + "`r`n")
	}
	do {
		$answ = Read-Host -Prompt $string
	}
	until ([int]$answ -ge 1 -and [int]$answ -le $list.count)

	return $list[[int] $answ - 1]
}

function CombineUrlFilename ([System.Uri] $url, [string] $file) {
	# is file a file or directory + file
	if (([regex] '\/.*|\\.*').ismatch($file)) {
		# directory + file
		$server_url = $url.scheme + '://' + $url.host
		return [System.Uri] ($server_url + $file)
	}
	else {
		# file
		# get host + directory - file
		$path = ([regex] '.*\/|.*\\').match($url.absoluteUri).tostring()
		return [System.Uri] ($path + $file)
	}
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
	$combiningfile = New-Item $filename -type file -force
			
	# combines files into specified file
	$count = 0
	foreach ($item in $list) {
		$item_filename = GetFilename($item)
		$loadedfile = Get-Content ($client_dir + $item_filename) -Encoding Byte -ReadCount 0

		Add-Content -Path $combiningfile -Value $loadedfile -Encoding Byte
		$count++
		"(" + $count + "/" + $list.count + ") Finished: " + $item_filename
	}
	write-host ("Finished`r`n")
}

$regex_url_m3u8 = [regex] 'http+s*\:.*\/.*\.m3u8'
$regex_file_m3u8 = [regex] '.*\.m3u8'
$regex_file_ts = [regex] '.*\.ts'

$in_url = [System.Uri] $args[0]
$filename_ts = $args[1]
$current_url = [System.Uri]
$client_dir = [System.IO.FileInfo]

$in_url = [System.Uri] (Read-Host "Enter URL")
$filename_ts = Read-Host "Enter output filename"

# check if url is valid
if($regex_url_m3u8.ismatch($in_url.absoluteUri)) {
	$current_url = $in_url
}
else {
	write-host ("Url not valid.")
	return;
}

if(-not (Test-Path $in_url.Host)) {
	write-host ("Creating directory " + $in_url.Host + ".`r`n")
	# make new folder, store folder path
	$client_dir = (New-Item $in_url.Host -type directory).tostring() + "\"
}
else {
	write-host ("Directory " + $in_url.Host + " found.`r`n")
	# found folder, store folder path
	$client_dir = (Get-Item $in_url.Host).tostring() + "\"
}

while ($current_url.tostring() -ne '') {
	write-host $current_url
	$current_file = FileDownloader $current_url

	# parse file with regex into list
	$file_m3u8_list = FileParser $current_file $regex_file_m3u8
	
	if($file_m3u8_list.count -ne 1) {
		write-host ("Found " + $file_m3u8_list.count + " items.`r`n")
	}
	else {
		write-host ("Found " + $file_m3u8_list.count + " item.`r`n")
	}
	
	if ($file_m3u8_list.count -gt 1) {
		# pick which file to load
		$file_choice = PromptUrlToLoad $file_m3u8_list
		$current_url = CombineUrlFilename $current_url $file_choice
	}
	elseif ($file_m3u8_list.count -eq 1) {
		$current_url = CombineUrlFilename $current_url $file_m3u8_list
	}
	else {
		# load .ts files
		$file_ts_list = FileParser $current_file $regex_file_ts
		
		# makes new list of .ts urls
		$url_ts_list = @()
		foreach ($filename in $file_ts_list) {
			$url_ts_list += CombineUrlFilename $current_url $filename
		}

		# downloads list of files from server directory to client directory
		DownloadFiles $url_ts_list $client_dir
		
		# combines list of files into one file
		CombineFiles $file_ts_list $client_dir $filename_ts
		
		# delete downloaded files
		$answ = Read-Host -Prompt ("Cleanup? (Y/N)")
		if($answ -eq "Y" -or $answ -eq "y") {
			Remove-Item -Recurse -Force $client_dir
		}
		# clear current url to end loop
		$current_url = [System.Uri] ''
	}
}
