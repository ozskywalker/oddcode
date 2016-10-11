#PowerShell implementation based on c# example found here:
#https://gist.github.com/j3tm0t0/2024833

Import-Module AWSPowershell

Function Create-AwsRoute53Record
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param (
                [String]$AccessKeyID="xxx",
         [String]$SecretAccessKeyID="xxx",
                [String]$Region="us-east-1",
                [Parameter(Mandatory=$true)] $Zone,
               [ValidateSet("A", "SOA", "PTR", "MX", "CNAME","TXT","SRV","SPF","AAAA","NS")]
                [String]$RecordType,
               [Parameter(Mandatory=$true)]
                [String]$Name,
              [Parameter(Mandatory=$true)]$Value,
               $TTL,
               $wait = $false,
              [int]$waitinterval = 1000

        )
    
    Process
    {
     Set-AWSCredentials -AccessKey $AccessKeyID  -SecretKey $SecretAccessKeyID
    Set-DefaultAWSRegion -Region $region
    $zoneEntry = (Get-R53HostedZones) | ? {$_.Name -eq "$($Zone)."}
  
  $hostedZone = $zoneEntry.Id
        if (@($zoneEntry).count -eq 1) {
                $Record = new-object Amazon.Route53.Model.ResourceRecord
                $record.Value = $Value
                 #add the trailing dot
        if (!($Name.EndsWith(".")) -and $Name)
            {$Name += "."}

        $ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
        $ResourceRecordSet.Type = $RecordType
        $ResourceRecordSet.ResourceRecords = $Record
        $ResourceRecordSet.Name = $Name
        $ResourceRecordSet.TTL = $TTL


        $change = New-Object Amazon.Route53.Model.Change
        $change.Action = "Upsert"
        $change.ResourceRecordSet = $ResourceRecordSet
      
        $Changes = (New-Object -TypeName System.Collections.ArrayList($null))
        $Changes.Add($Change)

        Try
        {
            $result = Edit-R53ResourceRecordSet -ChangeBatch_Changes $Changes -HostedZoneId $hostedZone
          
        }
        Catch [system.Exception]
        {
            Write-error $error[0]
        }
      
        if ($result)
        {
            if ($wait)
            {
            #Keep polling the result until it is no longer pending
            Do
                {
                    #get change status
                    if ($SecondPoll)
                        {Start-Sleep -Milliseconds $waitinterval}
                   $status=Get-R53Change -Id $result.Id
                    $SecondPoll = $true
                    Write-verbose "Waiting for changes to sync. Current status is $($status.Status.Value)"
                }
            Until ($status.Status.Value -eq "INSYNC")

      
            }
      
            $Status
        }
     } 
  }
}

$PublicFQDN = $(Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/public-hostname -Method Get).Trim()
Create-AwsRoute53Record -Zone lwalker.me -RecordType CNAME -Name "pm-awsshowcase-ma1.lwalker.me" -Value $PublicFQDN -TTL 15 -wait $True