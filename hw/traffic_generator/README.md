Hardware traffic generator
===========================

Top: traffic_generator
---------------------------

`traffic_generator.vhd` is the top entity which should be instantiated. If you use NetCOPE, it should be instantiated in the `application.vhd` file.

Its interface is made of 2 FrameLink buses (one receiving and one sending) for configuration and generated data, and some signals to communicate with the computer.

Connection to the NetCOPE application is straightforward using the DMA FrameLink bus `RX0`, and the OBUF FrameLink bus `OBUF0`. Communication with the computer is done using memory-mapped registers: a read-only register for `status`, and a read/write register for `action`.

If you want to adapt it to NetFPGA 10G without using the NetCOPE platform, you will have to write adaptation modules to convert the NetFPGA buses into FrameLink buses. You can use memory-mapped registers for communication with the computer too.

Structure
-------------------

The traffic generator is a pipeline structured around the FrameLink bus. The pipeline splits into a configured number of parallel flow generators. Here is a typical generator structure:

* 	`traffic_generator.vhd`: top entity
	*	`frame_merger.vhd`: transforms received frames into parts of the same frame.
		This is a trick to be able to send frames with multiple parts from the computer, as NetCOPE does not simply allow that. Remove this if you do not use NetCOPE.
	*	`control.vhd`: receives configuration and actions from the computer and decides to which flow configuration should be sent. Also manages the start word and reconfiguration signal.
	*	`flow_merger.vhd`: receives multiple traffic flows and merges them into one.
	*	`flow_generator.vhd`: receives configuration for one flow, and sends traffic when it receives the start word. The number of instantiated flow generators is configurable.
		*	`modifiers/core/skeleton_sender`: receives a packet skeleton and a number of iterations in configuration, and sends one skeleton per iteration once the start word is received
		* 	Any kind of modifier in `modifiers/`
		*	`modifiers/ethernet_fcs.vhd`: overrides the Ethernet FCS field with the computed FCS for each received packet. This module is optional.
		*	`modifiers/core/config_remover.vhd`: drops the useless configuration frames and packet headers before they are sent as generated traffic.

Extending the generator
-------------------

Extending the generator usually consists in writing new modifiers in the `modifiers/` directory, and adding them to the flow generator.

Utilities
-------------------

Some utilities are available in the `utils/` directory, like single and dual-port RAM, a normal FIFO and a FIFO for the FrameLink bus and a CRC computation unit. Do not hesitate to use them if you need.