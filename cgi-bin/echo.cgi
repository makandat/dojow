#!/usr/bin/python3
import os
SAVE = "/home/makandat/temp/echo.log"
qs = os.environ["QUERY_STRING"].split("=")
message = qs[1]
print("Content-Type: text/plain\n")
print(f"message = {message}")
#with open(SAVE, "w") as f:
#  f.write(qs[0] + "\n")
# f.write(message)
