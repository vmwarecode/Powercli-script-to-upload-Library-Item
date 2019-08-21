Function Add-LibraryItem {
	<#
		.NOTES :
		--------------------------------------------------------
		 Created by	: LOKESH HK
		 Organisation	: VMWARE
			 e-mail         : lhulibelekemp@vmware.com
		Modified by: K. Chris Nakagaki
			Organization    : Virtustream
			e-mail          : Chris.Nakagaki@virtustream.com
		--------------------------------------------------------
		.DESCRIPTION
			This function uploads item to the Content library from URL location.
		.PARAMETER  LibraryName
			Name of the library to which item needs to be uploaded.
		.PARAMETER	LibType
			Name of the file type. (File extension name)
		.PARAMETER	LibItemName
			Name of the library item.
		.PARAMETER	LibItemURLPath
			URL location of the file.
		.PARAMETER  SourceType
			Pull = Has vCenter 'pull' file from URL. | Push = Pushes file from client to vCenter server.  Default is pull.
		.PARAMETER	SkipCertificateCheck
			Skips Certificate check.
		.EXAMPLE
			These are "PULL" examples.  The syntax is made for vCenter's point of view.
			$URL = file:///path
			or
			$URL = file:///C:/path
			or
			$URL = file://unc-server/path
			or 
			$URL = ds:///vmfs/volumes/
	
			Connect-CISServer myvCenterNameorIP
			Add-LibraryItem -LibraryName 'LibraryName' -LibType 'ova' -LibItemName 'LibItemName' -LibItemURLPath $URL
			Add-LibraryItem -LibraryName 'LibraryName' -LibType 'vmdk' -LibItemName 'LibItemName' -LibItemURLPath $URL
			Add-LibraryItem -LibraryName 'LibraryName' -LibType 'ovf' -LibItemName 'LibItemName' -LibItemURLPath $URL
		.EXAMPLE
			These are "PUSH" examples.  URL syntax is highly dependent upon your local system, whether it is Linux or Windows.
			$URL="~/Documents/myOVF/myOVF.ovf"
			or
			$URL="C:\myOVF\myOVF.ovf"
	
			Connect-CISServer myvCenterNameorIP
			Add-LibraryItem -LibraryName 'LibraryName' -LibType 'ovf' -LibItemName 'LibItemName' -LibItemURLPath $URL -SourceType 'PUSH'
		
	#>
		param(
			[Parameter(Mandatory=$true)][string]$LibraryName,
			[Parameter(Mandatory=$true)][string]$LibType,
			[Parameter(Mandatory=$true)][string]$LibItemName,
			[Parameter(Mandatory=$true)][string]$LibItemURLPath,
			[Parameter(Mandatory=$false)][string][Validateset("Pull","Push")]$SourceType="PULL",
			[Parameter(Mandatory=$false)][boolean]$SkipCertificateCheck=$false
		)
		
		$ContentLibraryService = Get-CisService com.vmware.content.library
		
		$libaryIDs = $contentLibraryService.list()
		foreach($libraryID in $libaryIDs) {
			$library = $contentLibraryService.get($libraryID)
			if($library.name -eq $LibraryName){
				$library_ID = $libraryID
				break
			}
		}
		
		if(!$library_ID){
			write-host -ForegroundColor red $LibraryName " -- does not exist.."
		} else {
			$ContentLibraryItemService  = Get-CisService "com.vmware.content.library.item"
			$UniqueChangeId = [guid]::NewGuid().tostring()
	
			$createItemSpec = $ContentLibraryItemService.Help.create.create_spec.Create()
			$createItemSpec.type = $Libtype
			$createItemSpec.library_id = $library_ID
			$createItemSpec.name = $LibItemName
			write-host "Creating Library Item -- " $LibItemName
			$libraryItemId = $ContentLibraryItemService.create($UniqueChangeId,$createItemSpec)
			write-host "Library item is created with ID -- " $libraryItemId
			
			if(!$libraryItemId){
				write-host -ForegroundColor red "Failed to create Library item"
			} else {
				$ContentLibraryUpdateSession = Get-CisService "com.vmware.content.library.item.update_session"
				$SessionState = "ACTIVE"
				$createSessionSpec = $ContentLibraryUpdateSession.Help.create.create_spec.Create()
				$createSessionSpec.state = $SessionState
				$createSessionSpec.library_item_id = $libraryItemId
		
				write-host " Creating new Session ID " 
				$newSessionId = $ContentLibraryUpdateSession.create($UniqueChangeId,$createSessionSpec)
				write-host " New Session ID is created -- " $newSessionId
				
				if(!$newSessionId){
					write-host -ForegroundColor red " Failed to create Session ID"
				} else {
					$ContentLibraryUpdateItem = Get-Cisservice "com.vmware.content.library.item.updatesession.file"
					$createFileSpec = $ContentLibraryUpdateItem.Help.add.file_spec.Create()
					$LibItemName = $LibItemName+'.'+$LibType
					$createFileSpec.name = $LibItemName
					$SourceType = $SourceType.ToUpper()
					$createFileSpec.source_type = $SourceType
					Switch ($SourceType)
					{
						"PULL" 
						{
						$createFileSpec.source_endpoint.uri = $LibItemURLPath
						$ContentLibraryUpdateItem.add($newSessionId,$createFileSpec)
						write-host "File upload session is initiated."
						}
						"PUSH" 
						{
						$Data = $ContentLibraryUpdateItem.add($newSessionId,$createFileSpec)
						If (Test-Path $LibItemURLPath)
							{
								Write-Host ("Uploading " + $LibItemURLPath + " to Library: " + $LibraryName)
								Invoke-RestMethod -Method Put -Uri $data[0].upload_endpoint.uri.AbsoluteUri -InFile $LibItemURLPath -Credential $labcreds -SkipCertificateCheck:$SkipCertificateCheck       
								Write-Host ("Upload Complete, validating...")
								$validate = $ContentLibraryUpdateItem.validate($newSessionId)
							}
						Else 
							{
								Write-Host ("Path/File not found: " + $LibItemURLPath)
								Throw
							}
						If ($validate.missing_files)
							{
							Write-Host ("Additional files required to upload successfully.")
							Foreach ($missingfile in $validate.missing_files)
								{
								$ItemPath = Split-Path $LibItemURLPath
								Write-Host ("Looking for: " + $MissingFile + " in " + $ItemPath)
								$MissingFilePath = $ItemPath | Get-ChildItem | Where-Object {$_.Name -eq $missingfile} | Resolve-Path
								$test = Test-Path $MissingFilePath
								If ($test -eq $true)
									{
									Write-Host "File located."
									$createFileSpec = $ContentLibraryUpdateItem.Help.add.file_spec.Create()
									$createfilespec.name = $MissingFile
									$createFileSpec.source_type = $SourceType
									$Data = $ContentLibraryUpdateItem.add($newSessionId,$createFileSpec)
									Write-Host ("Uploading file:" + $Missingfile)
									Invoke-RestMethod -Method Put -Uri $data[0].upload_endpoint.uri.AbsoluteUri -InFile $missingfilepath.ProviderPath -Credential $labcreds -SkipCertificateCheck:$SkipCertificateCheck
									Write-Host ("Upload Complete.")
									}
								Else 
									{
									Write-Host ("File not found: " + $MissingFile)
									Throw
									}
								}
							}
						}
					}
					$ContentLibraryUpdateSession.complete($newSessionId)
					Write-Host $ContentLibraryUpdateSession.get($newSessionId).State
				}
			}
		}
	}
