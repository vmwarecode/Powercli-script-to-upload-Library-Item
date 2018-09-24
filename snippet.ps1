Function Add-LibraryItem {
<#
	.NOTES :
	--------------------------------------------------------
	 Created by	: LOKESH HK
	 Organisation	: VMWARE
         e-mail         : lhulibelekemp@vmware.com
	--------------------------------------------------------
	.DESCRIPTION
		This function uploads item to the Content library from URL location.
	.PARAMETER  LibraryName
		Name of the libray to which item needs to be uploaded.
	.PARAMETER	LibType
		Name of the file type. (File extension name)
	.PARAMETER	LibItemName
		Name of the library item.
	.PARAMETER	LibItemURLPath
		URL location of the file.
	.EXAMPlE
		Add-LibraryItem -LibraryName 'LibraryName' -LibType 'ova' -LibItemName 'LibItemName' -LibItemURLPath $URL
		Add-LibraryItem -LibraryName 'LibraryName' -LibType 'vmdk' -LibItemName 'LibItemName' -LibItemURLPath $URL
		Add-LibraryItem -LibraryName 'LibraryName' -LibType 'ovf' -LibItemName 'LibItemName' -LibItemURLPath $URL
	
#>
	param(
		[Parameter(Mandatory=$true)][string]$LibraryName,
		[Parameter(Mandatory=$true)][string]$LibType,
		[Parameter(Mandatory=$true)][string]$LibItemName,
		[Parameter(Mandatory=$true)][string]$LibItemURLPath
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
		write-host -ForegroundColor red $LibraryName " -- is not exists.."
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
			$ConentLibraryUpdateSession = Get-CisService "com.vmware.content.library.item.update_session"
			$SessionState = "ACTIVE"
			$createSessionSpec = $ConentLibraryUpdateSession.Help.create.create_spec.Create()
			$createSessionSpec.state = $SessionState
			$createSessionSpec.library_item_id = $libraryItemId
	
			write-host " Creating new Session ID " 
			$newSessionId = $ConentLibraryUpdateSession.create($UniqueChangeId,$createSessionSpec)
			write-host " New Session ID is created -- " $newSessionId
			
			if(!$newSessionId){
				write-host -ForegroundColor red " Failed to create Session ID"
			} else {
				$ConentLibraryUpdateItem = Get-Cisservice "com.vmware.content.library.item.updatesession.file"
				$createFileSpec = $ConentLibraryUpdateItem.Help.add.file_spec.Create()
				$LibItemName = $LibItemName+'.'+$LibType
				$createFileSpec.name = $LibItemName
				$createFileSpec.source_type = "PULL"
				$createFileSpec.source_endpoint.uri = $LibItemURLPath
				$ConentLibraryUpdateItem.add($newSessionId,$createFileSpec)
				$ConentLibraryUpdateSession.complete($newSessionId)
				write-host "File upload session is intiated"
			}
		}
	}
}