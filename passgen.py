import re
import sys
from utilitybelt import change_charset

oc = "abcdefghijklmnopqrstuvwxyz!@#$%^&*()_1234567890."
nc = "4bcd3f6h1jklmn0pqr57uvwxyz!@#$%^&*()_1234567890."

if(len(sys.argv) != 3):
    print(f"{sys.argv[0]} <user> <website>")
    sys.exit(1)

usr = change_charset(sys.argv[1].lower(), oc, nc).capitalize()

for j, i in enumerate(usr):
    if(i.isalpha()):
        usr = usr[:j] + i.capitalize() + usr[j+1:]
        break

pw = change_charset(sys.argv[2].lower(), oc, nc)

print(pw + usr)

#example: python passgen.py johndoe instagram yields "1n5746r4mJ0hnd03"
