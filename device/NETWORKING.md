# LoRa Networking
LoRa is a network modulation technique [\[ref\]](https://en.wikipedia.org/wiki/LoRa). I like to think about it as the physical (ie. PHY) networking layer using the [OSI model](https://en.wikipedia.org/wiki/Network_layer). So we need to come up with our own [data link layer \(ie. MAC or LLC\)](https://en.wikipedia.org/wiki/Data_link_layer). We'll need to have some addressing scheme, and some flow control or acknowledgement that data was received since wireless networks are lossy.

## Packets
Ive defined the following structure for packets sent on the LoRa network:

| Bytes | Name |
----------------
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
3. send any priority packets
4. send a single regular packet

Since each node will undoubt