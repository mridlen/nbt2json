# nbt2json
Minecraft level.dat tool for Bedrock edition

Tested on Ubuntu only.

Step 1: BACK UP YOUR WORLD DIRECTORY!!!!1
```
cd /yourminecraftdir
cp -r worlds/ worlds-backup
```

Install the prerequisites:
```
sudo apt install xxd jq
# hexyl is nice to have too for validating binary files :)
sudo apt install hexyl
```

Make the scripts executable

```
chmod +x nbt2json.sh
chmod +x json2nbt.sh
```

Extract your level.dat to json format
```
./nbt2json.sh level.dat
```

Now you have a level.dat.json file. You can edit this file.

Then recompile it into a level.dat
```
./json2nbt.sh level.dat.json
```
It will be saved into level.dat.json.compiled.dat - this is your new level.dat

Replace it at your own risk!!!

If you have hexdump or hexyl installed, you can do a diff on the files.
```
diff <(level.dat) <(level.dat.json.compiled.dat)
```

If you convert the file from nbt to json and then back to nbt without editing it, the files should be identical.
If they are not, please submit a bug report and include your level.dat in the bug report.
You can create a text version of it by doing this:
```
cat level.dat | xxd -ps
```
Then just copy and paste the text into the bug report.

All values are HEXADECIMAL (except strings).
They have been converted from big endian to little endian for your editing pleasure.

Payload Types:
01 - 1 byte payload (2 hex chars)
02 - 2 byte short (4 hex chars)
03 - 4 byte (8 hex chars)
04 - 8 byte long int (16 hex chars)
05 - 4 byte floating point (8 hex chars)
06 - 8 byte double floating point (16 hex chars)
07 - not implemented
08 - string payload
09 - tag list - a series of payloads (Types 01 through 06 supported)
0a - compound tag (sort of like a folder where more tags can live under it)
0b - not implemented
0c - not implemented
00 - end tag (closes out a compound tag) - these do not appear in the json file but they are added back in when it is recompiled

Regarding type 09 - here is how it is decoded from the hex code
```
	# 09 - tag list - this one is confusing
	09 15 00 lastOpenedWithVersion
	  # type int
	  03
	  # int length - 5
	  05 00 00 00
	  # int, int, int, int, int
	  01 00 00 00
	  13 00 00 00
	  53 00 00 00
	  01 00 00 00
	  00 00 00 00
```
1.13.53.1 corresponds to 1.19.83.1 in decimal
