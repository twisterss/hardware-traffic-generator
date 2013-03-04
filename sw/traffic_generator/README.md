traffic_generator tool
==========================

Usage
--------------------------
This tool allows to control the traffic generator.
Two methods are used to contol the board:

*       actions and statuses are handled using memory-mapped registers
*       configuration data is sent as packets to the sze0 interface

Possible actions:

*       `status`: display the current status of the generator
*       `config config_file_path`: send the configuration in the specified file to the board
*       `start`: start sending traffic
*       `reset`: forget current configuration and stop sending

### Command-line

```./traffic_generator [action] [config_file_path]```

*       `action`: `status`|`config`|`start`|`reset` (default: `status`)
*       `config_file_path`: path to a file with the configuration to send
        Format of the file is the same as for simulation
        Valid only with action "config"

Compilation
--------------------------
The NetCOPE environment must be installed on the machine. Just run `make` to compile.