# Firmware for a homemade graphics card

### What is this?

This is the firmware for the graphics sub-system of a [homemade computer][dhpc]. The said system
is built around an 8bit microcontroller (ATMEGA644) and produces a VGA signal at the industry
standard 640x480@60Hz. However, the images produced by this GPU have a much lower resolution
(256x240). The color depth is 8bits which gives a total of 256 colors. The firmware provides
a basic API for some simple tasks, such as clearing the screen, setting the background/foreground
color and printing characters etc. The file 3.font.asm contains a retro, fixed width font (the only
font the homemade computer can use), while the file 3.logo.asm contains the image data of a simple
logo. The contents of the second file were created with a little help from a python script
(pixeldata.py). This piece of software, as well as the whole computer, was built as a project
for [deltaHacker magazine][delta].

### How can I use it?

In order to use this piece of software in any meaningful way, you have to built the relevant
[hardware][dhpc]. If you have already decided to built the homemade computer and came here for
the GPU firmware, you just have to download "vga-fw.hex". This the only file you need, unless you
want to hack the firmware. In the later case, you'll need the assembler avrasm2.exe, that is
part of [Atmel Studio][studio]. If you're working under Linux, you can use a compatible
assembler like avra.


[delta]:    http://deltahacker.gr                       "ethical hacking magazine"
[dhpc]:     https://github.com/pvar/dhpc_hardware       "schematics and PCB"
[studio]:   http://www.atmel.com/tools/atmelstudio.aspx "Atmel IDE for the AVR microcontrollers"
