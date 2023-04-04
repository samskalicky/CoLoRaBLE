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

#include "SesameGPS.h"
#include "SesameEnv.h"
#include "SesameBatt.h"

#define SESAME_BCAST 0xFF
#define SESAME_MAGIC_NUMBER 0x42

enum packet_type {
  ERROR=0, //unset
  BCAST=1, //broadcast
  ANNOUNCE=2, //announce
  ACK=3, //acknowledge a data packet
  SINGLE=4, // single packet message
  MULTI=5, // multi packet message
};

typedef struct packet_t {
  unsigned char magic_num;
  unsigned char id; //packet ID
  unsigned short checksum;
  unsigned char type; // packet type
  unsigned char from; //sender ID
  unsigned char to; //destination ID
  unsigned char length; // max payload size 255
  unsigned char* data;
} Packet;
// Packet {id, {BCAST, ANNOUNCE, ACK, SINGLE, MULTI}, SESAME_ID, to, len, data}

typedef struct data_t {
  float latitude;
  float longitude;
  float gps_altitude;
  float temperature;
  float pressure;
  float humidity;
  float pressure_altitude;
  float current;
  float voltage;
} Node_Data;

typedef struct node_t {
  unsigned char id;
  int rx_rssi; // from sending node (in radio)
  float rx_snr; // from sending node (in radio)
  int tx_rssi; // from receiving node (retransmitted in ACK)
  float tx_snr; // from receiving node (retransmitted in ACK)
  unsigned long last; // time last received something from this node
  unsigned long received; // count of packets received from this node
  Node_Data data;
} Node;
// Node {id, rx_rssi, rx_snr, tx_rssi, tx_snr, last, received}

typedef struct quality_t {
    int rssi;
    float snr;
} Quality;

typedef void(*LoRaCallback)(int);

class SesameLoRa {  
public:
    SesameLoRa();

    void setPeriphs(SesameGPS *gps_, SesameEnv *env_, SesameBatt *batt_);
    
    void start(unsigned char _id, std::string _name, LoRaCallback callback);

    void handleIRQ(int packetSize);

    void update();
    
    void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data);
    
    void send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id);
    
    void prioritySend(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id);

    void announce();
    
    void do_network();
    
    bool hasData();
    
    std::string getNextData();

    std::string getMessages();

    void printNode_Data(Node_Data &data);

    std::string getNetworkInfo();

    std::string getNodeData();

    std::string getRadioConfig();
    
private:
    /*
     * Sends a packet from queues, used internally
     */
    void _send();
    
    void _sendPriority();

    
    /*
     * Receives any packets if available, used internally
     */
    void _recv();

    Packet* getPacket(int packetSize);
    
    void _handlePacket(Packet* p);

    unsigned short compute_checksum(Packet* packet);

    /*
     * Prints a packet to serial terminal (for debug), used internally
     */
    void printPacket(Packet* p);

    //node info
    unsigned char id;
    std::string name; 

    SesameGPS *gps;
    SesameEnv *env;
    SesameBatt *batt;

    Node_Data data;

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
    std::deque<Packet*> raw_packets; // list of raw packet data stored in ISR
    std::deque<Packet*> incoming; // list of packets that were received (to be read by App)
    unsigned char incoming_ids[16]; // list of recently received packets 
    unsigned char incoming_ids_ptr=0;

    // User configurable networking parameters
    int retries=5; // number of retries during sending
    int retry_delay=400; // max delay to wait between retries
    int announce_rate; // rate of sending announcements of this node (for discovery)
    int radioSpreadFactor, radioCodingRate, radioTxPower, radioTxPin;
    float radioBandwidth;
};

#endif /* SesameLoRa_h */
