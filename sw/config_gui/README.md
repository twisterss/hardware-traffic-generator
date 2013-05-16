Configuration GUI
==========================

Usage
--------------------------
This tool is a Graphical User Interface to generate configuration files.
For each flow:
* write a skeleton (copied from Wireshark for example),
* choose a bit rate,
* activate/deactivate and configure each available modifier.

The list of available flows and modifiers is configured in a JSON file. It must correspond to the hardware configuration.

### Command-line

```./generator_gui```

Dependencies
--------------------------
Python 3 and the PyQt 4 library must be installed on the computer.