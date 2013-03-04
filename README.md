Hardware traffic generator
==========================

This is a 10 Gbit/s Ethernet FPGA-based traffic generator. It is designed to be both flexible and extensible, and to be able to fill a 10Gb/s link, even with the smallest packets.

Environment
-----------

### Hardware

This implementation is tested with the [COMBO-LXT board](http://www.invea-tech.com/products-and-services/combo-fpga-boards/combo-lxt) with a [COMBOI-10G2](http://www.invea-tech.com/products-and-services/combo-fpga-boards/comboi-10g2) interface extension. The board must be plugged in a PCI port of a hosting machine.

As the implementation is made for [the NetCOPE platform](http://www.invea-tech.com/products-and-services/netcope-fpga-platform), it should work with few changes on any board supported by the platform, including the NetFPGA 10G. 

### Software

The VHDL code provided has no dependencies to the NetCOPE platform. You can simulate and synthesize the top `traffic_generator` entity using just Xilinx ISE for example (tested with version 13). To use it on the board, integrate it in a NetCOPE `application.vhd` file.

The C code has dependencies to the NetCOPE platform, it must be compiled on a platform with NetCOPE installed. A `Makefile` is provided.

Directory structure
-------------------

This repository is divided into:

* `hw`, which contains the code that goes on the board;
* `sw`, which contains the code to control the board from the computer;
* `samples`, which contains a sample configuration.

The top file of the hardware code is `traffic_generator.vhd`. It has to be included in `application.vhd` and connected to a FrameLink bus that comes from DMA and goes to OBUF.

The `traffic_generator` program enables to send configuration from a configuration file (an example is available in the sample directory).

Development status
------------------

Currently, the generator works and sends traffic at the expected speed. Some modifier blocks will not be available on this repository until Mid-March because students are working on them for a project. If you need these files, send us an email.

Documentation is at an early stage, so if you have trouble understanding how to use or extend the generator, do not hesitate to send us an email.