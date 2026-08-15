$ErrorActionPreference = 'Stop'

. (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'tomcat.common.ps1')

function global:au_GetLatest { Get-TomcatLatest -MajorVersion 11 -NoX86 }

function global:au_BeforeUpdate {
    Get-RemoteFiles -Purge -NoSuffix -Algorithm sha512
    Test-TomcatChecksums
}

function global:au_SearchReplace { Get-TomcatSearchReplace }

Update-Package -ChecksumFor none
