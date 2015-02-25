# dd-utility
<strong>Write and Backup Operating System IMG files on SD Memory Card</strong>

There are several tools available to copy and install IMG files to SD Memory Cards, but I was looking for something that could easily backup and restore disk image files for my Raspberry Pi with Mac OS X.

I also wanted a program that could write compressed IMG files directly to the memory card without the need to decompress the image files first. dd the command line utility has been my default choice for years, but lacked a GUI that fit my requirements and so I decided to write my own - that is how dd Utility came to be.

<h2>Features</h2>

- Write IMG files to memory cards and hard drives.
- Backup and Restore IMG files to memory cards and hard drives.
- Install and Restore compressed disk image files on the fly. Supported file formats: IMG, Zip, GZip and XZ.
- Backup and compress disk image files on the fly in ZIP format to significantly reduce the file size of backups.
- Ideal for flashing IMG files to SD Cards for use with Raspberry Pi, Arduino,  BeagleBoard and other ARM boards.
- Mac Retina displays supported.

<h2>Requirements</h2>
- Currently only Mac OSX is supported, Linux support to follow soon.
- OS X 10.6 or later

<h2>Technical</h2>
- Written in Bash and a bit of Applescript for dialogs
