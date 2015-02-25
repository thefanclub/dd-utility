#!/bin/bash
#
# dd Utility version 1.0
#
# By The Fan Club 2015
# http://www.thefanclub.co.za
#
### BEGIN LICENSE
# Copyright (c) 2015, The Fan Club <info@thefanclub.co.za>
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranties of
# MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
### END LICENSE

# Vars
apptitle="dd Utility"
version="1.0 beta"

# Set Icon directory and file 
iconfile="/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Removable.icns"

# Select Backup or Restore
response=$(osascript -e 'tell app "System Events" to display dialog "Select Backup to create an image file from a memory card or disk.\n\nSelect Restore to copy an image file to a memory card or disk. Supported formats: \nimg, zip, gzip, xz\n\nSelect Cancel to Quit" buttons {"Cancel", "Backup", "Restore"} default button 3 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'"  ')

action=$(echo $response | cut -d ':' -f2)

# Exit if Canceled
if [ ! "$action" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
  exit 0
fi

### BACKUP : Select inputfile and outputfile
if [ "$action" == "Backup" ] ; then

  # Get input folder of memcard disk - NOTE funny quotes ` not '
  memcardpath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set folderpath to choose folder default location "/Volumes" with prompt "Select your memory card location"
    end tell 
    return (posix path of folderpath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$memcardpath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
    exit 0
  fi

  # Get output folder for backup image
  imagepath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set folderpath to choose folder default location (path to desktop folder) with prompt "Select backup folder for memory card image file"
    end tell 
    return (posix path of folderpath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$imagepath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
    exit 0
  fi

  # Get filename for for backup image
  response=$(osascript -e 'tell app "System Events" to display dialog "Please enter filename for disk image:" default answer "imagefile" with title "'"$apptitle"' '"$version"'" ' )
  getfilename=$( echo $response | cut -d "," -f2 | cut -d ":" -f2 )
  # Strip path if given
  filename=$(basename "$getfilename")

  # Cancel is user selects Cancel
  if [ ! "$response" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
    exit 0
  fi

  # Ask for compression
  response=$(osascript -e 'tell app "System Events" to display dialog "Compress the Backup image file? \n\nThis can significantly reduce the space used by the backup.\n\nSelect Cancel to Quit" buttons {"No", "Yes"} default button 2 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'"  ')

  compression=$(echo $response | cut -d ':' -f2)

  # Parse vars for dd
  outputfile="$imagepath$filename.img"
  if [ "$compression" == "Yes" ] ; then
    outputfile="$outputfile.zip"
  fi

  # Check if image file exists
  if [ -f "$outputfile" ] ; then
    response=$(osascript -e 'tell app "System Events" to display dialog "The file '"$outputfile"' already exist.\n\nSelect Continue to overwrite the file.\n\nSelect Cancel to Quit" buttons {"Cancel", "Continue"} default button 2 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'"  ')
    
    # Cancel is user selects Cancel
    if [ ! "$response" ] ; then
      osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
      exit 0
    fi

    # Delete the file if exists
    rm $outputfile
  fi

fi


### RESTORE : Select image file and memcard location
if [ "$action" == "Restore" ] ; then

  # Get image file location
  imagepath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set imagefilepath to choose file of type {"img", "gz", "zip", "xz"} default location (path to desktop folder) with prompt "Select image file to restore to memory card or disk. Supported file formats : IMG, ZIP, GZ, XZ"
    end tell 
    return (posix path of imagefilepath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$imagepath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
    exit 0
  fi

  # Get input folder of memcard disk - NOTE funny quotes ` not '
  memcardpath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set folderpath to choose folder default location "/Volumes" with prompt "Select your memory card location"
    end tell 
    return (posix path of folderpath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$memcardpath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
    exit 0
  fi

  # Parse vars for dd
  inputfile=$imagepath

  # Check if Compressed from extension
  extension="${inputfile##*.}"
  if [ "$extension" == "gz" ] || [ "$extension" == "zip" ] || [ "$extension" == "xz" ]; then
    compression="Yes"
  else
    compression="No"
  fi

fi

# Parse memcard disk volume Goodies
memcard=$( echo $memcardpath | awk -F '\/Volumes\/' '{print $2}' | cut -d '/' -f1 )
disknum=$( diskutil list | grep "$memcard" | awk -F 'disk' '{print $2}' | cut -d 's' -f1 )
devdisk="/dev/disk$disknum"
# use rdisk for faster copy
devdiskr="/dev/rdisk$disknum"
# Get Drive size
drivesize=$( diskutil list | grep "disk$disknum" | grep "0\:" | cut -d "*" -f2 | awk '{print $1 " " $2}' )

# Set output option
if [ "$action" == "Backup" ] ; then
  inputfile=$devdiskr
  source="$drivesize $memcard (disk$disknum)"
  dest=$outputfile
  check=$dest
fi
if [ "$action" == "Restore" ] ; then
  source=$inputfile
  dest="$drivesize $memcard (disk$disknum)"
  outputfile=$devdiskr
  check=$source
fi

# Confirmation Dialog
response=$(osascript -e 'tell app "System Events" to display dialog "Please confirm settings and click Start\n\nSource: \n'"$source"' \n\nDestination: \n'"$dest"' \n\n\nNOTE: All Data on the Destination will be deleted and overwritten" buttons {"Cancel", "Start"} default button 2 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'" ')
answer=$(echo $response | grep "Start")

# Cancel is user does not select Start
if [ ! "$answer" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Program cancelled"'
  exit 0
fi

# Unmount Volume
response=$(diskutil unmountDisk $devdisk)
answer=$(echo $response | grep "successful")

# Cancel if unable to unmount
if [ ! "$answer" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Cannot Unmount '"$memcard"'"'
  exit 0
fi

# Start dd copy
## Todo - delete image file if it exists already

osascript -e 'display notification "Please be patient...." with title "'"$apptitle"'" subtitle "'"$drivesize"' Disk '$action' Started"'

if [ "$compression" == "No" ] ; then
  osascript -e 'do shell script "dd if=\"'"$inputfile"'\" of=\"'"$outputfile"'\" bs=1m" with administrator privileges'
fi

# Compression Backup and Restore
if [ "$compression" == "Yes" ] ; then
  # Compressed Backup to ZIP file
  if [ "$action" == "Backup" ] ; then
    osascript -e 'do shell script "dd if=\"'"$inputfile"'\" bs=1m | zip > \"'"$outputfile"'\"" with administrator privileges'
  fi

  # Compressed Restore
  if [ "$action" == "Restore" ] ; then
    # GZ files
    if [ "$extension" == "gz" ] ; then
      osascript -e 'do shell script "gzip -dc \"'"$inputfile"'\" | dd of=\"'"$outputfile"'\" bs=1m" with administrator privileges'
    fi
    # ZIP files
    if [ "$extension" == "zip" ] ; then
      osascript -e 'do shell script "unzip -p \"'"$inputfile"'\" | dd of=\"'"$outputfile"'\" bs=1m" with administrator privileges'
    fi
    # XZ files - OSX 10.10 only I think 
    if [ "$extension" == "xz" ] ; then
      osascript -e 'do shell script "tar -xJOf \"'"$inputfile"'\" | dd of=\"'"$outputfile"'\" bs=1m" with administrator privileges'
    fi
  fi
fi

# Copy Complete
# Check filesize the OSX way 1Kb = 1000 bytes
filesize=$(stat -f%z "$check")

if [ "$filesize" -gt 1000000000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000000000" | bc ) TB" 
elif [ "$filesize" -gt 1000000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000000" | bc ) GB" 
elif [ "$filesize" -gt 1000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000" | bc ) MB" 
elif [ "$filesize" -gt 1000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000" | bc ) KB" 
fi

# Get Filename for display
fname=$(basename "$check")

# Display Notifications

osascript -e 'display notification "'"$drivesize"' Drive '$action' Complete " with title "'"$apptitle"'" subtitle " '"$fname"' "'

response=$(osascript -e 'tell app "System Events" to display dialog "'"$drivesize"' Disk '$action' Complete\n\nFile '"$fname"'\n\nSize '"$fsize"' " buttons {"Done"} default button 1 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'" ')

exit 0
# END