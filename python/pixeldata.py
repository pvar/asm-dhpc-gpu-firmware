#!/usr/bin/env python

# author      : Panos Varelas
# date        : 05-03-2015
# description : Creates arithmetic representation of images for use in homebrew VGA
# usage       : python linedata.py {image files}
# notes       : for deltaHacker magazine (http://deltahacker.gr)



# import necessary libraries
import os, sys
from PIL import Image

# create/open output file
output = open("imagedata.txt", "w")

# loop through argument list
sys.argv.pop(0)
for image_file in sys.argv:

	# open image file and load content
	img_object = Image.open(image_file)
	pixel_array = img_object.load()
	img_width = img_object.size[0]
	img_height = img_object.size[1]

	# create short list or properties
	output.write("file name     : " + image_file + "\n")
	output.write("file format   : " + img_object.format + "\n")
	output.write("color format  : " + img_object.mode + "\n")
	output.write("image width   : " + str(img_width) + "\n")
	output.write("image height  : " + str(img_height) + "\n\n")

	# compute a value for each pixel of each row
	x_limit = img_width - 1
	for y in range(0, img_height):
		output.write(".db ")
		for x in range(0, img_width):
			r = pixel_array[x, y][0]
			g = pixel_array[x, y][1]
			b = pixel_array[x, y][2]
			m = (r + g + b) / 3
			r = (r >> 6) & 0b00000011
			g = (g >> 4) & 0b00001100
			b = (b >> 2) & 0b00110000
			m = m & 0b11000000
			byte = m + r + g + b
			if x < x_limit: output.write(str(byte) + ","),
			else: output.write(str(byte) + "\n")

# close output file
output.close()
