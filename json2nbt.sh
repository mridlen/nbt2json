#!/bin/bash

json=$(cat $1)

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
      label_chars_hex_be=$(echo $label_chars_hex | fold -w2 | tac | tr -d '\n')
      #echo "Label Chars: $label_chars Hex: $label_chars_hex BigEndian: $label_chars_hex_be"
      echo -n "$label_chars_hex_be"
      echo -n "$label"
    # if the label length is 0, just output "0000" for null label and move on...
    else
      # null label size
      echo -n "0000"
    fi

    # Payload(s)
    case $(echo $json | jq -r "$indentation_level[$i].Tag") in
      "01"|"02"|"03"|"04"|"05"|"06")
        payload=$(echo $json | jq -r "$indentation_level[$i].Payload" | fold -w2 | tac | tr -d '\n')
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
          payload_chars_hex_be=$(echo $payload_chars_hex | fold -w2 | tac | tr -d '\n')
        else
          payload_chars_hex_be="0000"
        fi
        echo -n "$payload_chars_hex_be"
        if [[ -n $payload ]]; then
          if [[ $(echo $json | jq -r "$indentation_level[$i].TrailingNewLine") == "yes" ]]; then
            echo "$payload" | xxd -ps | tr -d '\n' 
          else
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
        num_payloads_hex_be=$(echo $num_payloads_hex | fold -w2 | tac | tr -d '\n')
        echo -n "$num_payloads_hex_be"

        #echo "Payloads: $num_payloads DONE"
        local j=0
        for ((j=0; j<num_payloads; j++))
        do
          payload=$(echo $json | jq -r "$indentation_level[$i].Payloads[$j].Payload" | fold -w2 | tac | tr -d '\n')
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

process_entry "." > $1.hex
total_chars=$(($(cat $1.hex | wc -c) / 2 ))
echo "Total Chars: $total_chars"
total_chars_hex="$(printf "%08x" $total_chars)"
echo "Total Chars Hex: $total_chars_hex"
total_chars_hex_be=$(echo $total_chars_hex | fold -w2 | tac | tr -d '\n')
echo "Big Endian: $total_chars_hex_be"
echo -n "0a000000$total_chars_hex_be$(cat $1.hex)" | xxd -r -p > $1.compiled.dat
