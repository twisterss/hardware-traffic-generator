#!/bin/bash
# Show what has been recieved as one word on the FrameLink bus
# Should go to the next word except if no more word has been received.

echo "Word counter: "
csbus 0x80008
echo "drem: "
csbus 0x8000C
echo "SOF (8), EOF (4), SOP (2), EOP (1): "
csbus 0x80010
echo "data(63, 32): "
csbus 0x80014
echo "data(31, 0): "
csbus 0x80018

# Go to the next word if any
csbus 0x8001C 0
sleep 0.1
csbus 0x8001C 1
