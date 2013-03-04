Hardware traffic generator
==========================

This is a 10 Gbit/s Ethernet FPGA-based traffic generator. It is designed to be both flexible and extensible, and to be able to fill a 10Gb/s link, even with the smallest packets.

Environment
-----------

### Hardware

This implementation is tested with the [COMBO-LXT board](http://www.invea-tech.com/products-and-services/combo-fpga-boards/combo-lxt) with a [COMBOI-10G2](http://www.invea-tech.com/products-and-services/combo-fpga-boards/comboi-10g2) interface extension. The board must be plugged in a PCI port of a hosting machine.

As the implementation is made for [the NetCOPE platform](http://www.invea-tech.com/products-and-services/netcope-fpga-platform), it should work with few changes on any board supported by the platform, including the NetFPGA 10G. 

### Software

The VHDL code provided has no dependencies to the NetCOPE platform. You can simulate and synthesize the top _traffic\_generator_ module using just Xilinx ISE for example (tested with version 13). To use it on the board, integrate it in a NetCOPE _application.vhd_ file.

The C code has dependencies to the NetCOPE platform, it must be compiled on a platform with NetCOPE installed. A _Makefile_ is provided.

Directory structure
-------------------

This repository is divided into:
* _hw_, which contains the code that goes on the board;
* _sw_, which contains the code to control the board from the computer;
* _samples_, which contains a sample configuration.

The top file of the hardware code is _traffic\_generator.vhd_. It has to be included in _application.vhd_ and connected to a FrameLink bus that comes from DMA and goes to OBUF.

The _traffic\_generator_ program enables to send configuration from a configuration file (an example is available in the sample directory).

Development status
------------------

Currently, the generator works and sends traffic at the expected speed. Some modifier blocks will not be available on this repository until Mid-March because students are working on them for a project. If you need these files, send us an email.
