
#include <WaspSX1272.h>

uint8_t gw_address = 1;
uint8_t devAddr = 2;
int8_t e;
char NwKey[] = "AB1234";
uint8_t NwKeyB[3] = {0xAB, 0x12, 0x34};
char buffer_up[200];
uint8_t join_request[10];

void setup()
{
  USB.ON();
  sx1272.ON();

  e = sx1272.setChannel(CH_10_868);

  e = sx1272.setHeaderON();

  e = sx1272.setMode(1);  
  
  e = sx1272.setCRC_ON();

  e = sx1272.setPower('L');

  e = sx1272.setNodeAddress(2);
  
  delay(1000);  
  
  USB.println(F("----------------------------------------"));
  USB.println(F("Sending join request:")); 
  USB.println(F("----------------------------------------"));

  
  
  prepareJoinRequest();
  USB.print("nwkew ");
  printHexArray(NwKeyB, sizeof(NwKeyB));
  USB.println("");
  
  USB.print("join request: ");
  printHexArray(join_request, sizeof(join_request));
  USB.println("");

  uint8_t encryptedMsg[sizeof(join_request)];
  xor2(encryptedMsg, join_request, sizeof(join_request), NwKeyB, sizeof(NwKeyB));

  USB.print("encryptedMsg: ");
  printHexArray(encryptedMsg, sizeof(encryptedMsg));
  USB.println("");
  
//  sendJoinRequest();
  sendHex(encryptedMsg, sizeof(encryptedMsg));
  if( e == 0 ) 
  {
    USB.println(F("Join Request sent OK"));     
  }
  else 
  {
    USB.print(F("Error sending Join Request."));  
    USB.print(F("state: "));
    USB.println(e, DEC);
  }
  
  USB.println(F("----------------------------------------"));
  USB.println(F("Waiting join accept:")); 
  USB.println(F("----------------------------------------"));
  e = sx1272.receivePacketMAXTimeout();
  if ( e == 0 )
  {
    getPacketData(sx1272.packet_received.length);  
  }
  USB.println("end of setup");
}

void sendHex(uint8_t *hexArray, int size){
  USB.println("sending");
  Utils.hex2str(hexArray, buffer_up, size);
  USB.println(buffer_up);
  e = sx1272.sendPacketTimeout( gw_address, buffer_up);
}

void xor2(uint8_t *out, uint8_t *in, int inSize, uint8_t *key, int keySize){
  for (int i=0; i<inSize;i++){
    int j = i % keySize;
    out[i] = (in[i] ^ key[j]);
  }
}

void printHexArray(uint8_t *hexArray, int size){
  USB.print("size: ");
  USB.println(size);
  
  for (int i=0;i<size;i++){
    USB.print("0x");
    USB.print(hexArray[i], HEX);
    USB.print(" ");
  }
  USB.println("");
}


void getPacketData(int len) {
  char data[len];
  strcpy( data, "F" );
  for ( int i = 0; i < len; i++) {
//    snprintf(data, sizeof(data),"%s%c", data,sx1272.packet_received.data[i]);/
    data[i] = sx1272.packet_received.data[i];
  }
  USB.print("DATA: ");
  USB.println(data);
  
}
  
void prepareJoinRequest(){
  join_request[0] = 0x2B;
  join_request[1] = 0x2B;
  join_request[2] = 0x01;
  join_request[3] = devAddr;
  for (int i = 4; i< 9; i++){
    join_request[i] = 0x00; //4 bytes of timestamp that i dont have rtc and 1 byte of NU (not used)  
  }
  join_request[9] = 0x0A;
}


void loop()
{
  delay(5000);
  USB.print(".");
//  USB.println(F("----------------------------------------"));
//  USB.println(F("Waiting to receive:")); 
//  USB.println(F("----------------------------------------"));
//  // Sending packet before ending a timeout
//  while(!sx1272.receivePacketMAXTimeout()){
//      USB.println(F("\nShow packet received: "));
//      // show packet received
//      sx1272.showReceivedPacket();
//      USB.println(sx1272.packet_received.length, DEC);
//  }
}


