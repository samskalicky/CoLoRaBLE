//
//  SesameLoRa.cpp
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#include "SesameLoRa.h"

    SesameLoRa::SesameLoRa() : pid(0), nextTx(0), nextAnnounce(0) {
      for(int i=0; i<16; i++) incoming_ids[i] = -1;
      
      radioSpreadFactor = 8;
      radioCodingRate = 8;
      radioBandwidth = 125E3;
      radioTxPower = 14;
      radioTxPin = PA_OUTPUT_RFO_PIN;

      announce_rate = 5000; //milliseconds
    }

    void SesameLoRa::setPeriphs(SesameGPS *gps_, SesameEnv *env_, SesameBatt *batt_) {
      gps = gps_;
      env = env_;
      batt = batt_;
    }
    
    void SesameLoRa::start(unsigned char _id, std::string _name, LoRaCallback callback) {
      id = _id;
      name = _name;
      
      // setup LoRa
      LoRa.setPins(16, 19, 26);
      if (!LoRa.begin(915E6)) {
        Serial.println("Starting LoRa failed!");
        while (1);
      }
      
      LoRa.onReceive(callback);
      LoRa.enableCrc();

      LoRa.setSpreadingFactor(radioSpreadFactor);
      LoRa.setSignalBandwidth(radioBandwidth);
      LoRa.setCodingRate4(radioCodingRate);
      LoRa.setTxPower(radioTxPower, radioTxPin); //[PA_OUTPUT_RFO_PIN, PA_OUTPUT_PA_BOOST_PIN]
      
      LoRa.receive();

      esp_sleep_enable_timer_wakeup(announce_rate * 1000); // wakeup esp32 (rate in microseconds, convert from milliseconds from announce rate)
      
    }

    void SesameLoRa::handleIRQ(int packetSize) {
      Packet* p = getPacket(packetSize);
      if(p) raw_packets.push_back(p);
    }

    void SesameLoRa::update() {
      data.latitude = gps->latitude;
      data.longitude = gps->longitude;
      data.gps_altitude = gps->altitude;
      data.temperature = env->temperature;
      data.pressure = env->pressure;
      data.humidity = env->humidity;
      data.pressure_altitude = env->altitude;
      data.current = batt->current;
      data.voltage = batt->voltage;
    }
    
    void SesameLoRa::send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data) {
      send(to, from, length, data, SINGLE, pid++);
    }
    
    void SesameLoRa::send(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
      Packet* p = (Packet*)malloc(sizeof(Packet));
      if(p) {
        p->magic_num = SESAME_MAGIC_NUMBER;
        p->id = id;
        p->checksum = 0;
        p->type = type;
        p->from = from;
        p->to = to;
        p->length = length;
        p->data = (unsigned char*)malloc(length);
        memcpy(p->data, data, length);

        p->checksum = compute_checksum(p);
        outgoing.push_back(p);
        outgoing_retries.push_back(retries);
      } else {
        Serial.println("Unable to send packet");
      }
    }
    
    void SesameLoRa::prioritySend(unsigned char to, unsigned char from, unsigned char length, unsigned char* data, unsigned char type, unsigned char id) {
        Packet* p = (Packet*)malloc(sizeof(Packet));
        if(p) {
          p->magic_num = SESAME_MAGIC_NUMBER;
          p->id = id;
          p->checksum = 0;
          p->type = type;
          p->from = from;
          p->to = to;
          p->length = length;
          p->data = (unsigned char*)malloc(length);
          memcpy(p->data, data, length);

          p->checksum = compute_checksum(p);
          
          priority.push_front(p);
        } else {
          Serial.println("Unable to send priority packet");
        }
    }

    void SesameLoRa::announce() {
      prioritySend(SESAME_BCAST, id, sizeof(Node_Data), (unsigned char*)&data, ANNOUNCE, pid++);
    }
    
    void SesameLoRa::do_network() {
        unsigned long current = millis();

        // process any packets received (in ISR)
        while(raw_packets.size() > 0) {
          _recv();
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
    
    bool SesameLoRa::hasData() {
        return incoming.size() > 0;
    }

    std::string SesameLoRa::getMessages() {
      std::stringstream ss;
      ss <<  "[\n";
      int cnt = 0;
      for(Packet *p : incoming) {
        ss << " {";
        ss << " \"from\" : " << p->from;
        std::string str((const char*)p->data, p->length);
        ss << ", \"msg\" : \"" << str << "\"";
        ss << "}";
        if(++cnt < incoming.size())
          ss << ",\n";
        else
          ss << "\n";
      }
      ss << "]";

      for(int i=0; i<cnt; i++)
        incoming.pop_front();
      
      return ss.str();
    }
    
    std::string SesameLoRa::getNextData() {
        if(hasData()) {
            Packet *p = incoming.front();
            std::stringstream ss;
            ss << (unsigned char)p->to;
            std::string str((const char*)p->data, p->length);
            ss << str;
            incoming.pop_front();
            free(p->data);
            free(p);
            return ss.str();
        } else {
            return std::string();
        }
    }

    std::string SesameLoRa::getNetworkInfo() {
      std::stringstream ss;
      ss <<  "{\n";
      int cnt = 0;
      for(auto &kv : nodes) {
        ss << "\t\"" << (int)kv.first << "\" : {";
        ss << "\"rx_rssi\" : " << kv.second.rx_rssi;
        ss << ", \"rx_snr\" : " << kv.second.rx_snr;
        ss << ", \"tx_rssi\" : " << kv.second.tx_rssi;
        ss << ", \"tx_snr\" : " << kv.second.tx_snr;
        ss << ", \"last\" : " << kv.second.last;
        ss << ", \"received\" : " << kv.second.received;
        ss << ", \"position\" : \"" << kv.second.data.latitude << ", " << kv.second.data.longitude << "\"";
        ss << ", \"gps_altitude\" : " << kv.second.data.gps_altitude;
        ss << ", \"temperature\" : " << kv.second.data.temperature;
        ss << ", \"pressure\" : " << kv.second.data.pressure;
        ss << ", \"humidity\" : " << kv.second.data.humidity;
        ss << ", \"pressure_altitude\" : " << kv.second.data.pressure_altitude;
        ss << ", \"current\" : " << kv.second.data.current;
        ss << ", \"voltage\" : " << kv.second.data.voltage;
        ss << "}";
        if(++cnt < nodes.size())
          ss << ",\n";
        else
          ss << "\n";
      }
      ss << "}";
      return ss.str();
    }

    std::string SesameLoRa::getNodeData() {
      std::stringstream ss;
      ss << "{ \"position\" : \"" << data.latitude << ", " << data.longitude << "\"";
      ss << ", \"gps_altitude\" : " << data.gps_altitude;
      ss << ", \"temperature\" : " << data.temperature;
      ss << ", \"pressure\" : " << data.pressure;
      ss << ", \"humidity\" : " << data.humidity;
      ss << ", \"pressure_altitude\" : " << data.pressure_altitude;
      ss << ", \"current\" : " << data.current;
      ss << ", \"voltage\" : " << data.voltage << " }";

      return ss.str();
    }

    std::string SesameLoRa::getRadioConfig() {
      std::stringstream ss;
      ss << "{ \"spreadfactor\" : " << radioSpreadFactor;
      ss << ", \"codingrate\" : " << radioCodingRate;
      ss << ", \"bandwidth\" : " << radioBandwidth;
      ss << ", \"txpower\" : " << radioTxPower;
      ss << ", \"txpin\" : " << radioTxPin;
      ss << ", \"announce\" : " << announce_rate << " }";

      return ss.str();
    }
    
    void SesameLoRa::_send() {
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
            LoRa.write((unsigned char*)p,8);
            if(p->length > 0)
              LoRa.write(p->data, p->length);
            LoRa.endPacket();

            // go back into receive mode until next transmission
            LoRa.receive();
            
            if(p->type == ACK or p->type == BCAST) {
                outgoing.pop_front();
                outgoing_retries.pop_front();
                
                free(p->data);
                free(p);
            }
        }
    }
    
    void SesameLoRa::_sendPriority() {
        Packet* p = priority.front();
        LoRa.beginPacket();
        LoRa.write((unsigned char*)p,8);
        if(p->length > 0)
          LoRa.write(p->data, p->length);
        LoRa.endPacket();

        // go back into receive mode until next transmission
        LoRa.receive();
           
        priority.pop_front();
        free(p->data);
        free(p);
    }

    void SesameLoRa::_recv() {
      Packet* p = raw_packets.front();
      _handlePacket(p);
      raw_packets.pop_front();
    }

    Packet* SesameLoRa::getPacket(int packetSize) {
      if (packetSize >= 8) {
        // parse packet data into struct
        Packet* p = (Packet*)malloc(sizeof(Packet));
        p->magic_num = LoRa.read();
        p->id = LoRa.read();
        p->checksum = LoRa.read();
        p->checksum |= LoRa.read() << 8;
        p->type = LoRa.read();
        p->from = LoRa.read();
        p->to = LoRa.read();
        p->length = LoRa.read();
        p->data = 0;

        if(packetSize > 8) {
          p->data = (unsigned char*)malloc(packetSize-8);
          for(int i=0; i<packetSize-8; i++) {
            p->data[i] = LoRa.read();
          }
        }

        // check for valid packet
        if(p->magic_num != SESAME_MAGIC_NUMBER ||
           compute_checksum(p) != p->checksum) {
            free(p);
            return 0;
        }
        return p;
      }
      return 0;
    }
    
    void SesameLoRa::_handlePacket(Packet* p) {
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
        Node n;
        n.id = p->from;
        n.rx_rssi = rssi;
        n.rx_snr = snr;
        n.tx_rssi = 0;
        n.tx_snr = -1;
        n.last = current;
        n.received = 1;
        n.data.latitude = 0;
        n.data.longitude = 0;
        n.data.gps_altitude = 0;
        n.data.temperature = 0;
        n.data.pressure = 0;
        n.data.humidity = 0;
        n.data.pressure_altitude = 0;
        n.data.current = 0;
        n.data.voltage = 0;
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
      } else if(p->type == ANNOUNCE) {
        // store node data for this node
        memcpy(&(n.data), p->data, p->length);
      } else if(p->type == SINGLE) {
        //only look at this packet if its a broadcast or its for me
        if (p->to == SESAME_BCAST || p->to == id) {
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
    }

    unsigned short SesameLoRa::compute_checksum(Packet* packet) {
      unsigned short checksum = 0;
      unsigned short saved = packet->checksum;
      packet->checksum = 0;
      //packet metadata
      unsigned char* data = (unsigned char*)packet;
      for(int i=0; i<8; i++) {
        checksum += data[i];
      }
      //packet data
      for(int i=0; i<packet->length; i++) {
        checksum += packet->data[i];
      }
      packet->checksum = saved;
      return checksum;
    }

    
#if 0
    void SesameLoRa::printNode_Data(Node_Data &data) {
      std::stringstream ss;
      ss << "Data:[";
      ss << "\"position\" : \"" << data.latitude << ", " << data.longitude << "\"";
      ss << ", \"gps_altitude\" : " << data.gps_altitude;
      ss << ", \"temperature\" : " << data.temperature;
      ss << ", \"pressure\" : " << data.pressure;
      ss << ", \"humidity\" : " << data.humidity;
      ss << ", \"pressure_altitude\" : " << data.pressure_altitude;
      ss << ", \"current\" : " << data.current;
      ss << ", \"voltage\" : " << data.voltage;

      Serial.println(ss.str().c_str());
    }
    
    void SesameLoRa::printPacket(Packet* p) {
      Serial.print("Packet [");
      Serial.print("magic: ");
      Serial.print(SESAME_MAGIC_NUMBER);
      Serial.print(" | ");
      Serial.print(p->magic_num);
      Serial.print("  id: ");
      Serial.print(p->id);
      Serial.print("  chksm: ");
      Serial.print(p->checksum);
      Serial.print(" | ");
      Serial.print(compute_checksum(p));
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
 
