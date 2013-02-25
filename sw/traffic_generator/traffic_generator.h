/**
 * Main file of the traffic generator.
 * Manages communication with the traffic generator.
 */

#include <stdio.h>
/**
 * Maximum number of bytes of a sent frame 
 */
#define MAX_FRAME_SIZE 2000
/**
 * Maximum number of bytes of a sent frame 
 */
#define MAX_HW_SIZE 32
/**
 * Number of the sze interface
 */
#define SZE_RX_INTF 0
/**
 * Generator memory base address 
 */
#define GEN_BASE_ADDR 0x80000
/**
 * Generator memory word size
 */
#define GEN_WORD_SIZE 0x0100
/**
 * Generator status address
 */
#define GEN_ADDR_STATUS 0x0000
/**
 * Generator action address
 */
#define GEN_ADDR_ACTION 0x0004

typedef enum {
    ACT_UNKNOWN,
    ACT_STATUS,
    ACT_CONFIG,
    ACT_START,
    ACT_RESET
} action_t;

/**
 * Sends the configuration in the file at config_path
 * to the generator
 */
int send_config(const char* config_path);

/**
 * Sends a new action to realize for the generator
 */
int send_action(int action);

/**
 * Reads and displays the current status of the generator
 */
int read_status();

/**
 * Read one frame in the configuration file.
 * Provided lengths should be the size of the buffers.
 * Puts the actual data size in the lengths.
 * Returns 0 if a frame was available.
 * Returns 1 if no frame was available.
 * Returns 2 if there was an error reading the frame.
 */
int read_frame(FILE* file, char* hw_data, size_t* hw_data_len, char* data, size_t* data_len);

/**
 * Print some data in hexadecimal format
 */
void print_data(char* data, size_t data_len);

/**
 * Main function
 */
int main(int argc, char **argv);

/**
 * Print some help
 */
void usage();
