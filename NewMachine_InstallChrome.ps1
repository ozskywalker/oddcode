Import-Module BitsTransfer; 
Start-BitsTransfer 'http://dl.google.com/chrome/install/149.27/chrome_installer.exe' 'chrome_installer.exe'
& ".\chrome_installer.exe"
