/*
 * SesameLoRa.h
 *  
 * LoRa class for the RFM95W based device
 */

#ifndef SesameLoRa_h
#define SesameLoRa_h

// C/C++ core includes
#include <map>
#include <deque>
#include <sstream>

// Arduino includes
#include <LoRa.h>
#include "Arduino.h"

// broadcast address for LoRa-based network
#define SESAME_BCAST 0xFF

// packet types
enum packet_type {
  ERROR, //unset
  BCAST, //broadcast
  ANNOUNCE, //announce
  ACK, //acknowledge a data packet
  SINGLE, // single packet message
  MULTI, // multi packet message
};

// packet structure for LoRa networking
typedef struct packet_t {
  unsigned char id; //packet ID
  unsigned char type; // packet type
  unsigned char from; //sender ID
  unsigned char to; //destination ID
  unsigned char length; // max payload size 255
  unsigned char* data;
} Packet;
// Packet {id, {BCAST, ANNOUNCE, ACK, SINGLE, MULTI}, SESAME_ID, to, len, data}

// status data for node in LoRa network
typedef struct node_t {
  unsigned char id;
  int rx_rssi; // from sending node (in radio)
  float rx_snr; // from sending node (in radio)
  int tx_rssi; // from receiving node (retransmitted in ACK)
  float tx_snr; // from receiving node (retransmitted in ACK)
  unsigned long last; // time last received something from this node
  unsigned long received; // count of packets received from this node
} Node;
// Node {id, rx_rssi, rx_snr, tx_rssi, tx_snr, last, received}

// quality data when sending ACK's
typedef struct quality_t {
    int rssi;
    float snr;
} Quality;

class SesameLoRa {
public:
  SesameLoRa() : pid(0), nextTx(0), nextAnnounce(0) {
    // initialize incoming IDs to SESAME_BCAST
    for(int i=0; i<16; i++) incoming_ids[i] = SESAME_BCAST;
  }
  
  //start the LoRa radio
  void start(unsigned char _id, std::string _name) {
    id = _id;
    name = _name;
    // setup LoRa radio
    LoRa.setPins(16, -1, 26);
    if (!LoRa.begin(915E6)) {
      Serial.println("Starting LoRa failed!");
      while (1);
    }
    LoRa.enableCrc();
  }

  // send a packet over LoRa
  void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data) {
    send(to, from, length, data, SINGLE, pid++);
  }
  
  // send a packet over LoRa
  void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
    //allocate & initialize the packet
    Packet* p = (Packet*)malloc(sizeof(Packet));
    if(p) {
      p->to = to;
      p->from = from;
      p->type = type;
      p->id = id;
      p->length = length;
      p->data = (unsigned char*)malloc(length);
      memcpy(p->data, data, length);
      // add packet to outgoing queue to be sent later
      outgoing.push_back(p);
      outgoing_retries.push_back(retries);
    } else {
      Serial.println("Unable to send packet");
    }
  }

  // send a priority packet
  void prioritySend(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
    //allocate & initialize the packet
    Packet* p = (Packet*)malloc(sizeof(Packet));
    if(p) {
      p->to = to;
      p->from = from;
      p->type = type;
      p->id = id;
      p->length = length;
      p->data = (unsigned char*)malloc(length);
      memcpy(p->data, data, length);
      // add packet to priority queue to be sent later          
      priority.push_front(p);
    } else {
      Serial.println("Unable to send priority packet");
    }
  }

  // send announcement packet
  void announce() {
    prioritySend(SESAME_BCAST, id, name.length(), (unsigned char*)name.c_str(), BCAST, 0);
  }
  
  // do LoRa networking process
  void do_network() {
    // get current time
    unsigned long current = millis();

    // try receiving for 10 times over 100ms or so
    for(int i=0; i<10; i++) {
      if(!_recv()) delay(10);
    }

    // announce for discovery
    if(current > nextAnnounce) {
      announce();
      nextAnnounce = current + announce_rate;
    }
    
    // send priority packets
    while(priority.size() > 0) {
      _sendPriority();
    }

    if(outgoing.size() > 0 && current > nextTx) {
      // wait between 100-<user cfg>ms between each packet
      nextTx = current + random(100, retry_delay);
      // send regular packet
      _send();
    }
  }

  // check if there is data received over LoRa
  bool hasData() {
    return incoming.size() > 0;
  }

  // get next data received over LoRa
  std::string getNextData() {
    if(hasData()) {
      Packet *p = incoming.front();
      // convert data to string
      std::string str((const char*)p->data, p->length);
      // clean up queue
      incoming.pop_front();
      free(p->data);
      free(p);
      
      return str;
    } else {
      return std::string();
    }
  }

  // get current LoRa network status as JSON
  std::string getNetworkInfo() {
    /*
     * JSON structure is:
     *   { ID : {stats}, ... }
     * for each node in the LoRa network
     */
    std::stringstream ss;
    ss <<  "{\n";
    for(auto &kv : nodes) {
      ss << "\t\"" << (int)kv.first << "\" : {";
      ss << "\"rx_rssi\" : " << kv.second.rx_rssi;
      ss << ", \"rx_snr\" : " << kv.second.rx_snr;
      ss << ", \"tx_rssi\" : " << kv.second.tx_rssi;
      ss << ", \"tx_snr\" : " << kv.second.tx_snr;
      ss << ", \"last\" : " << kv.second.last;
      ss << ", \"received\" : " << kv.second.received << "}\n";
    }
    ss << "}";
    return ss.str();
  }
    
private:
  // Sends a packet from queues, used internally
  void _send() {
    // get net packet to send
    Packet* p = outgoing.front();
    // check if there are any retries left for this packet
    if(outgoing_retries.front() == 0) {
      // failed to send this packet, drop it & clean up
      outgoing_failed.push_back(p->id);
      outgoing.pop_front();
      outgoing_retries.pop_front();
      
      free(p->data);
      free(p);
    } else {
      // try sending (again)
      outgoing_retries.front()--;
      // send out over LoRa radio
      LoRa.beginPacket();
      LoRa.write((unsigned char*)p,4);
      if(p->length > 0)
	LoRa.write(p->data, p->length);
      LoRa.endPacket();

      if(p->type == ACK or p->type == BCAST) {
	// only send ACK's or BCAST's once (no retries), clean up
	outgoing.pop_front();
	outgoing_retries.pop_front();
	
	free(p->data);
	free(p);
      }
    }
  }

  // send priority packet
  void _sendPriority() {
    // get next packet to send
    Packet* p = priority.front();
    // send out over LoRa radio
    LoRa.beginPacket();
    LoRa.write((unsigned char*)p,4);
    if(p->length > 0)
      LoRa.write(p->data, p->length);
    LoRa.endPacket();
           
    // only send once (no retries), clean up
    priority.pop_front();
    free(p->data);
    free(p);
  }
  
  // receives any packets if available, used internally
  bool _recv() {
    // check packet size on radio
    int packetSize = LoRa.parsePacket(); // size in bytes
    if (packetSize >= 4) { // packet must be at least 4 bytes
      // parse packet data into struct
      Packet* p = (Packet*)malloc(sizeof(Packet));
      p->id = LoRa.read();
      p->type = LoRa.read();
      p->from = LoRa.read();
      p->to = LoRa.read();
      // see if the packet has payload
      if(packetSize > 4) {
	// allocate space for payload & set length
	p->data = (unsigned char*)malloc(packetSize-4);
	p->length = packetSize-4;
	// copy data from radio into buffer
	for(int i=0; i<packetSize-4; i++) {
	  p->data[i] = LoRa.read();
	}
      } else {
	// packet does not have any payload
	p->data = 0;
	p->length = 0;
      }

      // handle packet appropriately
      _handlePacket(p);
      return true;
    }
    return false;
  }

  // process each packet
  void _handlePacket(Packet* p) {
    // get current time
    long unsigned current = millis();
    // get radio stats for this received packet
    int rssi = LoRa.packetRssi();
    float snr = LoRa.packetSnr();
    
    //update network
    if(nodes.count(p->from) > 0) {
      // update existing node
      Node &n = nodes[p->from];
      n.rx_rssi = rssi;
      n.rx_snr = snr;
      n.last = current;
      n.received++;
    } else {
      // first time seeing this node
      Node n = {p->from, rssi, snr, 0, -1, current, 1};
      nodes.emplace(p->from, n);
    }
    Node &n = nodes[p->from];
        
    // handle packet types
    if(p->type == ACK) {
      // try and match this ACK to one of the packets we sent previously
      if(outgoing.size() > 0) {
	Packet* dat = outgoing.front();
	if(p->id == dat->id &&
	   p->from == dat->to &&
	   p->to == dat->from) {
	  //match, packet sent/received successfully, remove packet
	  outgoing.pop_front();
	  outgoing_retries.pop_front();
	  
	  //update Tx quality to this node
	  Quality *q = (Quality*)p->data;
	  n.tx_rssi = q->rssi;
	  n.tx_snr = q->snr;
	}
      }
      // drop packet
      free(p->data);
      free(p);
    } else if(p->type == SINGLE) {
      // check if this packet has already been received to avoid duplicates
      bool found = false;
      for(int i=0; i<16; i++) {
	if(incoming_ids[i] == p->id) {
	  found = true;
	  break;
	}
      }
      if(!found) { // first time we see this packet, save it
	incoming.push_back(p);
	incoming_ids[incoming_ids_ptr]=p->id;
	incoming_ids_ptr = (incoming_ids_ptr+1)%16;
      }
      // send ack either way (so sender stops retrying)
      Quality* q = (Quality*)malloc(sizeof(Quality));
      q->rssi = rssi;
      q->snr = snr;
      prioritySend(p->from, p->to, 8, (unsigned char*)q, ACK, p->id);
    }
  }
  
#if 0
  // Prints a packet to serial terminal (for debug), used internally
  void printPacket(Packet* p) {
    Serial.print("Packet [id: ");
    Serial.print(p->id);
    Serial.print("  type: ");
    switch(p->type) {
    case BCAST:
      Serial.print("BCAST");
      break;
    case ANNOUNCE:
      Serial.print("ANCE");
      break;
    case ACK:
      Serial.print("ACK");
      break;
    case SINGLE:
      Serial.print("SNGL");
      break;
    case MULTI:
      Serial.print("MULT");
      break;
    default:
      Serial.print("ERR");
      break;
    }
    Serial.print("  from: ");
    Serial.print(p->from);
    Serial.print("  to: ");
    Serial.print(p->to);
    Serial.print("  data: ");
    if(p->type == ACK) {
      Quality *q = (Quality*)p->data;
      Serial.print("rssi: ");
      Serial.print(q->rssi);
      Serial.print("  snr: ");
      Serial.print(q->snr);
    } else {
      for(int i=0; i<p->length; i++)
	Serial.print((char)p->data[i]);
    }
    Serial.println(" ]");
  }
#endif

  // node info
  unsigned char id;
  std::string name; 

  // networking management
  unsigned char pid; // current packet ID
  unsigned long nextTx; // time to send next packet
  unsigned long nextAnnounce; // time to send next announcement
  
  // network info
  std::map<unsigned char, Node> nodes;
  
  // tx data structures
  std::deque<unsigned char> outgoing_ids; // IDs for packets to send
  std::deque<unsigned char> outgoing_retries; // retries left for each packet to send
  std::deque<Packet*> outgoing; // packet data to be sent
  std::deque<Packet*> priority; // packet data to be sent
  std::deque<unsigned char> outgoing_failed; // list of packets that failed to send (to be read by App)
  std::deque<unsigned char> outgoing_success; // list of packets that were sent successfully (to be read by App)

  // rx data structures
  std::deque<Packet*> incoming; // list of packets that were received (to be read by App)
  unsigned char incoming_ids[16]; // list of recently received packet IDs (circular buffer)
  unsigned char incoming_ids_ptr = 0; // index to put next ID into buffer
  
  // user configurable networking parameters
  int retries = 5; // number of retries during sending
  int retry_delay = 400; // max delay to wait between sending retries
  int announce_rate = 5000; // rate of sending announcements of this node (for discovery)
};

#endif /* SesameLoRa_h */
