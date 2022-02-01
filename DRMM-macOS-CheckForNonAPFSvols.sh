#!/bin/sh
COUNT=`diskutil list | grep ":" |grep -v "/dev/" | grep -v "#:" | grep -v "EFI" | grep -v "APFS" | grep -v "GUID_partition_scheme" | wc -l`

if [ "$COUNT" -gt 0 ]; then
    RESULT="Found 1 or more"
else
    RESULT="OK"
fi

echo "<-Start Result->"
echo "NONAPFS=$RESULT"
echo "<-End Result->"

echo "<-Start Diagnostic->"
diskutil list
echo "<-End Diagnostic->"

exit $COUNT