# DEFINE DIRECTORY TO SCAN BELOW:
directory="/HOME/TEST/EXAMPLEDIR"

# Define the target date
target_date="2024-03-23"

# Convert the target date to seconds since 1970-01-01 00:00:00 UTC
target_date_seconds=$(date -d "$target_date" +%s)



# Loop through files and folders in the directory
find "$directory" -type f -printf '%T@ %p\n' | while read -r file_date file_path
do
    # Convert the file date to seconds since 1970-01-01 00:00:00 UTC
    file_date_seconds=$(date -d "@$(echo $file_date | cut -d'.' -f1)" +%s)

    # If the file date is before the target date, delete the file
    if (( file_date_seconds < target_date_seconds )); then
        echo "Deleting $file_path"
        rm -rf "$file_path"
    fi
done