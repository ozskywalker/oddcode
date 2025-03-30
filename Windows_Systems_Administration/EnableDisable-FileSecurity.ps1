 #Disable File Security  
 $env:SEE_MASK_NOZONECHECKS = 1  
 
 #Enable File Security  
 Remove-Item env:\SEE_MASK_NOZONECHECKS  
