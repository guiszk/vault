#!/usr/bin/env bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${0##*/}"
[[ "$(uname -s)" == "Darwin" ]] && alias sed="gsed" && clipb="pbcopy"
[[ "$(uname -s)" == "Linux" ]] && clipb="xclip -selection c"

#
# FUNCTIONS START
#
die() {
    echo "$@" >>/dev/stderr
    [[ -f .web.lst ]] && all e
    exit 1
}

usage() {
cat <<EOF
Usage:
    $RUN init
        Delete all info, reset password and start from scratch.
    $RUN add [domain] [user] [*password]
        Add new credentials to a domain.
        Run with no options for interactive mode.
        Leave password blank to auto-generate.
    $RUN list [search|domain] [user]
        List all domains, search domains and users
        and show passwords.
    $RUN edit  *-d,--delete [domain] [username] [password]
        Edit password, use -d to delete.
        Run with no options for interactive mode.
    $RUN -h, --help
        Show this text.
EOF
exit 0
}

trap_ctrlc() {
    [[ -f .web.lst ]] && all e
    exit 1
}

fgpg() {
    # fgpg [d|e] [u|p|w|m]
    ################ D E C O D E ##############
    if [[ "$1" == "d" ]]; then
        case "$2" in
            u) shift; echo "$PASS$(sed '1q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.usr.lst --decrypt "$HERE"/.usr.enc &>/dev/null && rm "$HERE"/.usr.enc || die "Wrong password.";;
            p) shift; echo "$PASS$(sed '2q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.pass.lst --decrypt "$HERE"/.pass.enc &>/dev/null && rm "$HERE"/.pass.enc || die "Wrong password.";;
            w) shift; echo "$PASS$(sed '3q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.web.lst --decrypt "$HERE"/.web.enc &>/dev/null && rm "$HERE"/.web.enc || die "Wrong password.";;
            m) shift; echo "$PASS" | gpg --batch --passphrase-fd 0 --output "$HERE"/.wa.lst --decrypt "$HERE"/.wa.enc &>/dev/null && rm "$HERE"/.wa.enc || die "Wrong password.";;
            *) die "Error";;
        esac
    ################ E N C O D E ##############
    elif [[ "$1" == "e" ]]; then
        case "$2" in
            u) shift; echo "$PASS$(sed '1q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.usr.enc --symmetric --no-symkey-cache --cipher-algo AES256 "$HERE"/.usr.lst &>/dev/null && rm "$HERE"/.usr.lst;;
            p) shift; echo "$PASS$(sed '2q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.pass.enc --symmetric --no-symkey-cache --cipher-algo AES256 "$HERE"/.pass.lst &>/dev/null && rm "$HERE"/.pass.lst;;
            w) shift; echo "$PASS$(sed '3q;d' $HERE/.wa.lst | rev)" | gpg --batch --passphrase-fd 0 --output "$HERE"/.web.enc --symmetric --no-symkey-cache --cipher-algo AES256 "$HERE"/.web.lst &>/dev/null && rm "$HERE"/.web.lst;;
            m) shift; echo "$PASS" | gpg --batch --passphrase-fd 0 --output "$HERE"/.wa.enc --symmetric --no-symkey-cache --cipher-algo AES256 "$HERE"/.wa.lst &>/dev/null && rm "$HERE"/.wa.lst || die "Wrong password.";;
            *) die "Error";;
        esac
    else
        die "Usage: fgpg [d|e] [u|p|w]"
    fi
}

init() {
    [[ "$(read -e -n 1 -r -p 'This will delete all credentials and reset the master password. Continue? [Y/n] '; echo $REPLY)" == [Yy]* ]] || die "Aborting."
    rm "$HERE"/.*.enc 2&>/dev/null
    read -r -s -p "Enter new password: " PASS && echo
    touch .{usr,pass,web,wa}.lst
    pwgen -y -s $((5 + RANDOM % 7)) 3 | tr " " "\n" > "$HERE"/.wa.lst
    echo "All info deleted, run $RUN add to add new credentials."
}

all() {
    [[ $# -eq 2 ]] && read -r -s -p "$2" PASS && echo
    case "$1" in
        d) shift; fgpg d m && fgpg d u && fgpg d p && fgpg d w;;
        e) shift; fgpg e u && fgpg e p && fgpg e w && fgpg e m;;
        *) die "Error";;
    esac
}

dif() {
    same=()
    while IFS= read -r a; do
        while IFS= read -r b; do
            [[ "$a" == "$b" ]] && same+=("$a")
        done < <(echo "$2")
    done < <(echo "$1")
    [[ ${#same[@]} -gt 1 ]] && die "Error: multiple matches found."
    [[ ${#same[@]} -ne 1 ]] && die "Error: account not found."
}

domcheck() {
    local match
    [[ -z "$1" ]] && return 1
    match=$(echo "$1" | grep -E -o "[a-zA-Z0-9]+(\.[a-zA-Z]{1,4})+\b")
    #echo $match
    if [[ "$1" == "$match" ]]; then
        return 0
    else
        return 1
    fi
}

check() {
    # check [dom] [usr]
    #return usernames
    if [[ $# -lt 2 ]]; then
        if echo "$1" | grep -E -q "[a-zA-Z0-9]+(\.[a-zA-Z]{1,4})+\b"; then
            ret=$(for i in $(grep -nF "$1" "$HERE"/.web.lst | cut -d : -f 1 | tr '\n' ' '); do sed "${i}q;d" "$HERE"/.usr.lst; done)
        else
        #return domains
            ret=$(for i in $(grep -nF "$1" "$HERE"/.usr.lst | cut -d : -f 1 | tr '\n' ' '); do sed "${i}q;d" "$HERE"/.web.lst; done)
        fi
    else
        domline=$(grep -nF "$1" "$HERE"/.web.lst | cut -d : -f 1)
        usrline=$(grep -nF "$2" "$HERE"/.usr.lst | cut -d : -f 1)
        dif "$domline" "$usrline"
    fi
}

add() {
    all d 'Enter master password: '
    trap "trap_ctrlc" 2
    local dom usr pw domname match
    if [[ $# -eq 0 ]]; then
        read -r -p "Enter domain: " dom

        domcheck "$dom" || die "Domain must fit [example.com/example.co.nz]"
        check "$dom"
        domname=$(echo "$dom" | cut -d "." -f 1)
        read -r -p "Enter username: " usr
        [[ -z "$usr" ]] && die "Please enter a username."
        [[ $ret =~ $usr ]] && die "$usr's $domname account already exists."
        echo "$usr" >> "$HERE"/.usr.lst
        echo "$dom" >> "$HERE"/.web.lst
        read -r -p "Enter password (leave blank to auto-generate): " pw
        if [[ -z "$pw" ]]; then
            pw=$(pwgen -y -s $((12 + RANDOM % 20)) 1) >> "$HERE"/.pass.lst
            echo "$pw" | $clipb
            echo "Password copied to clipboard."
        fi
        echo "$pw" >> "$HERE"/.pass.lst
        unset pw
        echo "$usr's $domname account added."
    else
        dom=$1
        usr=$2
        pw=$3
        domcheck "$dom" || die "Domain must fit [example.com/example.co.nz]"
        check "$dom" # ret usernames
        domname=$(echo "$dom" | cut -d "." -f 1)
        [[ -z "$usr" ]] && die "Usage: $RUN -a, --add [domain] [user] [*password]"
        [[ $ret =~ $usr ]] && die "$usr's $domname account already exists."
        echo "$usr" >> "$HERE"/.usr.lst
        echo "$dom" >> "$HERE"/.web.lst
        if [[ $# -eq 2 ]]; then
            pw=$(pwgen -y -s $((10 + RANDOM % 20)) 1)
            echo "$pw" | $clipb
            echo "Password copied to clipboard."
        fi
        echo "$pw" >> "$HERE"/.pass.lst
        echo "$usr's $domname account added."
    fi
}

list() {
    all d 'Enter master password: '
    bold=$(tput bold)
    normal=$(tput sgr0)
    [[ -s "$HERE"/.web.lst ]] || die "There is nothing saved. Run $RUN add to add new credentials."
    if [[ $# -eq 0 ]]; then
        while IFS= read -r dom; do
            echo "${bold}$dom${normal}"
            check "$dom"
            while IFS= read -r usr; do
                echo -e "└─ $usr"
            done < <(echo "$ret")
        done < <(sort "$HERE"/.web.lst | uniq)
    elif [[ "$#" -eq 1 ]]; then
        if grep -Fq "$1" "$HERE"/.web.lst; then
            while IFS= read -r dom; do
                check "$dom"
                if [[ -n "$ret" ]]; then
                    echo "${bold}$dom${normal}"
                    while IFS= read -r usr; do
                        echo -e "└─ $usr"
                    done < <(echo "$ret")
                fi
            done < <(grep -F "$1" "$HERE"/.web.lst | sort | uniq)
        elif grep -Fq "$1" "$HERE"/.usr.lst; then
            while IFS= read -r usr; do
                check "$usr"
                if [[ -n "$ret" ]]; then
                    echo "${bold}$usr${normal}"
                    while IFS= read -r dom; do
                        echo -e "└─ $dom"
                    done < <(echo "$ret")
                fi
            done < <(grep -F "$1" "$HERE"/.usr.lst | sort | uniq)
        else
            die "Domain or user not found."
        fi
    else
        if grep -Fq "$1" "$HERE"/.web.lst; then
            check "$1" "$2"
            # echo "${same[0]}"
            sed "${same[0]}q;d" "$HERE"/.pass.lst
            unset same
        else
            die "Domain not found."
        fi
    fi
}

edit() {
    all d 'Enter master password: '
    trap "trap_ctrlc" 2
    case "$1" in
        -d|--delete) shift;
            if [[ "$#" -eq 2 ]]; then
                if grep -Fq "$1" "$HERE"/.web.lst; then
                    if grep -Fq "$2" "$HERE"/.usr.lst; then
                        check "$1" "$2"
                        gsed -i "${same[0]}d" "$HERE"/.{usr,pass,web}.lst
                        echo "$2's $(echo $1 | cut -d . -f 1) account deleted."
                        unset same
                    else
                        die "Username not found in this domain."
                    fi
                else
                    die "Domain not found."
                fi
            elif [[ "$#" -eq 0 ]]; then
                echo "Deleting account."
                read -r -p "Enter domain: " dom
                if grep -Fq "$dom" "$HERE"/.web.lst; then
                    read -r -p "Enter username: " usr
                    if grep -Fq "$usr" "$HERE"/.usr.lst; then
                        check "$dom" "$usr"
                        domname=$(grep -F "$dom" "$HERE"/.web.lst | cut -d . -f 1)
                        echo "$usr's $domname account deleted."
                        gsed -i "${same[0]}d" "$HERE"/.{usr,pass,web}.lst
                        unset same
                    else
                        die "Username not found in this domain."
                    fi
                else
                    die "Domain not found."
                fi
            else
                die "Usage: $RUN edit -d [domain] [username]"
            fi;;
        *)
            if [[ "$#" -eq 3 ]]; then
                if grep -Fq "$1" "$HERE"/.web.lst; then
                    if grep -Fq "$2" "$HERE"/.usr.lst; then
                        check "$1" "$2"
                        gsed -i "${same[0]}s/.*/${3}/" "$HERE"/.pass.lst
                        echo "Password changed."
                        unset same
                    else
                        die "Username not found in this domain."
                    fi
                else
                    die "Domain not found."
                fi
            elif [[ "$#" -eq 0 ]]; then
                echo "Changing password."
                read -r -p "Enter domain: " dom
                [[ -z "$dom" ]] && die "Invalid domain."
                if grep -Fq "$dom" "$HERE"/.web.lst; then
                    read -r -p "Enter username: " usr
                    [[ -z "$usr" ]] && die "Invalid username."
                    if grep -Fq "$usr" "$HERE"/.usr.lst; then
                        check "$dom" "$usr"
                        read -r -s -p $'Enter new password: ' pw
                        gsed -i "${same[0]}s/.*/${pw}/" "$HERE"/.pass.lst
                        echo -e "\nPassword changed."
                        unset same
                    else
                        die "Username not found in this domain."
                    fi
                else
                    die "Domain not found."
                fi
            else
                die "Usage: $RUN edit [domain] [username] [password]"
            fi;;
    esac
}
#
# FUNCTIONS END
#

case "$1" in
    init) shift; init "$@";;
    add) shift; add "$@";;
    list) shift; list "$@";;
    edit) shift; edit "$@";;
    -h|--help|*) usage;;
esac
[[ -f .web.lst ]] && all e ######### ALWAYS ENCRYPT IN THE END #########
unset PASS
exit 0