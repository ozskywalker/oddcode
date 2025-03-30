# Check if the SqlServer module is available; if not, install it
if (!(Get-Module -ListAvailable -Name SQLPS)) {
    Write-Output "SqlServer SQLPS module not found. Installing..."
    try {
        Install-Module -Name SQLPS -Force -Scope CurrentUser
        Write-Output "SqlServer SQLPS module installed successfully."
    } catch {
        Write-Output "Error installing SqlServer SQLPS module. Ensure you have PowerShellGet installed and are connected to the internet."
        exit
    }
} else {
    Write-Output "SqlServer module found."
}

# Import the SqlServer module
Import-Module SQLPS -ErrorAction Stop
Write-Output "SqlServer SQLPS module imported successfully."

# Set up SQL Server connection variables
$serverInstance = "localhost\SQLEXPRESS" # Replace with your SQL Server instance
$databaseName = "AdventureWorks2022"
$connectionString = "Server=$serverInstance;Database=$databaseName;Integrated Security=True;"

# Define a function to run SQL commands
function Execute-SQLCommand {
    param (
        [string]$command
    )
    Invoke-Sqlcmd -Query $command -ConnectionString $connectionString
}

# Function to generate random data for SQL injection
function Generate-RandomData {
    # Generate realistic random values for testing
    $CustomerID = Get-Random -Minimum 29000 -Maximum 30000
    $SalesPersonID = Get-Random -Minimum 274 -Maximum 290
    $TerritoryID = Get-Random -Minimum 1 -Maximum 10
    $BillToAddressID = Get-Random -Minimum 900 -Maximum 1000
    $ShipToAddressID = $BillToAddressID  # Use the same for simplicity
    $ShipMethodID = Get-Random -Minimum 1 -Maximum 5  # Only 5 methods in ShipMethod
    $SubTotal = [math]::Round((Get-Random -Minimum 50 -Maximum 500), 2)
    $TaxAmt = [math]::Round($SubTotal * 0.08, 2)
    $Freight = [math]::Round($SubTotal * 0.05, 2)
    #$SpecialOfferID = Get-Random -Minimum 1 -Maximum 16
    $SpecialOfferID = 1
    $Comment = "Random Order - $(Get-Random -Minimum 1 -Maximum 1000)"
    $UnitPrice = [math]::Round((Get-Random -Minimum 10 -Maximum 100), 2)

    # Return a hashtable of generated values
    return @{
        CustomerID = $CustomerID
        SalesPersonID = $SalesPersonID
        TerritoryID = $TerritoryID
        BillToAddressID = $BillToAddressID
        ShipToAddressID = $ShipToAddressID
        ShipMethodID = $ShipMethodID
        SubTotal = $SubTotal
        TaxAmt = $TaxAmt
        Freight = $Freight
        SpecialOfferID = $SpecialOfferID
        Comment = $Comment
        UnitPrice = $UnitPrice
    }
}

# Generate random data for insertion
$data = Generate-RandomData
$dueDate = (Get-Date).AddDays((Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd")  # Set a DueDate 1-30 days in the future

# Insert sample data into Sales.SalesOrderHeader and Sales.SalesOrderDetail tables
$sqlInsert = @"
BEGIN TRANSACTION;
INSERT INTO Sales.SalesOrderHeader (CustomerID, SalesPersonID, TerritoryID, BillToAddressID, ShipToAddressID, ShipMethodID, SubTotal, TaxAmt, Freight, Comment, OrderDate, DueDate)
VALUES ($($data.CustomerID), $($data.SalesPersonID), $($data.TerritoryID), $($data.BillToAddressID), $($data.ShipToAddressID), $($data.ShipMethodID), $($data.SubTotal), $($data.TaxAmt), $($data.Freight), '$($data.Comment)', GETDATE(), '$dueDate');
DECLARE @OrderID INT = SCOPE_IDENTITY();
INSERT INTO Sales.SalesOrderDetail (SalesOrderID, OrderQty, ProductID, UnitPrice, SpecialOfferID, UnitPriceDiscount)
VALUES (@OrderID, 2, 776, $($data.UnitPrice), $($data.SpecialOfferID), 0.00);
COMMIT;
"@

Execute-SQLCommand -command $sqlInsert
Write-Output "Sample data with random values inserted."

# Generate random data for update
$dataUpdate = Generate-RandomData

# Update records with random data to create changes in transaction logs
$sqlUpdate = @"
BEGIN TRANSACTION;
UPDATE Sales.SalesOrderDetail
SET UnitPrice = $($dataUpdate.UnitPrice)
WHERE SalesOrderDetailID IN (SELECT TOP 5 SalesOrderDetailID FROM Sales.SalesOrderDetail ORDER BY NEWID());
COMMIT;
"@

Execute-SQLCommand -command $sqlUpdate
Write-Output "Randomized records updated."

# Delete a small number of records to add more log activity
$sqlDelete = @"
BEGIN TRANSACTION;
DELETE FROM Sales.SalesOrderDetail
WHERE SalesOrderDetailID IN (SELECT TOP 10 SalesOrderDetailID FROM Sales.SalesOrderDetail ORDER BY SalesOrderDetailID DESC);
COMMIT;
"@

Execute-SQLCommand -command $sqlDelete
Write-Output "Records deleted."

# Insert additional small changes in a loop with random data
for ($i = 1; $i -le 5; $i++) {
    $dataLoop = Generate-RandomData
    $loopDueDate = (Get-Date).AddDays((Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd")  # Set a DueDate 1-30 days in the future
    $sqlLoopInsert = @"
BEGIN TRANSACTION;
INSERT INTO Sales.SalesOrderHeader (CustomerID, SalesPersonID, TerritoryID, BillToAddressID, ShipToAddressID, ShipMethodID, SubTotal, TaxAmt, Freight, Comment, OrderDate, DueDate)
VALUES ($($dataLoop.CustomerID), $($dataLoop.SalesPersonID), $($dataLoop.TerritoryID), $($dataLoop.BillToAddressID), $($dataLoop.ShipToAddressID), $($dataLoop.ShipMethodID), $($dataLoop.SubTotal), $($dataLoop.TaxAmt), $($dataLoop.Freight), '$($dataLoop.Comment)', GETDATE(), '$loopDueDate');
COMMIT;
"@

    Execute-SQLCommand -command $sqlLoopInsert
    Start-Sleep -Seconds 1 # Add a small delay between transactions
    Write-Output "Loop Insert $i with random values completed."
}

Write-Output "Transaction log activity with randomized data generated successfully."
