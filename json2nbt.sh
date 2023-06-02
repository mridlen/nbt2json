#!/bin/bash

json=$(cat $1)
edition=$(echo $json | jq -r '.[].Edition')
echo "Edition: $edition"

process_entry() {
  # a jq formatted path like '.[0].Payloads[32].Payloads'
  local indentation_level="$1"
  local length=$(echo "$json" | jq -r "$indentation_level | length")

  local i=0
  for ((i=0; i<length; i++))
  do
    #echo "Object: $indentation_level[$i]"
    #echo "JSON: $(echo $json | jq -r "$indentation_level[$i]")"
    #echo "END JSON"
    # output the tag
    echo -n "$(echo $json | jq -r "$indentation_level[$i].Tag")"

    # output the label length followed by the label
    if [[ $(echo $json | jq -r "$indentation_level[$i].Label") != "null" ]]; then
    # jq -r ".[0].Payloads[32].Payloads[1].Label" level.dat.json | tr -d '\n' | xxd -ps
      label=$(echo -n "$(echo $json | jq -r "$indentation_level[$i].Label" | tr -d '\n' | xxd -ps)")
      label_chars=$(( $(echo -n "$label" | wc -c) / 2 ))
      label_chars_hex="$(printf "%04x" $label_chars)"
      label_chars_hex_le=$(echo $label_chars_hex | fold -w2 | tac | tr -d '\n')
      if [[ $edition == "Bedrock" ]]; then
        echo -n "$label_chars_hex_le"
      elif [[ $edition == "Java" ]]; then
        echo -n "$label_chars_hex"
      fi
      echo -n "$label"
    # if the label length is 0, just output "0000" for null label and move on...
    else
      # null label size
      echo -n "0000"
    fi

    # Payload(s)
    case $(echo $json | jq -r "$indentation_level[$i].Tag") in
      "01"|"02"|"03"|"04"|"05"|"06")
        if [[ $edition == "Bedrock" ]]; then
          payload=$(echo $json | jq -r "$indentation_level[$i].Payload" | fold -w2 | tac | tr -d '\n')
        elif [[ $edition == "Java" ]]; then
          payload=$(echo $json | jq -r "$indentation_level[$i].Payload")
        fi
        echo -n "$payload"
        ;;
      "08")
        payload=$(echo $json | jq -r "$indentation_level[$i].Payload // empty")
        if [[ -n $payload ]]; then
          if [[ $(echo $json | jq -r "$indentation_level[$i].TrailingNewLine") == "yes" ]]; then
            payload_chars=$(( $(echo -n "$payload" | wc -c) + 1 ))
          else
            payload_chars=$(echo -n "$payload" | wc -c)
          fi
          payload_chars_hex="$(printf "%04x" $payload_chars)"
          payload_chars_hex_le=$(echo $payload_chars_hex | fold -w2 | tac | tr -d '\n')
        else
          payload_chars_hex_le="0000"
        fi

        if [[ $edition == "Bedrock" ]]; then
          echo -n "$payload_chars_hex_le"
        elif [[ $edition == "Java" ]]; then
          echo -n "$payload_chars_hex"
        fi

        if [[ -n $payload ]]; then
          if [[ $(echo $json | jq -r "$indentation_level[$i].TrailingNewLine") == "yes" ]]; then
            # echo adds a trailing new line by default
            echo "$payload" | xxd -ps | tr -d '\n' 
          else
            # echo -n means no trailing new line
            echo -n "$payload" | xxd -ps | tr -d '\n'
          fi
        fi
        # if the payload is null, don't do anything :)
        ;;
      "09")
        # first value is the tag type
        payload_tag=$(echo $json | jq -r "$indentation_level[$i].PayloadTag")
        echo -n "$payload_tag"

        # next value is the number of tags
        num_payloads=$(echo $json | jq -r "$indentation_level[$i].Payloads | length")
        num_payloads_hex=$(printf "%08x" $num_payloads)
        num_payloads_hex_le=$(echo $num_payloads_hex | fold -w2 | tac | tr -d '\n')
        if [[ $edition == "Bedrock" ]]; then
          echo -n "$num_payloads_hex_le"
        elif [[ $edition == "Java" ]]; then
          echo -n "$num_payloads_hex"
        fi

        #echo "Payloads: $num_payloads DONE"
        local j=0
        for ((j=0; j<num_payloads; j++))
        do
          # payload 08 string has a length for each payload
          if [[ $payload_tag == "08" ]]; then
            payload_string_length=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload" | tr -d '\n' |  wc -c)
            payload_string_length_hex=$(printf "%04x" $payload_string_length)
            payload_string_length_hex_le=$(echo $payload_string_length_hex | fold -w2 | tac | tr -d '\n')
            # first 2 bytes are payload length
            if [[ $edition == "Bedrock" ]]; then
              echo -n "$payload_string_length_hex_le"
            elif [[ $edition == "Java" ]]; then
              echo -n "$payload_string_length_hex"
            fi
            # then output the payload
            payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload // empty")
            echo -n "$payload" | xxd -ps | tr -d '\n'
          elif [[ $payload_tag == "0a" ]]; then
            # payload payload tag
            payload_payload_tag=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].PayloadTag")
            echo -n "$payload_payload_tag"
            # label length
            payload_label=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Label")
            payload_label_length=$(echo -n "$payload_label" | wc -c)
            payload_label_length_hex=$(printf "%04x" $payload_label_length)
            payload_label_length_hex_le=$(echo $payload_label_length_hex | fold -w2 | tac | tr -d '\n')
            if [[ $edition == "Bedrock" ]]; then
              echo -n "$payload_label_length_hex_le"
            elif [[ $edition == "Java" ]]; then
              echo -n "$payload_label_length_hex"
            fi
            # label
            echo -n "$payload_label" | xxd -ps | tr -d '\n'
            # payload
            payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload")
            echo -n "$payload"
          # all other tag types are handled this other way
          else
            if [[ $edition == "Bedrock" ]]; then
              payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload" | fold -w2 | tac | tr -d '\n')
            elif [[ $edition == "Java" ]]; then
              payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload")
            fi
            echo -n "$payload"
          fi
        done
        ;;
      "07"|"0b"|"0c")
        num_payloads=$(echo $json | jq -r "$indentation_level[$i].Payloads | length")
        # length of number of payloads is 8 hex - 4 byte int
        num_payloads_hex=$(printf "%08x" $num_payloads)
        num_payloads_hex_le=$(echo $num_payloads_hex | fold -w2 | tac | tr -d '\n')
        if [[ $edition == "Bedrock" ]]; then
          echo -n "$num_payloads_hex_le"
        elif [[ $edition == "Java" ]]; then
          echo -n "$num_payloads_hex"
        fi

        local j=0
        for ((j=0; j<num_payloads; j++))
        do
          if [[ $edition == "Bedrock" ]]; then
            payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload" | fold -w2 | tac | tr -d '\n')
          elif [[ $edition == "Java" ]]; then
            payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload")
          fi
          echo -n "$payload"
        done
        ;;
      "0a")
        next_level="$indentation_level[$i].Payloads"
        process_entry "$next_level"
        # close with a tag 00 - Tag_End
        echo -n "00"
        ;;
    esac
  done
}

echo "Processing (this may take a few minutes)..."

process_entry "." > $1.hex
if [[ $edition == "Bedrock" ]]; then
  echo "Bedrock Edition: adding 8 byte header..."
  total_chars=$(($(cat $1.hex | wc -c) / 2 ))
  echo "Total Chars: $total_chars"
  total_chars_hex="$(printf "%08x" $total_chars)"
  echo "Total Chars Hex: $total_chars_hex"
  total_chars_hex_le=$(echo $total_chars_hex | fold -w2 | tac | tr -d '\n')
  echo "Little Endian: $total_chars_hex_le"
  # bedrock has an 8 byte header
  # first 4 bytes are:  0a 00 00 00 (0a compound open, 00 00 <null label>, 00 close)
  # next 4 bytes are:   xx xx xx xx (this is the total bytes, little endian format)
  # the number of bytes DOES NOT INCLUDE THE 8 BYTE HEADER!
  echo -n "0a000000$total_chars_hex_le$(cat $1.hex)" | xxd -r -p > $1.compiled.dat
elif [[ $edition == "Java" ]]; then
  # java edition has an extra closing tag for some reason
  echo "Java Edition: adding '00' footer..."
  echo -n "$(cat $1.hex)00" | xxd -r -p > $1.compiled.dat.unzipped
  echo "Java Edition: gzip compression..."
  # java edetion gzips the file as well
  gzip -cvfn $1.compiled.dat.unzipped > $1.compiled.dat
  # just for 100% file parity, we change the gzip header OS code to "unknown"
  echo "Java Edition: Changing gzip OS code to FF (unknown OS)..."
  printf '\xff' | dd of=$1.compiled.dat bs=1 seek=9 count=1 conv=notrunc
fi

echo "Processing finished."
