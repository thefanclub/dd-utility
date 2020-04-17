#!/bin/bash
#
# dd Utility version 1.6 - Linux/Ubuntu 
#
# Write and Backup Operating System IMG and ISO files on Memory Card or Disk
#
# By The Fan Club 2020
# http://www.thefanclub.co.za
#
### BEGIN LICENSE
# Copyright (c) 2020, The Fan Club <info@thefanclub.co.za>
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
#
### NOTES 
#
# Dependencies : zenity zip xz gzip tar dd udevil
#
# To run script make executable with: sudo chmod +x ddutility.sh
# and then run with: sudo ddutility.sh
#
###

# Vars
apptitle="dd Utility"
version="1.6 beta"
export LC_ALL=en_US.UTF-8
mountpath="/media/$SUDO_USER"

# Set Icon directory and file 
iconfile="notification-device"

# Read args
if [ "$1" == "--Backup" ] ; then
  action="Backup"
fi
if [ "$1" == "--Restore" ] ; then
  action="Restore"
fi

# Check if Disk Dev was dropped
if [ "$(dirname "$1")" == "$mountpath" ] ; then
   memcard=$( df | grep "$mountpath" | awk {'print $1'} | grep "\/dev\/" )
   if [ "$memcard" ] ; then
    # Get dev names of drive - remove numbers
    devdisk=$(echo $memcard | sed 's/[0-9]*//g')
    action="Backup"
   fi
fi

# Check if Restore file was dropped
if [ -f "$1" ] ; then
  # Check extension if file
  extension=$( echo "${1##*.}" | tr '[:upper:]' '[:lower:]' )
  case "$extension" in
    img|iso|zip|gz|xz)
      action="Restore"
      imagepath=$1
      ;;
  esac
fi

# Filesize conversion function
function filesizehuman () {
  filesize=$1
  if [ "$filesize" -gt 1000000000000 ] ; then
    fsize="$( echo "scale=1; $filesize/1000000000000" | bc ) TB" 
  elif [ "$filesize" -gt 1000000000 ] ; then
    fsize="$( echo "scale=1; $filesize/1000000000" | bc ) GB" 
  elif [ "$filesize" -gt 1000000 ] ; then
    fsize="$( echo "scale=1; $filesize/1000000" | bc ) MB" 
  elif [ "$filesize" -gt 1000 ] ; then
    fsize="$( echo "scale=1; $filesize/1000" | bc ) KB" 
  fi
  echo $fsize
}

# Calculate progress in percentage for progress bar
function progressmonitor () {
  echo "# $progresstext"
  processactive=$( ps -p $pid -o pid= )
  # While process running show progress
  while [ $processactive ] ; do
    # Backup Progress
    if [ "$action" == "Backup" ] ; then
      # img
      if [ "$compression" == "No" ] ; then
        # Calc progress with size of output file and disk dev size
        outputfilesize=$( du -b "$outputfile" | awk {'print $1'} )
      fi
      # zip
      if [ "$compression" == "Yes" ] ; then
        # Calc progress for compressed backup using read offset on disk device and total size of disk
        outputfilesize=$( lsof -o0 -o -e /run/user/"$(ls /run/user | xargs)"/gvfs 2>/dev/null | grep "$inputfile" | awk {'print $7'} | cut -d 't' -f2 )         
      fi      
    fi
    
    # Restore Progress
    if [ "$action" == "Restore" ] ; then
        # Calc progress by using offset bytes on disk device and uncompressed size pf restore file
        outputfilesize=$( lsof -o0 -o -p $pid -e /run/user/"$(ls /run/user | xargs)"/gvfs 2>/dev/null | grep "$outputfile" | awk {'print $7'} | cut -d 't' -f2 )
    fi
       
    # Calc percentage of progress
    if [ "$outputfilesize" ] ; then
      percentage=$(printf "%.0f" $( echo "scale=2; ($outputfilesize/$totalbytes)*100" | bc 2>/dev/null))  
    fi
    
    # Wait for buffer to finish 
    if [ ! "$outputfilesize" ] && [ "$percentage" -gt 90 ] ; then
      echo "# $action almost done..."
    fi
    
    # Update progress bar
    echo "$percentage"
    sleep 1
    
    # Check if process still active
    processactive=$( ps -p $pid -o pid= )
  done
  echo "# $action Complete"
  echo "$percentage"
}

# Select Disk Volume Dialog
function getdevdisk () {
  # Check for mounted devices in user media folder
  # Parse memcard disk volume Goodies and get mounted device excluding /dev/sr 
  memcard=$( df | grep "$mountpath" | awk {'print $1'} |  grep -v "\/dev\/sr" | grep "\/dev\/" )
  # Get dev names of drive - remove numbers
  checkdev=$(echo $memcard | sed 's/[0-9]*//g')
  # Remove duplicate dev names
  devdisks=$(echo $checkdev | xargs -n1 | sort -u | xargs )
  # How many devs found
  countdev=$( echo $devdisks | wc -w )
  # Retry detection if no memcards found
  while [ $countdev -eq 0 ] ; do
    notify-send --icon=$iconfile "$apptitle" "No Volumes Detected"
    # Ask for redetect
    zenity --question  --no-wrap --title="$apptitle - $action" --text="<big><b>No Volumes Detected</b></big> \n\nInsert a memory card or removable storage and click Retry.\n\nSelect Cancel to Quit" --ok-label=Retry --cancel-label=Cancel 
    if [ ! $? -eq 0 ] ; then
      exit 1
    fi
    # Do Re-Detection of Devices
    # Parse memcard disk volume Goodies
    memcard=$( df | grep "$mountpath" | awk {'print $1'} |  grep -v "\/dev\/sr" | grep "\/dev\/" )
    # Get dev names of drive - remove numbers
    checkdev=$(echo $memcard | sed 's/[0-9]*//g')
    # Remove duplicate dev names
    devdisks=$(echo $checkdev | xargs -n1 | sort -u | xargs )
    # How many devs found
    countdev=$( echo $devdisks | wc -w )
  done

  # Generate Zenity Dialog 
  devdisk=$(
  (
  # Generate list for Zenity
  for (( c=1; c<=$countdev; c++ ))
    do
      devitem=$( echo $devdisks | awk -v c=$c '{print $c}')
      drivesize=$( fdisk -l | grep "Disk\ $devitem\:" | cut -d "," -f2 | awk {'print $1'} | xargs )
      drivesizehuman=$( filesizehuman $drivesize ) 
      devicevendor=$(udevil --show-info $devitem | grep "vendor" | cut -d ":" -f2 | xargs)
      devicemodel=$(udevil --show-info $devitem | grep "model" | cut -d ":" -f2 | xargs)
      # echo output for zenity columns
      echo "$drivesizehuman" ; echo "$devicevendor $devicemodel   " ; echo "$(basename $devitem)" 
  done

  ) | zenity --list --title="$apptitle - $action : Select memory card" \
   --column="Volume" --column="Description" --column="Device" --print-column=3 --ok-label=Continue --width=400 --height=200 )
 
  # Return value if selected
  if [ $devdisk ] ; then
    echo "/dev/$devdisk"
  fi
}

# Select Backup or Restore if not in args
if [ ! "$action" ] ; then
  response=$(zenity --question --no-wrap --text "\n<big>Select <b>Backup</b> to create an image file from a memory card or disk.\n\n\nSelect <b>Restore</b> to copy an image file to a memory card or disk.</big>\nSupported formats: img, iso, zip, gzip, xz\n\n\n\nWARNING - Use this program with caution. Data could be lost." --title "$apptitle $version" --ok-label=Restore --cancel-label=Backup  )

  if [ $? -eq 0 ] ; then
    action="Restore"
  else
    action="Backup"
  fi
fi

### BACKUP : Select inputfile and outputfile
if [ "$action" == "Backup" ] ; then
  
  # Check if volume was dropped already
  if [ ! "$devdisk" ] ; then
    # Select Disk Volume
    devdisk=$( getdevdisk )
  fi
   
  # Cancel if user selects Cancel
  if [ ! "$devdisk" ] ; then
    notify-send --icon=$iconfile "$apptitle" "No Volumes Selected. $action Cancelled. "
    exit 0
  fi

  # Get output filename and folder for backup image
  imagepath=$(zenity --file-selection --filename=/home/$SUDO_USER/Desktop/ --save --confirm-overwrite --title="$apptitle - $action : Select the filename and folder for memory card image file" --file-filter="*.img *.IMG *.gz *.GZ" )
 
  # Cancel if user selects Cancel
  if [ ! $? -eq 0 ] ; then
    echo "$action Cancelled"
    exit 0
  fi

  # Get filename for for backup image and Strip path if given
  filename=$(basename "$imagepath")

  # check if compression implied in filename extension
  extension=$( echo "${filename##*.}" | tr '[:upper:]' '[:lower:]' )
  # Check if extension is already zip
  if [ "$extension" == "gz" ] ; then
     compression="Yes"
  else
    # Ask for compression if not a zip file
    zenity --question --no-wrap --title="$apptitle - $action" --text="<big><b>Compress the Backup image file?</b></big> \n\nThis can significantly reduce the space used by the backup." --ok-label=Yes --cancel-label=No --width=400 

    if [ $? -eq 0 ] ; then
      compression="Yes"
    else
      compression="No"
    fi
  fi

  # Parse vars for dd
  outputfile="$imagepath"
  # Add img extension if missing
  if [ "$extension" != "gz" ] && [ "$extension" != "img" ] ; then
    outputfile="$outputfile.img"
  fi
  # Add zip for compressed backup
  if [ "$compression" == "Yes" ] && [ "$extension" != "gz" ] ; then    
    outputfile="$outputfile.gz"
  fi

  # Check if image file exists again
  if [ -f "$outputfile" ] && [ "$imagepath" != "$outputfile" ] ; then
    zenity --question --no-wrap --title="$apptitle - $action" --text="<big><b>The file $(basename $outputfile) already exist.</b></big>\n\nSelect <b>Continue</b> to overwrite the file.\n\nSelect <b>Cancel</b> to Quit" --ok-label=Continue --cancel-label=Cancel --width=500 
    
    # Cancel if user selects Cancel
    if [ ! $? -eq 0 ] ; then
      echo "$action Cancelled"
      exit 0
    fi

    # Delete the file if exists
    rm $outputfile
  fi

fi


### RESTORE : Select image file and memcard location
if [ "$action" == "Restore" ] ; then

  # Check if restore file was dropped as arg already
  if [ ! "$imagepath" ] ; then
    # Get image file location
    imagepath=$(zenity --file-selection --filename=/home/$SUDO_USER/ --title="$apptitle - $action : Select image file to restore to memory card. Supported files : IMG, ISO, ZIP, GZ, XZ" --file-filter="*.img *.IMG *.iso *.ISO *.gz *.GZ *.xz *.XZ *.zip *.ZIP")
 
    # Cancel if user selects Cancel
    if [ ! $? -eq 0 ] ; then
      echo "$action Cancelled"
      exit 0
    fi
  fi
  
  # Get memcard device name
  devdisk=$( getdevdisk )
   
  # Cancel if user selects Cancel
    if [ ! $devdisk ] ; then
      echo "No Volumes Selected. $action Cancelled. "
      exit 0
    fi

  # Parse vars for dd
  inputfile="$imagepath"

  # Check if Compressed from extension
  extension=$( echo "${inputfile##*.}" | tr '[:upper:]' '[:lower:]' )
  if [ "$extension" == "gz" ] || [ "$extension" == "zip" ] || [ "$extension" == "xz" ]; then
    compression="Yes"
  else
    compression="No"
  fi

fi

# Get Drive size in bytes and human readable
drivesize=$( fdisk -l | grep "Disk\ $devdisk\:" | cut -d "," -f2 | awk {'print $1'} | xargs )
drivesizehuman=$( filesizehuman $drivesize )

# Set output option
if [ "$action" == "Backup" ] ; then
  inputfile=$devdisk
  source="<big><b>$drivesizehuman Volume</b></big>"
  dest="<big><b>$(basename "$outputfile")</b></big>"
  totalbytes=$drivesize
  # Check available space left for backup
  outputspace=$( df $(dirname "$outputfile") | grep "\/dev\/" | awk {'print $4'} )
  # Output of df is in 1024 K blocks 
  outputspace=$(( $outputspace * 1024 ))
fi
if [ "$action" == "Restore" ] ; then
  inputfilesize=$( du -b "$inputfile" | awk {'print $1'} )
  inputfilesizehuman=$( filesizehuman $inputfilesize )
  source="<big><b>$(basename "$inputfile")</b></big>"
  dest="<big><b>$drivesizehuman Volume</b></big>"
  outputfile=$devdisk
  outputspace=$drivesize
  # Get uncompressed size of image restore files 
  case "$extension" in
    img|iso)
       totalbytes=$inputfilesize
       ;;
    zip)
       totalbytes=$( unzip -l "$inputfile" | tail -1 | awk '{print $1}')
       ;;
     gz)
       totalbytes=$( gzip -l "$inputfile" | tail -1 | awk '{print $2}')
       ;;
     xz)
       totalbytes=$( xz -lv  "$inputfile" | grep "Uncompressed" | cut -d "(" -f2 | cut -d "B" -f1 | sed -e 's/[^0-9]*//g')
       ;;
  esac 
fi

# Check sizes to find out if there is enough space to do backup or restore
if [ "$totalbytes" -gt "$outputspace" ] ; then
  sizedif=$(( $totalbytes - $outputspace ))
  sizedifhuman=$( filesizehuman $sizedif )

  if [ "$compression" == "Yes" ] && [ "$action" == "Restore" ] ; then
    compressflag=" uncompressed"
  fi
  # Add Warning text 
  warning="<b>WARNING: </b>The$compressflag ${action,,} file is <b>$sizedifhuman</b> too big to fit on the destination storage device.\n\nYou can click Start to continue anyway, or select Cancel to Quit."

fi 
  
### Confirmation Dialog
zenity --question --no-wrap --text="<big>Please confirm settings and click Start</big>\n\n\nSource \n$source \n\nDestination \n$dest \n\n\n$warning\n\n\n<b>NOTE: </b>All Data on the Destination will be deleted" --title "$apptitle - $action" --ok-label=Start --cancel-label=Cancel --width=580

# Cancel if user selects Cancel
if [ ! $? -eq 0 ] ; then
  echo "$action Cancelled"
  exit 0
fi

# Unmount mounted partitions
partitions=$( df | grep $devdisk | awk '{print $1}' )
if [ "$partitions" ] ; then
  umount $partitions
fi

# Check mounted patitions again to make sure they are unmounted
partitions=$( df | grep -c $devdisk )

# Cancel if unable to unmount
if [ ! $partitions -eq 0 ] ; then
  notify-send --icon=$iconfile "$apptitle" "Cannot Unmount $devdisk"
  exit 0
fi

### Start dd copy
notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action Started" 

# Backup
if [ "$action" == "Backup" ] ; then
  if [ "$compression" == "Yes" ] ; then
    # Compressed Backup to GZ file
    dd if="$inputfile" bs=1M | gzip > "$outputfile" &
  else
    # Normal dd uncompressed Backup
    dd if="$inputfile" of="$outputfile" bs=1M &
  fi  
fi

# Restore
if [ "$action" == "Restore" ] ; then
  # IMG files
  if [ "$extension" == "img" ] || [ "$extension" == "iso" ] ; then
    dd if="$inputfile" of="$outputfile" bs=1M &
  fi
  # GZ files
  if [ "$extension" == "gz" ] ; then
    gzip -dc "$inputfile" | dd of="$outputfile" bs=1M &
  fi
  # ZIP files
  if [ "$extension" == "zip" ] ; then
    unzip -p "$inputfile" | dd of="$outputfile" bs=1M &    
  fi
  # XZ files - OSX 10.10 only I think 
  if [ "$extension" == "xz" ] ; then
    tar -xJOf "$inputfile" | dd of="$outputfile" bs=1M &
  fi

fi  


# Get PID of dd running in background
pid=$!

# Monitor progress
progresstext="$action in progress..."
progressmonitor | zenity --progress --auto-close --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$progresstext" --ok-label=Done --no-cancel 

# check if job was cancelled 
if [ ! $? -eq 0 ] ; then
  notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action Cancelled"
  status="Cancelled"
else
  status="Complete"
fi

# set permissions
if [ "$action" == "Backup" ] ; then  
  chown $SUDO_USER "$outputfile"
fi

# Copy Complete
# Display Notifications
notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action $status"

zenity --info --no-wrap --title="$apptitle $version" --text="<big><b>$drivesizehuman Volume $action $status</b></big>" --ok-label=Done

# exit
exit 0