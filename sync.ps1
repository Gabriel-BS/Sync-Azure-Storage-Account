param(
    [Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$false)]
    [System.String]
    $SourceStorageAccount,

    [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$false)]
    [System.String]
    $SourceStorageKey

    [Parameter(Mandatory=$True, Position=2, ValueFromPipeline=$false)]
    [System.String]
    $DestStorageAccount,

    [Parameter(Mandatory=$True, Position=3, ValueFromPipeline=$false)]
    [System.String]
    $DestStorageKey
)

$SourceStorageContext = New-AzureStorageContext -StorageAccountName $SourceStorageAccount -StorageAccountKey $SourceStorageKey
$DestStorageContext = New-AzureStorageContext -StorageAccountName $DestStorageAccount -StorageAccountKey $DestStorageKey

$Containers = Get-AzureStorageContainer -Context $SourceStorageContext


foreach($Container in $Containers)
{
    if(($Container.name -eq '$web') -or ($Container.name -eq '$logs')){
        $ContainerName = ""
    } else {
        $ContainerName = $Container.Name
    }


    if (!((Get-AzureStorageContainer -Context $DestStorageContext) | Where-Object { $_.Name -eq $ContainerName }))
    {   
        Write-Output "Creating new container $ContainerName"
        New-AzureStorageContainer -Name $ContainerName -Permission Off -Context $DestStorageContext -ErrorAction Stop
    }

    $Blobs = Get-AzureStorageBlob -Context $SourceStorageContext -Container $ContainerName
    $BlobCpyAry = @() #Create array of objects

    #Do the copy of everything
    foreach ($Blob in $Blobs)
    {
       $BlobName = $Blob.Name
       Write-Output "Copying $BlobName from $ContainerName"
       $BlobCopy = Start-CopyAzureStorageBlob -Context $SourceStorageContext -SrcContainer $ContainerName -SrcBlob $BlobName -DestContext $DestStorageContext -DestContainer $ContainerName -DestBlob $BlobName
       $BlobCpyAry += $BlobCopy
    }

    #Check Status
    foreach ($BlobCopy in $BlobCpyAry)
    {
       #Could ignore all rest and just run $BlobCopy | Get-AzureStorageBlobCopyState but I prefer output with % copied
       $CopyState = $BlobCopy | Get-AzureStorageBlobCopyState
       $Message = $CopyState.Source.AbsolutePath + " " + $CopyState.Status + " {0:N2}%" -f (($CopyState.BytesCopied/$CopyState.TotalBytes)*100) 
       Write-Output $Message
    }
}