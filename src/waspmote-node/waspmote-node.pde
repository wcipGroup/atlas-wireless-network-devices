
#include <WaspSX1272.h>

uint8_t gw_address = 1;
uint8_t devAddr = 2;
int8_t e;
char NwKey[] = "AB1234";
uint8_t NwKeyB[3] = {0xAB, 0x12, 0x34};
char buffer_up[200];
char buffer_down[200];
uint8_t encryptedResponse[200];
uint8_t join_request[10];
uint8_t data_pckt[32];
uint8_t encrypted_data_pckt[32];
char dl_message[100];
int join_num_try = 0;
int join_retries = 2;
bool joined = false;

///test sensor data
float temp_value = 24.5;
float PH_value = 7.8;
float DO_value = 87;
float cond_value = 33;


void setup()
{
  USB.ON();
  sx1272.ON();
  Utils.setLED(LED0, LED_ON);

  e = sx1272.setChannel(CH_10_868);

  e = sx1272.setHeaderON();

  e = sx1272.setMode(1);  
  
  e = sx1272.setCRC_ON();

  e = sx1272.setPower('L');

  e = sx1272.setNodeAddress(2);
  
  delay(1000);  

  join_the_network();  
  
  
  USB.println("end of setup");
  Utils.setLED(LED0, LED_OFF);
}


void join_the_network()
{
  while (!joined && join_num_try < join_retries)
  {
    USB.print("Num of try: ");
    USB.println(join_num_try);
    USB.println(F("----------------------------------------"));
    USB.println(F("Sending join request:")); 
    USB.println(F("----------------------------------------"));
  
    
  ///Create the body of the message for the join request  
    prepareJoinRequest();
  ///Encrypt the body of the message using the network key
    uint8_t encryptedMsg[sizeof(join_request)];
    xor2(encryptedMsg, join_request, sizeof(join_request), NwKeyB, sizeof(NwKeyB));
  ///Send the message using LoRa
    sendHex(encryptedMsg, sizeof(encryptedMsg));
    if( e == 0 ) 
    {
      USB.println(F("Join Request sent OK"));
      USB.println(F("----------------------------------------"));
      USB.println(F("Waiting join accept:")); 
      USB.println(F("----------------------------------------"));
      e = sx1272.receivePacketMAXTimeout();
      USB.print("TO E: ");
      USB.println(e);
      if ( e == 0 )
      {
        char buffer_down[sx1272.packet_received.length-5];
        strcpy(buffer_down, getPacketData(sx1272.packet_received.length));
        USB.println(buffer_down);
        uint16_t responseSize;
        responseSize = Utils.str2hex(buffer_down, encryptedResponse, sizeof(encryptedResponse));
        
        USB.print("encrypted Response: ");
        printHexArray(encryptedResponse, responseSize );
        uint8_t decryptedResponse[responseSize];
        xor2(decryptedResponse, encryptedResponse, responseSize, NwKeyB, sizeof(NwKeyB));
        USB.print("decrypted Response: ");
        printHexArray(decryptedResponse, responseSize);
        USB.println(decryptedResponse[0], DEC);
        USB.println(decryptedResponse[0], HEX);
        if (decryptedResponse[0] == 43)
        {
          joined = true;
          USB.println("JOINED");
//          /TODO: handle the response and save the app key.
        }else
        {
          USB.println("ERROR at join request.");
          join_num_try = join_num_try + 1;
        }
      }else
      {
        USB.println("ERROR at receiving join accept.");
        join_num_try = join_num_try + 1;
      }
    }
    else 
    {
      USB.print(F("Error sending Join Request."));  
      USB.print(F("state: "));
      USB.println(e, DEC);
      join_num_try = join_num_try + 1;
    }
    if (join_num_try == join_retries && !joined)
    {
      USB.println("Max retries. Wait 10 sec and try again");
      PWR.deepSleep("00:00:00:10",RTC_OFFSET,RTC_ALM1_MODE1,ALL_ON);
      USB.println("Wake up!");
      join_num_try = 0;
      Utils.setLED(LED0, LED_ON);
    }
  }
  
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


char* getPacketData(int len) {
  char data[len];
  strcpy( data, "F" );
  for ( int i = 0; i < len; i++) {
//    snprintf(data, sizeof(data),"%s%c", data,sx1272.packet_received.data[i]);/
    data[i] = sx1272.packet_received.data[i];
  }
  USB.print("DATA: ");
  USB.println(data);
  return data;
  
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

void prepareDataPckt(){
  data_pckt[0] = 0x2B;
  data_pckt[1] = 0x2B;
  data_pckt[2] = 0x04; //Data message
  data_pckt[3] = devAddr;
  data_pckt[4] = 0x04; //Num of sensors [Temp, Conductivity, PH, DO]
  get_temp(5);
  get_ph(10);
  get_do(15);
  get_cond(20);
  for (int i = 25; i< 31; i++){
    data_pckt[i] = 0x00; //4 bytes of timestamp that i dont have rtc and 2 bytes of NU (not used)  
  }
  data_pckt[31] = 0x20; //len = 32 bytes
}

void get_temp(int idx){
  data_pckt[idx] = 0x01; //SensorId
  for (int i=0; i<4; i++)
  {
    data_pckt[idx+i+1] = ((uint8_t*)&temp_value)[i];  
  }
}

void get_ph(int idx){
  data_pckt[idx] = 0x02; //SensorId
  for (int i=0; i<4; i++)
  {
    data_pckt[idx+i+1] = ((uint8_t*)&PH_value)[i];  
  }
}

void get_do(int idx){
  data_pckt[idx] = 0x03; //SensorId
  for (int i=0; i<4; i++)
  {
    data_pckt[idx+i+1] = ((uint8_t*)&DO_value)[i];  
  }
}

void get_cond(int idx){
  data_pckt[idx] = 0x04; //SensorId
  for (int i=0; i<4; i++)
  {
    data_pckt[idx+i+1] = ((uint8_t*)&cond_value)[i];  
  }
}

void loop()
{
  USB.print("Wake up!");
  //Prepare the data frame
  prepareDataPckt();
  printHexArray(data_pckt, sizeof(data_pckt));
  ///Encrypt the body of the message using the network key
  xor2(encrypted_data_pckt, data_pckt, sizeof(data_pckt), NwKeyB, sizeof(NwKeyB));
  ///Send the message using LoRa
  sendHex(encrypted_data_pckt, sizeof(encrypted_data_pckt));
  USB.println("Data Frame sent!");
  USB.println("Go to sleep!");
  PWR.deepSleep("00:00:05:00",RTC_OFFSET,RTC_ALM1_MODE1,ALL_ON);
}


