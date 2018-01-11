Import-Module BitsTransfer; 
Start-BitsTransfer 'http://dl.google.com/chrome/install/chrome_installer.exe' 'chrome_installer.exe'
& ".\chrome_installer.exe"
