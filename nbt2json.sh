#!/bin/bash

# usage:
# nbtparse level.dat

# this should take a level.dat and translate it into space separated hex characters
# e.g. "00 01 02 03"
data=$(xxd -ps $1 | tr -d "\n")
outfile="$1.json"
echo "$outfile"
# 
file_payload_size_hex="${data:14:2}${data:12:2}${data:10:2}${data:8:2}"
file_payload_size=$(echo "ibase=16; ${file_payload_size_hex^^}" | bc)
file_length=$(( ${#data} / 2 ))
echo "File Payload Size Reported: $file_payload_size"
echo "File Payload Size Actual: $(( $file_length - 8 ))"
# the file payload size is defined by the first 8 characters but does not include them as part of the count
echo "Difference (should be 0): $(( $file_length - $file_payload_size - 8 ))"

payload=""
tag=""
label_length_hex=""
label_length=""
label=""
payload_hex=""
payload_length_hex=""
payload_length=""

echo "[" > $outfile
# start reading at character 16 (the 17th character since 0 is the first) - the 9th hex character
i=16
while [ $i -lt ${#data} ]; do
  echo "-"
  # read the code
  tag="${data:i:2}"
  echo "Tag: $tag"
  
  # Increment the counter
  ((i+=2))

  if [[ $tag != "00" ]]; then
    # read the label length
    # next two bytes in big endian  reverse order
    label_length_hex="${data:i+2:2}${data:i:2}"
    label_length=$(echo "ibase=16; ${label_length_hex^^}" | bc)
    #echo "Label Length: $label_length"
    ((i+=4))
  else
    label_length=0
  fi

  # read the label
  if [[ $label_length -ne "0" ]]; then
    label_hex="${data:i:$label_length * 2}"
    label="\"$(echo "$label_hex" | xxd -r -p)\""
    echo "Label: $label"
    ((i+=$label_length * 2))
  else
    label="null"
  fi

  case $tag in
    # 01 - byte tag
    "01")
      #echo "Payload Type: byte"
      payload_hex="${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=2))
      ;;
    # 02 - 2 byte short
    "02")
      #echo "Payload Type: short"
      payload_hex="${data:i+2:2}${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=4))
      ;;
    # 03 - 4 byte int
    "03")
      #echo "Payload Type: int"
      payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=8))
      ;;
    # 04 - 8 byte long int
    "04")
      #echo "Payload Type: long"
      payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=16))
      ;;
    # 05 - 4 byte float
    "05")
      #echo "Payload Type: float"
      payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=8))
      ;;
        # 04 - 8 byte double float
    "06")
      #echo "Payload Type: double"
      payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{ \"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\" }" >> $outfile
      ((i+=16))
      ;;
    # 07 - byte array
    "07")
      echo "Fatal error: Tag type 07 - 'byte array' not implemented yet."
      exit 1
      ;;
    # 08 - string
    "08")
      #echo "Payload Type: string"

      # read 2 byte string length
      payload_length_hex="${data:i+2:2}${data:i:2}"
      payload_length=$(echo "ibase=16; ${payload_length_hex^^}" | bc)
      ((i+=4))

      # read the payload
      if [[ $payload_length -gt 0 ]]; then
        payload_hex=${data:i:payload_length * 2}
        payload_last_char=${payload_hex: -2}
        payload="$(echo "$payload_hex" | xxd -r -p)"
        sanitized_payload=$(echo -n "$payload" | jq -R -s '.')
        if [[ $payload_last_char == "0a" ]]; then
          echo "Trailing: $payload_last_char"
          trailing_new_line="yes"
        else
          trailing_new_line="no"
        fi
        ((i+=$payload_length * 2))
      else
        sanitized_payload="null"
        trailing_new_line="no"
        echo "Payload: <null>"
      fi
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":$sanitized_payload, \"TrailingNewLine\":\"$trailing_new_line\"}" >> $outfile
      ;;
    # 09 - tag list
    "09")
      #echo "Payload Type: tag"
      # read the payload tag type
      payload_tag=${data:i:2}
      ((i+=2))

      # number of payloads in 4 byte int big endian
      num_payloads_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      num_payloads=$(echo "ibase=16; ${num_payloads_hex^^}" | bc)
      ((i+=8))
      

      #echo "Payloads: $num_payloads"
      echo "Payload Tag: $payload_tag"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"PayloadTag\":\"$payload_tag\", \"Payloads\": [" >> $outfile
      for (( c=1; c<=$num_payloads; c++ ))
      do
        case $payload_tag in
          "01")
            payload_hex="${data:i:2}"
            ((i+=2))
            ;;
          "02")
            payload_hex="${data:i+2:2}${data:i:2}"
            ((i+=4))
            ;;
          "03"|"05")
            payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
            ((i+=8))
            ;;
          "04"|"06")
            payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
            ((i+=16))
            ;;  
        esac
        echo "Payload: $payload_hex"
        echo -n "{\"Payload\":\"$payload_hex\"}" >> $outfile
        if [[ $c -lt $num_payloads ]]; then
          echo -n "," >> $outfile
        fi
      done
      echo -n "] }" >> $outfile
      ;;
    # 0b - ??
    # 0c - ??
    "0b"|"0c")
      echo "Fatal Error: tags 0b and 0c not implemented yet."
      exit 1
      ;;
  esac

  # this part is for the nested tags
  case $tag in
    # 0a - compound tag
    "0a")
      echo "Compound Tag Open"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payloads\": [  " >> $outfile
      ;;
    "00")
      echo "Compound Tag Close"
      # remove the trailing comma
      truncate --size=-2 $outfile
      echo -n "] }" >> $outfile
      ;;
  esac

  if [[ $tag != "0a" ]]; then
      echo "Add comma separator in json"
      echo "," >> $outfile
  fi
done
echo "-"
echo "END OF FILE"
# remove trailing comma
truncate --size=-2 $outfile
echo "]" >> $outfile
echo "JSON: ]"
