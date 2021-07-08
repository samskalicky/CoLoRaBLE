# LoRa Networking
LoRa is a network modulation technique [\[ref\]](https://en.wikipedia.org/wiki/LoRa). I like to think about it as the physical (ie. PHY) networking layer using the [OSI model](https://en.wikipedia.org/wiki/Network_layer). So we need to come up with our own [data link layer \(ie. MAC or LLC\)](https://en.wikipedia.org/wiki/Data_link_layer). We'll need to have some addressing scheme, and some flow control or acknowledgement that data was received since wireless networks are lossy.

## Packets
Ive defined the following structure for packets sent on the LoRa network:

| Bytes | Name |
| ----- | ---- |
| 0 | Packet ID [0-254, 255 is reserved for broadcasts\] |
| 1 | Packet Type |
| 2 | From Node ID |
| 3 | To Node ID |
| 4 | Payload length (in bytes) |
| 5-N | Payload data |

where the Packet Types are:
- ERROR: error/unset
- BCAST: broadcast message (not ack'ed)
- ANNOUNCE: node announcing its presense (not ack'ed)
- ACK: acknowledgement packet (for a sent/received packet)
- SINGLE: single packet payload (all data fits in one packet -- less than 250 bytes)
- MULTI: multi packet payload (data is larger than 250 bytes)

## Addressing
Since the goal is for this LoRa network to be a mesh/distributed, there is no central server. Each node has a built-in unique ID (for now set manually when I program each board) and self-identifies. ID clashes shouldnt happen (except when I made misteaks -- or mischickens).

## Protocol
Since the RFM95W LoRa radio cannot detect collisions during transmission (it can detect collisions during receiving though) there is no way for the sender to know that it has collided and should retransmit. So we are not able to implement [Pure ALOHA](https://en.wikipedia.org/wiki/ALOHAnet#Pure_ALOHA) exactly. However we will reuse some of the concepts like random wait times between transmissions.

Each node runs the following state machine:
1. try receiving for 10 times for at least 100ms. If there is nothing to receive, wait 10ms and try again.
2. if its time, announce
3. send any priority packets (normally these are just ACKs to received packets)
4. send a single regular packet

When sending a regular packet (ie. message from the phone) we implement semi-reliable transmission by allowing 5 chances to have a receiver ACK the packet. After each attempt we wait a random delay (between 100-400ms) before we try again. This works as our backoff and random collision avoidance. Once we recieve an ACK for the packet, we remove it from the `outgoing` queue and move on to the next packet to transmit.

When receiving a packet we parse it into a data structure and than handle it accordingly. If we received an ACK, we try and match it with one of the packets we sent (as opposed to receiving an ACK from two other communicating nodes) and then make that packet as transmitted successfully. If we receive a regular packet for the first time, we enqueue an ACK to be sent out in the priority queue (so it doesnt get stuck behind other data packets we're trying to send).

Additionally, ACK packets also return the RSSI and SNR values of the receiving node to the transmitting node (so it can know how strong its signal is to this node). We also track the status of each node in the network we receive packets from.

Currently there is no mesh support, but its something that can be added. For now, point-to-point is all im interested in (since I only have 2 nodes anyway ;-p). 