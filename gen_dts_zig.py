#!/usr/bin/env python3

# Copyright (c) 2021 Nordic Semiconductor ASA
# SPDX-License-Identifier: Apache-2.0

import argparse
import os
import pickle
import sys
import re
from collections import defaultdict

#sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'python-devicetree',
#                                'src'))

def parse_args():
    # Returns parsed command-line arguments

    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--zig-out", required=True,
                        help="path to write the zig file")
    parser.add_argument("--edt-pickle", required=True,
                        help="path to read the pickled edtlib.EDT object from")
    parser.add_argument("--edt-lib", required=True,
                        help="path to edtlib")
    return parser.parse_args()


def main():
    global zig_out
    args = parse_args()

    sys.path.insert(0, args.edt_lib)
    
    with open(args.edt_pickle, 'rb') as f:
        edt = pickle.load(f)

    s="""
const c = @import("c").c;
"""
    # Create the generated zig.
    with open(args.zig_out, "w", encoding="utf-8") as zig_out:
        print(s, file=zig_out)
        print(print_node_props_and_children( edt.scc_order[0][0], 0, True) , file=zig_out)

        
def ident( level) :
    return ' ' * ( 4 * level)

# if decl is true then use struct declaration
# otherwise implicite struct initialisation
# this is required to ommit circular references
# for phandles
def print_node_props_and_children( node, level, decl) :
    s = ""
    # _device
    # we create an _device if status is okay
    if "status" in node.props and node.props["status"].val  == "okay":
        s += ident( level)
        s += f"const _device = " if decl else f"._device = "
        s += f"@as([*c]const c.struct_device, &c.__device_dts_ord_{node.dep_ordinal})"
        s += ";\n" if decl else ",\n"
    # properties
    for prop_name, prop in node.props.items():
        prop_id = str2ident(prop_name)
        val = prop2value(prop)
        if val is None:
            s += ident( level) + f"// {prop.type}" + "\n"
        s += ident( level)
        s += "const " if decl else "."
        s += f"{prop_id} = "
        if val is not None: s += f"{val}"
        else: s += "undefined"
        s += ";\n" if decl else ",\n"
    # children
    for child in node.children.values():
        child_decl = True if str2ident( child.name) == "soc" else False
        s += ident( level)
        s += f"// {child.dep_ordinal}" + "\n"
        s += ident( level)
        if decl:
            if level == 0:
                s += "pub ";
            s += "const "
        else: s+= "."
        s += f"{str2ident( child.name)} = "
        s += "struct {" if child_decl else ".{"
        s += "\n"
        s += print_node_props_and_children( child, level+1, child_decl)
        s += ident(level)
        s += "};\n" if decl else "},\n"   
    return s

def prop2value(prop):
    # Gets the macro value for property 'prop', if there is
    # a single well-defined C rvalue that it can be represented as.
    # Returns None if there isn't one.

    if prop.type == "string":
        return quote_str(prop.val)

    if prop.type == "int":
        return f"@as( u32, {prop.val})"

    if prop.type == "boolean":
        return "true" if prop.val else "false" 

    if prop.type == "array":
        return "[_]u32" + list2init(f"{hex(val)}" for val in prop.val) 

    if prop.type == "uint8-array":
        return "[_]u8" + list2init(f"{hex(val)}" for val in prop.val) 

    if prop.type == "string-array":
        return "[_][]const u8" + list2init(quote_str(val) for val in prop.val)

    if prop.type == "phandle":
        return  f"{path2ref(prop.val.path)}"

    if prop.type == "phandles":
        return "." + list2init( path2ref(node.path) for node in prop.val) 
    
    if prop.type == "phandle-array":    
        return pharray2items( prop.val)
        
    # phandle, phandles, phandle-array, path, compound: nothing
    return None

def pharray2items( val):
    s = ""
    len_val = len(val)
    if len_val > 1: 
        s += ".{"
    for i, entry in enumerate( val):
        if entry is None:
            continue
        if i > 0: s += ", "
        s += ".{"
        s += f".ph={path2ref(entry.controller.path)}"
        for cell, val in entry.data.items():
            s += ","
            s += "." + str2ident(cell) + "=" + f"@as( u32, {val})"
        s += "}"
    if len_val > 1:
        s += "}"
    return s

def path2ref(p):
     return "&" + re.sub('[/]', '.', re.sub('[-,.@+]', '_', p[1:].lower()))

def str2ident(s):
    # Converts 's' to a form suitable for (part of) an identifier

    return re.sub('[-,.@/+]', '_', s.lower())

def list2init(l):
    # Converts 'l', a Python list (or iterable), to a C array initializer

    return "{" + ", ".join(l) + "}"

def escape(s):
    # Backslash-escapes any double quotes and backslashes in 's'

    # \ must be escaped before " to avoid double escaping
    return s.replace("\\", "\\\\").replace('"', '\\"')


def quote_str(s):
    # Puts quotes around 's' and escapes any double quotes and
    # backslashes within it

    return f'"{escape(s)}"'


def out_comment(s, blank_before=True):
    # Writes 's' as a comment to the header and configuration file. 's' is
    # allowed to have multiple lines. blank_before=True adds a blank line
    # before the comment.

    if blank_before:
        print(file=zig_out)

    if "\n" in s:
        # Format multi-line comments like
        #   // first line
        #   // second line
        #   //
        #   // empty line before this line
        #    
        res = []
        for line in s.splitlines():
            # Avoid an extra space after '*' for empty lines. They turn red in
            # Vim if space error checking is on, which is annoying.
            res.append(" //" if not line.strip() else " // " + line)
        print("\n".join(res), file=zig_out)
    else:
        # Format single-line comments like
        # // foo bar 
        print("// " + s , file=zig_out)


def err(s):
    raise Exception(s)


if __name__ == "__main__":
    main()

    
