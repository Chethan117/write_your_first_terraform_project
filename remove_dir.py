import os
import shutil

main_folder = r"path/to/main_folder"

# Function to delete a file or folder with force removal
def force_remove(path):
    try:
        if os.path.isfile(path):
            os.remove(path)
        else:
            shutil.rmtree(path, ignore_errors=True)
    except (OSError, PermissionError):
        pass

# Recursive function to remove empty directories
def remove_empty_directories(folder_path):
    for item in os.listdir(folder_path):
        item_path = os.path.join(folder_path, item)
        if os.path.isdir(item_path):
            remove_empty_directories(item_path)
            if not os.listdir(item_path):
                force_remove(item_path)

# Start the directory traversal
remove_empty_directories(main_folder)

# Remove the main_folder if it's empty
if not os.listdir(main_folder):
    force_remove(main_folder)
