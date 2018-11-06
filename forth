#!/bin/bash

pop () {
  while (( $# )); do
    eval "$1=\${stack[-1]}"
    unset "stack[-1]"
    shift
  done
}

push () { stack+=("$@"); }

output () { echo -n "$* "; }

declare -A funcs variables constants

evaluate () {
  local a b c
  while (( $# )); do
    if [[ -v "funcs[${1@Q}]" ]]; then
      eval evaluate "${funcs[$1]}"
    elif [[ -v "constants[${1@Q}]" ]]; then
      push "${constants[$1]:-0}"
    else
      case ${1,,} in
        '\') break;;
        [-+*/%]) pop a b; push "$((a $1 b))";;
        .) pop a; output "$a";;
        dup) pop a; push "$a" "$a";;
        .s) output "${stack[*]}";;
        swap) pop a b; push "$a" "$b";;
        abs) pop a; push "${a#-}";;
        negate) pop a; push "$((-a))";;
        drop) pop a;;
        max) pop a b; push "$((a > b ? a : b))";;
        min) pop a b; push "$((a < b ? a : b))";;
        bye) exit ;;
        nip) pop a b; push "$a";;
        tuck) pop a b; push "$a" "$b" "$a";;
        rot) pop a b c; push "$b" "$a" "$c";;
        over) pop a b; push "$b" "$a" "$b";;
        pick) pop a; push "${stack[-a-1]}";;
        roll) pop a
              stack=(
                     "${stack[@]::${#stack[@]}-1-a}"
                     "${stack[@]: -a}"
                     "${stack[-a-1]}"
                     )
                     ;;
        =) pop a b; push "$((a == b))";;
        ['><'])  pop a b; push "$((b $1 a))";;
        '(') while [[ $1 != ')' ]]; do shift; done ;;
        cr) output $'\n';;
        .\") string=
             shift
             while [[ $1 != '"' ]]; do string+="$1 "; shift; done
             output "$string"
             ;;
        :) name="$2" code=
           shift 2
           while [[ $1 != ';' ]]; do
             code+="${1@Q} "
             shift
           done
           funcs[$name]=$code
           ;;
        see) shift; output "${funcs[$1]}";;
        do) local i=0 code=
            shift
            while [[ ${1,,} != loop ]]; do
              code+="${1@Q} "
              shift
            done
            pop a b
            while (( a+i != b )); do
              eval evaluate "$code"
              (( i += a < b ? 1 : -1 ))
            done
            ;;
        \?do) local i=0 code=
            shift
            while [[ ${1,,} != loop ]]; do
              code+="${1@Q} "
              shift
            done
            pop a b
            while (( a+i != b )); do
              eval evaluate "$code"
              (( i += a < b ? 1 : -1 ))
            done
            ;;
        i) push "$i" ;;
        begin) code=
               shift
               while [[ ${1,,} != until ]]; do
                 code+="${1@Q} "
                 shift
               done
               while :; do
                 eval evaluate "$code"
                 pop a; (( a )) && break
               done ;;
        if) local code=() q=0
            shift
            while [[ ${1,,} != then ]]; do
              [[ ${1,,} = else ]] && ((++q)) || code[q]+="${1@Q} "
              shift
            done
            pop a
            eval evaluate "${code[!a]}"
            ;;
        constant) shift; pop "constants[$1]";;
        variable) shift; variables[$1]=0;;
        !) pop name val; variables[$name]=$val;;
        @) pop name; push "${variables[$name]}";;
        \?) pop name; output "${variables[$name]}";;
        clearstack) stack=() ;;
        *) push "$1";;
      esac
    fi
    shift
  done
}

while read -re; do
  history -s -- "$REPLY"
  read -ra input <<< "$REPLY"
  echo -n $'\e[32m>\e[m '
  evaluate "${input[@]}"
  echo $'\e[32mok\e[m'
done
