//
//  SesameLoRa.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameLoRa_h
#define SesameLoRa_h
#include <map>
#include <deque>
#include <sstream>

#include <LoRa.h>
#include "Arduino.h"

#define SESAME_BCAST 0xFF

enum packet_type {
  ERROR, //unset
  BCAST, //broadcast
  ANNOUNCE, //announce
  ACK, //acknowledge a data packet
  SINGLE, // single packet message
  MULTI, // multi packet message
};

typedef struct packet_t {
  unsigned char id; //packet ID
  unsigned char type; // packet type
  unsigned char from; //sender ID
  unsigned char to; //destination ID
  unsigned char length; // max payload size 255
  unsigned char* data;
} Packet;
// Packet {id, {BCAST, ANNOUNCE, ACK, SINGLE, MULTI}, SESAME_ID, to, len, data}

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

typedef struct quality_t {
    int rssi;
    float snr;
} Quality;

class SesameLoRa {
public:
    SesameLoRa() : pid(0), nextTx(0), nextAnnounce(0) {
      for(int i=0; i<16; i++) incoming_ids[i] = -1;
    }
    
    void start(unsigned char _id, std::string _name) {
      id = _id;
      name = _name;
      // setup LoRa
      LoRa.setPins(16, -1, 26);
      if (!LoRa.begin(915E6)) {
        Serial.println("Starting LoRa failed!");
        while (1);
      }
      LoRa.enableCrc();
    }
    
    void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data) {
        send(to, from, length, data, SINGLE, pid++);
    }
    
    void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
        Packet* p = (Packet*)malloc(sizeof(Packet));
        if(p) {
          p->to = to;
          p->from = from;
          p->type = type;
          p->id = id;
          p->length = length;
          p->data = (unsigned char*)malloc(length);
          memcpy(p->data, data, length);
          
          outgoing.push_back(p);
          outgoing_retries.push_back(retries);
        } else {
          Serial.println("Unable to send packet");
        }
    }
    
    void prioritySend(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
        Packet* p = (Packet*)malloc(sizeof(Packet));
        if(p) {
          p->to = to;
          p->from = from;
          p->type = type;
          p->id = id;
          p->length = length;
          p->data = (unsigned char*)malloc(length);
          memcpy(p->data, data, length);
          
          priority.push_front(p);
        } else {
          Serial.println("Unable to send priority packet");
        }
    }

    void announce() {
      prioritySend(SESAME_BCAST, id, name.length(), (unsigned char*)name.c_str(), BCAST, 0);
    }
    
    void do_network() {
        unsigned long current = millis();

        for(int i=0; i<10; i++) {
            if(!_recv()) delay(10);
        }

        //Announce for discovery
        if(current > nextAnnounce) {
            announce();
            nextAnnounce = current + announce_rate;
        }

        // send Tx packets
        while(priority.size() > 0) {
            _sendPriority();
        }
        if(outgoing.size() > 0 && current > nextTx) {
        nextTx = current + random(100, retry_delay); //wait between 50-300ms
            _send();
        }
    }
    
    bool hasData() {
        return incoming.size() > 0;
    }
    
    std::string getNextData() {
        if(hasData()) {
            Packet *p = incoming.front();
            std::string str((const char*)p->data, p->length);
            incoming.pop_front();
            free(p->data);
            free(p);
            return str;
        } else {
            return std::string();
        }
    }

    std::string getNetworkInfo() {
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
    /*
     * Sends a packet from queues, used internally
     */
    void _send() {
        Packet* p = outgoing.front();
        if(outgoing_retries.front() == 0) {//send failed
            outgoing_failed.push_back(p->id);
            outgoing.pop_front();
            outgoing_retries.pop_front();
            
            free(p->data);
            free(p);
        } else {
            outgoing_retries.front()--;
            LoRa.beginPacket();
            LoRa.write((unsigned char*)p,4);
            if(p->length > 0)
              LoRa.write(p->data, p->length);
            LoRa.endPacket();
            
            if(p->type == ACK or p->type == BCAST) {
                outgoing.pop_front();
                outgoing_retries.pop_front();
                
                free(p->data);
                free(p);
            }
        }
    }
    
    void _sendPriority() {
        Packet* p = priority.front();
        LoRa.beginPacket();
        LoRa.write((unsigned char*)p,4);
        if(p->length > 0)
          LoRa.write(p->data, p->length);
        LoRa.endPacket();
           
        priority.pop_front();
        free(p->data);
        free(p);
    }
    
    /*
     * Receives any packets if available, used internally
     */
    bool _recv() {
      int packetSize = LoRa.parsePacket();
      if (packetSize >= 4) {
        // parse packet data into struct
        Packet* p = (Packet*)malloc(sizeof(Packet));
        p->id = LoRa.read();
        p->type = LoRa.read();
        p->from = LoRa.read();
        p->to = LoRa.read();
        if(packetSize > 4) {
          p->data = (unsigned char*)malloc(packetSize-4);
          p->length = packetSize-4;
          for(int i=0; i<packetSize-4; i++) {
            p->data[i] = LoRa.read();
          }
        } else {
          p->data = 0;
          p->length = 0;
        }
        _handlePacket(p);
          return true;
      }
        return false;
    }
    
    void _handlePacket(Packet* p) {
      long unsigned current = millis();
      // update network info
      int rssi = LoRa.packetRssi();
      float snr = LoRa.packetSnr();

      //update network
      if(nodes.count(p->from) > 0) {
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
              //match, remove packet
              outgoing.pop_front();
              outgoing_retries.pop_front();

              //update Tx quality
              Quality *q = (Quality*)p->data;
              n.tx_rssi = q->rssi;
              n.tx_snr = q->snr;
          }
        }
        free(p->data);
        free(p);
      } else if(p->type == SINGLE) {
        //check if this packet has already been received
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
        //send ack either way
        Quality* q = (Quality*)malloc(sizeof(Quality));
        q->rssi = rssi;
        q->snr = snr;
        prioritySend(p->from, p->to, 8, (unsigned char*)q, ACK, p->id);
      }
    }
    
    /*
     * Prints a packet to serial terminal (for debug), used internally
     */
#if 0
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

    //node info
    unsigned char id;
    std::string name; 

    unsigned char pid; // current packet ID
    unsigned long nextTx;
    unsigned long nextAnnounce;
    
    // Network info
    std::map<unsigned char, Node> nodes;
    unsigned long receivedAt = 0;

    //Tx data structures
    std::deque<unsigned char> outgoing_ids; // IDs for packets to send
    std::deque<unsigned char> outgoing_retries; // retries left for each packet to send
    std::deque<Packet*> outgoing; // packet data to be sent
    std::deque<Packet*> priority; // packet data to be sent
    std::deque<unsigned char> outgoing_failed; // list of packets that failed to send (to be read by App)
    std::deque<unsigned char> outgoing_success; // list of packets that were sent successfully (to be read by App)

    // Rx data structures
    std::deque<Packet*> incoming; // list of packets that were received (to be read by App)
    unsigned char incoming_ids[16]; // list of recently received packets 
    unsigned char incoming_ids_ptr=0;

    // User configurable networking parameters
    int retries=5; // number of retries during sending
    int retry_delay=400; // max delay to wait between retries
    int announce_rate=5000; // rate of sending announcements of this node (for discovery)
};

#endif /* SesameLoRa_h */
