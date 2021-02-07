
#include <WaspSX1272.h>

// status variable
int8_t e;
char dl_message[100];
unsigned long timeout_amount = 4000;



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
  e = sx1272.setNodeAddress(1);

  strcpy(dl_message, "");

  delay(1000);
}

char* USBreadString() {
  char message[100];
  int val = 0;
  unsigned long TIMEOUT = millis() + timeout_amount;
  while (!USB.available() && millis() < TIMEOUT)
  {
    //wait for available
  }
  strcpy( message, "" );
  while (USB.available() > 0)
  {
    val = USB.read();
    snprintf(message, sizeof(message), "%s%c", message, val);
  }
  USB.flush();
  return message;
};

void getPacketData(int len) {
  char data[len];
  strcpy( data, "F" );
  for ( int i = 0; i < len; i++) {
//    snprintf(data, sizeof(data),"%s%c", data,sx1272.packet_received.data[i]);/
    data[i] = sx1272.packet_received.data[i];
  }
  USB.println(data);
}

void loop()
{
  // receive packet
  e = sx1272.receivePacketMAXTimeout();

  // check rx status
  if ( e == 0 )
  {
//    sx1272.showReceivedPacket();/
    getPacketData(sx1272.packet_received.length);
    strcpy(dl_message, USBreadString());
    if (dl_message[0] != 0) {
      sx1272.sendPacketTimeout( 2, dl_message);
      strcpy(dl_message, "");
    }
  }

}





