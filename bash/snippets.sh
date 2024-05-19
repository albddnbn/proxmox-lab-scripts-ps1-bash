## backup all files in directory, add .bak extension
for file in *; do cp $file $file.bak; done