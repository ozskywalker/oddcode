# from http://www.veeam.com/kb1940
# workaround for bug http://kb.vmware.com/kb/2090639
#

# Get the VMs with CBT enabled:
$vms=get-vm | ?{$_.ExtensionData.Config.ChangeTrackingEnabled -eq $true}

# Create a VM Specification to apply with the desired setting:
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
$spec.ChangeTrackingEnabled = $false

# Apply the specification to each VM, then create and remove a snapshot:
foreach($vm in $vms){ 
$vm.ExtensionData.ReconfigVM($spec) 
$snap=$vm | New-Snapshot -Name 'Disable CBT' 
$snap | Remove-Snapshot -confirm:$false}

# Check for success:
get-vm | ?{$_.ExtensionData.Config.ChangeTrackingEnabled -eq $true}