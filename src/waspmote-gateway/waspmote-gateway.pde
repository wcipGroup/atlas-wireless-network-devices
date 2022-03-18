
#include <WaspSX1272.h>

///Change This!
uint8_t gw_address = 40;
///**************
// status variable
int8_t e;
unsigned long timeout_amount = 4000;


char message[100];
char dl_data [100];
char dl_devAddr [10];

void setup()
{
  USB.ON();
  sx1272.ON();

  e = sx1272.setChannel(CH_10_868);

  e = sx1272.setHeaderON();

  e = sx1272.setMode(1);

  e = sx1272.setCRC_ON();

  e = sx1272.setPower('L');

  // Select the node address value: from 2 to 255
  e = sx1272.setNodeAddress(gw_address);

  delay(1000);
}

bool USBreadString(char dl_data[], char dl_devAddr[]) {
  bool ret_flag = false;
  int val = 0;
  unsigned long TIMEOUT = millis() + timeout_amount;
  while (!USB.available() && millis() < TIMEOUT)
  {
    //wait for available
  }
  strcpy( message, "" );
  while (USB.available() > 0)
  {
    ret_flag = true;
    val = USB.read();
    if (val == 47) //character "/"
    {
      strcpy (dl_data, message);
      strcpy (message, "");
    }else if (val == 38) //character "&"
    {
      strcpy (dl_devAddr, message);
      strcpy (message, "");
    }else
    {
      snprintf(message, sizeof(message), "%s%c", message, val);  
    }
  }
  return ret_flag;
}

///Forward message to gw-backend through serial interface
void getForwardPacketData(int len) {
  char data[len];
  strcpy( data, "F" );
  for ( int i = 0; i < len; i++) {
//    snprintf(data, sizeof(data),"%s%c", data,sx1272.packet_received.data[i]);/
    data[i] = sx1272.packet_received.data[i];
  }
  sx1272.getSNR();
  sx1272.getRSSI();
  USB.print("{\"DATA\": \"");
  USB.print(data);
  USB.print("\", \"SNR\": \"");
  USB.print(sx1272._SNR);
  USB.print("\", \"RSSI\": \"");
  USB.print(sx1272._RSSI);
  USB.println("\"}");
}

void loop()
{
  // receive packet
  e = sx1272.receivePacketMAXTimeout();
  // check rx status
  if ( e == 0 )
  {
    getForwardPacketData(sx1272.packet_received.length);
    //Check and forward replies as downlink packets
    if (USBreadString(dl_data, dl_devAddr))
    {
      sx1272.sendPacketTimeout( atoi(dl_devAddr), dl_data);
    }
  }
  
}





