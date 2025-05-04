quser | ForEach-Object -Process { $_ -replace '\s{2,}',',' } | convertfrom-csv
