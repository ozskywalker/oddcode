$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()
$HistoryCount = $Searcher.GetTotalHistoryCount()
$Updates = $Searcher.QueryHistory(0,$HistoryCount)
$Updates | Select Title,@{l='Name';e={$($_.Categories).Name}},Date,
    @{name="Operation"; expression={switch($_.operation)
    {
        1 {"Installation"};
        2 {"Uninstallation"};
        3 {"Other"}
    }}},
    @{name="Status"; expression={switch($_.resultcode)
    {
        1 {"In Progress"};
        2 {"Succeeded"};
        3 {"Succeeded With Errors"};
        4 {"Failed"};
        5 {"Aborted"}
    }}} | Format-Table
    
# optionally - consider piping to Out-GridView / ogv