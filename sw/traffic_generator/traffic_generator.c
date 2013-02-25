#include "traffic_generator.h"

#include <stdlib.h>
#include <string.h>
#include <libsze2.h>
#include <combosix.h>

int read_frame(FILE* file, char* hw_data, size_t* hw_data_len, char* data, size_t* data_len) {
    char* hw_data_ptr = hw_data;
    char* data_ptr = data;
    char** current_ptr = &hw_data_ptr;
    char line[1024];
    char char_val[3];
    char_val[2] = '\0';
    char frame_ok = 0;
    int i;
    // Read the file until an end of frame is found
    while (fgets(line, sizeof(line), file) != NULL)
    {
        char value[1024] = "";
        int result = sscanf(line, "%8[$#0123456789ABCDEF]", value);
        if (result != 1)
            continue;
        if (value[0] == '$') {
            // End of part
            current_ptr = &data_ptr;
            continue;
        } else if (value[0] == '#') {
            // End of frame
            frame_ok = 1;
            break;
        }
        for (i = 3; i >= 0; i--) {
            char_val[0] = value[i*2];
            char_val[1] = value[i*2+1];
            sscanf(char_val, "%hhx", *current_ptr);
            (*current_ptr)++;
        }
    }
    // Update the frame size
    *hw_data_len = hw_data_ptr - hw_data;
    *data_len = data_ptr - data;
    // Check the return status
    if (frame_ok && current_ptr == &data_ptr)
        // Frame read
        return 0;
    else if (!frame_ok)
        // No frame
        return 1;
    else
        // Corrupted frame (no hardware part)
        return 2;
}

void print_data(char* data, size_t data_len) {
    int i;
    for (i = 0; i < data_len; i++) {
        printf("%02hhX", data[i]);
        if (i % 4 == 3)
            printf("\n");
    }
    printf("\n");
}

int main(int argc, char **argv) {

    // Parse the arguments
    int valid = 1;
    action_t action = ACT_UNKNOWN;
    char* config_path;
    if (argc >= 2) {
        char* action_str = argv[1];
        if (strcmp(action_str, "status") == 0)
            action = ACT_STATUS;
        else if (strcmp(action_str, "config") == 0)
            action = ACT_CONFIG;
        else if (strcmp(action_str, "start") == 0)
            action = ACT_START;
        else if (strcmp(action_str, "reset") == 0)
            action = ACT_RESET;
    } else {
        action = ACT_STATUS;
    }

    if (action == ACT_CONFIG) {
        if (argc == 3)
            config_path = argv[2];
        else
            valid = 0;
    }
    else if (action != ACT_UNKNOWN) {
        if (argc > 2)
            valid = 0;
    } else {
        valid = 0;
    }

    // Display the help if there is a problem
    if (valid == 0) {
        usage();
        return 1;
    }

    // Realize the action
    if (action == ACT_CONFIG)
        return send_config(config_path);
    else if (action == ACT_START)
        return send_action(1);
    else if (action == ACT_RESET)
        return send_action(2);
    else if (action == ACT_STATUS)
        return read_status();
    
}

int send_config(const char* config_path) {

    // Open the configuration file
    FILE* config_file = fopen(config_path, "r");
    if (config_file == NULL) {
        printf("The configuration file cannot be read.\n");
        return 1;
    }

    // Initialize the szedata connection
    struct szedata *sze = NULL;
    char *sze_dev = "/dev/szedataII0";
    unsigned int rx = 0x00, tx = 0x01;
    sze = szedata_open(sze_dev);
    if (sze == NULL)
        printf("szedata open error\n");
    if (szedata_subscribe3(sze, &rx, &tx))
        printf("szedata subscribe error\n");
    if (szedata_start(sze))
        printf("szedata start error\n");

    // Read the configuration frame by frame
    int read_ok = 1;
    int read_status;
    char hw_data[MAX_HW_SIZE], data[MAX_FRAME_SIZE];
    size_t hw_data_len, data_len;
    int sent_frames = 0;
    while (read_ok) {
        read_status = read_frame(config_file, hw_data, &hw_data_len, data, &data_len);
        if (read_status != 0) {
            read_ok = 0;
            if (read_status != 1)
                printf("There was an error while reading the configuration.\n");
            break;
        }
        // Send data
        char sent = 0;
        while (!sent) {
            int result = szedata_prepare_and_try_write_next(sze, hw_data, hw_data_len, data, data_len, SZE_RX_INTF);

            if (result == 0) {
                sent = 1;
            } else if(result == 1) {
                printf("Retrying to send a frame.\n");
                short events = SZEDATA_POLLTX;
                if(szedata_poll(sze, &events, 5000000) < 0) {
                    printf("szedata poll error\n");
                    break;
                }
            } else {
                printf("szedata write error\n");
                break;
            }
        }
        if (!sent) {
            printf("Impossible to send a configuration frame.\n");
            break;
        }
        printf ("Sent frame (hardware: %d bytes, data: %d bytes)\n", hw_data_len, data_len);
        //print_data(hw_data, hw_data_len);
        //print_data(data, data_len);
        sent_frames++;
    }

    printf("Sent %d frames.\n", sent_frames);

    // Close the szedata connection
    szedata_close(sze);
    // Close the configuration file
    fclose(config_file);
    return 0;
}

int send_action(int action) {
    char *file = CS_PATH_DEV(0);
    cs_device_t *dev;
    cs_space_t *ibuf_space; 

    // Open the interface
    if (cs_attach_noex(&dev, file) != 0) {
        printf("Impossible to attach to the combo card.\n");
        return 1;
    }
    if (cs_space_map(dev, &ibuf_space, CS_SPACE_FPGA, GEN_WORD_SIZE, GEN_BASE_ADDR, 0) != 0) {
        printf("Impossible to map the generator memory.\n");
        return 1;
    }

    // Write the action
    cs_space_write_4(dev, ibuf_space, GEN_ADDR_ACTION, action);


    printf("Sent action %d\n", action);

    // Close the interface
    cs_space_unmap(dev, &ibuf_space);
    cs_detach(&dev);
}

int read_status() {
    char *file = CS_PATH_DEV(0);
    cs_device_t *dev;
    cs_space_t *ibuf_space; 

    // Open the interface
    if (cs_attach_noex(&dev, file) != 0) {
        printf("Impossible to attach to the combo card.\n");
        return 1;
    }
    if (cs_space_map(dev, &ibuf_space, CS_SPACE_FPGA, GEN_WORD_SIZE, GEN_BASE_ADDR, 0) != 0) {
        printf("Impossible to map the generator memory.\n");
        return 1;
    }

    // Read the status
    uint32_t status = cs_space_read_4(dev, ibuf_space, GEN_ADDR_STATUS);
    uint32_t action = cs_space_read_4(dev, ibuf_space, GEN_ADDR_ACTION);

    // Print the current status
    char* generator_status;
    if (status == 1)
        generator_status = "receiving configuration";
    else if (status == 2)
        generator_status = "fully configured";
    else if (status == 3)
        generator_status = "sending traffic";
    else if (status == 4)
        generator_status = "finished";
    else
        generator_status = "unknown";
    printf("Current status: %s\n", generator_status);

    char* pending_action;
    if (action == 1)
        pending_action = "start";
    else if (action == 2)
        pending_action = "reset";
    else
        pending_action = "unknown";
    if (action != 0)
        printf("Pending action: %s\n", pending_action);

    // Close the interface
    cs_space_unmap(dev, &ibuf_space);
    cs_detach(&dev);
}

void usage() {
    printf(""
        "This tool allows to control the traffic generator.\n"
        "Configuration is sent from a file with the format of simulation files.\n"
        "\n"
        "Usage:\n"
        "./traffic_generator [action] [config_file_path]\n"
        "\n"
        "   action: status|config|start|reset (default: status)\n"
        "   config_file_path: path to a file with the configuration to send.\n"
        "       Format of the file is the same as for simulation.\n"
        "       Valid only with action \"config\".\n"
    );
}
