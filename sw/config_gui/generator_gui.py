#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Traffic generator graphic user interface.
This is the main file
"""

import sys
from PyQt4 import QtGui

from gui import MainWindow
from config_editor import Hardware

def main():
    """
    Start the program
    """

    # Initialize the backend
    hardware = Hardware("config/hardware.json")

    # Initialize the GUI
    app = QtGui.QApplication(sys.argv)
    window = MainWindow(hardware)

    # Start
    window.show()
    sys.exit(app.exec_())
    

if __name__ == '__main__':
    main()