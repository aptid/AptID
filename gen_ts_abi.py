import sys
  
abi_file = sys.argv[1]
hex_abis = []
with open(abi_file) as file:
    lines = file.readlines()
    hex_abis = [line.rstrip() for line in lines]

hex_strs = ""
for s in hex_abis:
    hex_strs += "\n\t\"%s\"," % s

ts = """export const APT_ID_ABIS = [%s
];""" % hex_strs

print(ts)
