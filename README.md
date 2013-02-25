Hardware traffic generator
==========================

This is a 10 Gbit/s Ethernet FPGA-based traffic generator. It is designed to be both flexible and extensible, and to be able to fill a 10Gb/s link, even with the smallest packets.

Environment
-----------

This implementation is for the COMBO-LXT board with a COMBOI-10G2 interface extension.

Directory structure
-------------------

This repository is divided into:
* _hw_, which contains the code that goes on the board;
* _sw_, which contains the code to control the board from the computer;
* _sample_, which contains a sample configuration.

The top file of the hardware code is traffic\_generator.vhd. It has to be included in application.vhd and connected to a FrameLink bus that comes from DMA and goes to OBUF.

The traffic\_generator program enables to send configuration from a configuration file (an example is available in the sample directory).

Development status
------------------

Currently, the generator works and sends traffic at the expected speed. Some modifier blocks will not be available on this repository until Mid-March because students are working on them for a project. If you need these files, send us an email.
