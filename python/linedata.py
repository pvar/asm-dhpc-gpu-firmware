linebatch = 0
while linebatch < 24:
	line = 0
	print ".db ",
	while line < 10:
		print "0, " + str(linebatch * 10 + line) + ", 0, " + str(linebatch * 10 + line) + ", ",
		line = line + 1
	linebatch = linebatch + 1
	print ""
