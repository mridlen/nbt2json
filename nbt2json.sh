#!/bin/bash

# usage:
# nbtparse level.dat

# first determine if the file is zipped or not
gunzip -S .dat -l $1
gzip_status=$?

# this should take a level.dat and translate it into space separated hex characters
# e.g. "00 01 02 03"
if [[ $gzip_status -eq "1" ]]; then
  echo "File is plain text. No extraction necessary."
  data=$(xxd -ps $1 | tr -d "\n")
else
  echo "File is gzipped. Extracting file..."
  data=$(zcat $1 | xxd -ps | tr -d "\n")
fi
outfile="$1.json"
echo "Output JSON file: $outfile"
#
# if the level.dat begins with 0a000000 - this is Bedrock
# if the level.dat begins with 0a00000a - this is Java
if [[ ${data:0:8} == "0a000000" ]]; then
  echo "Header indicates Bedrock: ${data:0:8}"
  edition="Bedrock"
elif [[ ${data:0:8} == "0a00000a" ]]; then
  echo "Header indicates Java: ${data:0:8}"
  edition="Java"
else
  echo "Error: unrecognized level.dat edition: ${data:0:8}"
  exit 1
fi

# Bedrock has an 8 byte header with the payload bytes, but Java starts right into the code
if [[ $edition == "Bedrock" ]]; then
  file_payload_size_hex="${data:14:2}${data:12:2}${data:10:2}${data:8:2}"
  file_payload_size=$(echo "ibase=16; ${file_payload_size_hex^^}" | bc)
  file_length=$(( ${#data} / 2 ))
  echo "File Payload Size Reported: $file_payload_size"
  echo "File Payload Size Actual: $(( $file_length - 8 ))"
  # the file payload size is defined by the first 8 characters but does not include them as part of the count
  echo "Difference (should be 0): $(( $file_length - $file_payload_size - 8 ))"
fi

payload=""
tag=""
label_length_hex=""
label_length=""
label=""
payload_hex=""
payload_length_hex=""
payload_length=""
payload_string_length=""
payload_string=""
num_payloads=""
num_payloads_hex=""

echo "[" > $outfile

# Start reading the code at character 16 or 0, depending on edition
if [[ $edition == "Bedrock" ]]; then
  i=16
  # little endian
  be=0
elif [[ $edition == "Java" ]]; then
  i=0
  # java uses big endian
  be=1
fi

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
    if [[ $be -eq "0" ]]; then
      label_length_hex="${data:i+2:2}${data:i:2}"
    elif [[ $be -eq "1" ]]; then
      label_length_hex="${data:i:4}"
    fi
    label_length=$(echo "ibase=16; ${label_length_hex^^}" | bc)
    #echo "Label Length: $label_length"
    ((i+=4))
  else
    label_length=0
  fi

  # read the label
  if [[ $label_length -ne "0" ]]; then
    label_hex="${data:i:$label_length * 2}"
    echo "Label Hex: $label_hex"
    label="\"$(echo "$label_hex" | xxd -r -p)\""
    echo "Label: $label"
    ((i+=$label_length * 2))
  else
    label="null"
    echo "Label: null"
  fi

  case $tag in
    # 01 - byte tag
    "01")
      #echo "Payload Type: byte"
      payload_hex="${data:i:2}"
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=2))
      ;;
    # 02 - 2 byte short
    "02")
      #echo "Payload Type: short"
      if [[ $be -eq "0" ]]; then
        payload_hex="${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_hex="${data:i:4}"
      fi
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=4))
      ;;
    # 03 - 4 byte int
    "03")
      #echo "Payload Type: int"
      if [[ $be -eq "0" ]]; then
        payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_hex="${data:i:8}"
      fi
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=8))
      ;;
    # 04 - 8 byte long int
    "04")
      #echo "Payload Type: long"
      if [[ $be -eq "0" ]]; then
        payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_hex="${data:i:16}"
      fi
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=16))
      ;;
    # 05 - 4 byte float
    "05")
      #echo "Payload Type: float"
      if [[ $be -eq "0" ]]; then
        payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_hex="${data:i:8}"
      fi
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=8))
      ;;
        # 04 - 8 byte double float
    "06")
      #echo "Payload Type: double"
      if [[ $be -eq "0" ]]; then
        payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_hex="${data:i:16}"
      fi
      echo "Payload: ${payload_hex^^}"
      echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payload\":\"$payload_hex\"}" >> $outfile
      ((i+=16))
      ;;
    
    # 08 - string
    "08")
      #echo "Payload Type: string"

      # read 2 byte string length
      if [[ $be -eq "0" ]]; then
        payload_length_hex="${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        payload_length_hex="${data:i:4}"
      fi
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
      if [[ $be -eq "0" ]]; then
        num_payloads_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
      elif [[ $be -eq "1" ]]; then
        num_payloads_hex="${data:i:8}"
      fi
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
            if [[ $be -eq "0" ]]; then
              payload_hex="${data:i+2:2}${data:i:2}"
            elif [[ $be -eq "1" ]]; then
              payload_hex="${data:i:4}"
            fi
            ((i+=4))
            ;;
          "03"|"05")
            if [[ $be -eq "0" ]]; then
              payload_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
            elif [[ $be -eq "1" ]]; then
              payload_hex="${data:i:8}"
            fi
            ((i+=8))
            ;;
          "04"|"06")
            if [[ $be -eq "0" ]]; then
              payload_hex="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
            elif [[ $be -eq "1" ]]; then
              payload_hex="${data:i:16}"
            fi
            ((i+=16))
            ;;  
          "08")
            # payload starts with a two byte short int length
            if [[ $be -eq "0" ]]; then
              payload_string_length_hex="${data:i+2:2}${data:i:2}"
            elif [[ $be -eq "1" ]]; then
              payload_string_length_hex="${data:i:4}"
            fi
            ((i+=4))
            # convert the payload length from hex to decimal and multiply by two, since we need 2 hex chars for each byte
            payload_string_length=$(( $(echo "ibase=16; ${payload_string_length_hex^^}" | bc) * 2 ))
            payload_hex="${data:i:$payload_string_length}"
            payload_string="$( echo "$payload_hex" | xxd -r -p )"
            ((i+=$payload_string_length))
            ;;
          "0a")
            # 0a payload tag indicates that the payloads are typed and labeled
            # However, unlike a tag 0a, there is no closing 00 tag end
            # Example Data:
            # 09 00 0a 41 74 74 72 69 62 75 74 65 73 0a 00 00 00 01 06 00 04 42 61 73 65 3f b9 99 99 a0 00 00 00
            #
            # Tag: 09
            # Label Length: 00 0a - 10 chars
            # Label: Attributes
            # Payload Tag: 0a
            # Num Payloads: 00 00 00 01 - 1 payload
            # ------------------------------------- This code portion focuses on the last half:
            #   Payload Tag: 06
            #   Label Length: 00 04
            #   Label: 42 61 73 65 - Base
            #   Payload: 3f b9 99 99 a0 00 00 00

            payload_payload_tag="${data:i:2}"
            echo "Payload Payload Tag: $payload_payload_tag"
            ((i+=2))
            
            # payload starts with a two byte short int length
            if [[ $be -eq "0" ]]; then
              payload_string_length_hex="${data:i+2:2}${data:i:2}"
            elif [[ $be -eq "1" ]]; then
              payload_string_length_hex="${data:i:4}"
            fi
            ((i+=4))

            # convert the payload length from hex to decimal and multiply by two, since we need 2 hex chars for each byte
            payload_string_length=$(( $(echo "ibase=16; ${payload_string_length_hex^^}" | bc) * 2 ))
            payload_label_hex="${data:i:$payload_string_length}"
            payload_string="$( echo "$payload_label_hex" | xxd -r -p )"
            echo "Payload Label: $payload_string"
            ((i+=$payload_string_length))

            # take the payload based on the payload_payload_tag
            case $payload_payload_tag in
              "01")
                payload="${data:i:2}"
                ((i+=2))
                ;;
              "02")
                payload="${data:i:4}"
                ((i+=4))
                ;;
              "03"|"05")
                payload="${data:i:8}"
                ((i+=8))
                ;;
              "04"|"06")
                payload="${data:i:16}"
                ((i+=16))
                ;;
            esac
            if [[ $be -eq "0" ]]; then
              payload_hex=$(echo -n "$payload" | fold -w2 | tac | tr -d '\n')
            elif [[ $be -eq "1" ]]; then
              payload_hex=$payload
            fi
            ;;
        esac
        echo "Payload: $payload_hex"
        
        # output string payloads to ascii text
        if [[ $payload_tag == "08" ]]; then
          echo -n "{\"Payload\":\"$payload_string\"}" >> $outfile
        elif [[ $payload_tag == "0a" ]]; then
          echo -n "{\"PayloadTag\":\"$payload_payload_tag\", \"Label\":\"$payload_string\", \"Payload\":\"$payload_hex\"}" >> $outfile
        else
          echo -n "{\"Payload\":\"$payload_hex\"}" >> $outfile
        fi

        if [[ $c -lt $num_payloads ]]; then
          echo -n "," >> $outfile
        fi
      done
      echo -n "] }" >> $outfile
      ;;
  # 07 - byte array
  # 0b - int array
  # 0c - long array
  "07"|"0b"|"0c")
    # number of payloads - first 4 bytes
    if [[ $be -eq "0" ]]; then
      num_payloads_hex="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
    elif [[ $be -eq "1" ]]; then
      num_payloads_hex="${data:i:8}"
    fi
    ((i+=8))
    num_payloads=$(echo "ibase=16; ${num_payloads_hex^^}" | bc)
    echo "Num Payloads: $num_payloads"
    echo -n "{\"Tag\":\"$tag\", \"Label\":$label, \"Payloads\": [" >> $outfile
    for (( c=0; c<$num_payloads; c++ ))
    do
      case $tag in
        "07")
          payload="${data:i:2}"
          ((i+=2))
          ;;
        "0b")
          if [[ $be -eq "0" ]]; then
            payload="${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
          elif [[ $be -eq "1" ]]; then
            payload="${data:i:8}"
          fi
          ((i+=8))
          ;;
        "0c")
          if [[ $be -eq "0" ]]; then
            payload="${data:i+14:2}${data:i+12:2}${data:i+10:2}${data:i+8:2}${data:i+6:2}${data:i+4:2}${data:i+2:2}${data:i:2}"
          elif [[ $be -eq "1" ]]; then
            payload="${data:i:16}"
          fi
          ((i+=16))
          ;;
      esac
      echo -n "{\"Payload\":\"$payload\"}" >> $outfile
      if [[ $c -lt $(( $num_payloads -1 )) ]]; then
        echo -n "," >> $outfile
      fi
    done
    echo -n "] }" >> $outfile
    ;;
  esac

  # this part is for the nested tags
  case $tag in
    # 0a - compound tag
    "0a")
      echo "Compound Tag Open"
      echo -n "{\"Tag\":\"$tag\", \"Edition\":\"$edition\", \"Label\":$label, \"Payloads\": [  " >> $outfile
      ;;
    "00")
      echo "Compound Tag Close"
      # remove the trailing comma
      truncate --size=-2 $outfile
      if [[ $edition == "Java" && $i == ${#data} ]]; then
        # do nothing - Java edition seems to put in an extra closing tag
        :
      else
        echo -n "] }" >> $outfile
      fi
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
