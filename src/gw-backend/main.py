# Simple code for Atlas gw-host machine.
# Is waiting for incoming messages either from the gw-transceiver or the nw-server.
# Is communicating with the gw-transceiver through the serial interface (usb)
# Is communicating with the nw-server through an mqtt client (paho)

import serial
import paho.mqtt.client as mqtt
import threading
import time
import configparser
import json

key = None
config = None
mqttc = None


def on_connect(client, userdata, flags, rc):
    print("Connected with result code " + str(rc))
    client.subscribe("atlas/%s/down" % config["gw_id"])
    client.subscribe("atlas/%s/action" % config["gw_id"])


def on_message(client, userdata, msg):
    if msg.topic == "atlas/%s/down" % config["gw_id"]:
        ser.write(msg.payload)
        ser.flushInput()
        ser.flushOutput()
    elif msg.topic == "atlas/%s/action" % config["gw_id"]:
        doAction(msg.payload)


def doAction(action):
    print(action)


def xor(input, inSize, key, keySize):
    strs = ""
    for i in range(inSize):
        j = i % keySize
        strs = strs + "0x" + str(input[i] ^ key[j])
    return strs


def toHexArrayInt(input):
    hexArray = input.split("0x")[1:]
    for i in range(len(hexArray)):
        hexArray[i] = hex(int(hexArray[i]))
    return hexArray


def toHexArrayStr(input):
    ret = ""
    for i in range(len(input)):
        ret = ret + input[i].split("0x")[1]
    return ret


def read_until(ser, eol, timeout=1):
    msg = b''
    endTime = time.time() + timeout
    while True:
        ch = ser.read()
        msg = msg + ch
        if ch == eol:
            break
        if time.time() > endTime:
            raise TimeoutError
    return msg


#Use this as 'lastSeen' functionality at network server for the gateways
def heartBeat(mqttc):
    while 1:
        try:
            mqttc.publish("atlas/%s/gw_heartbeat" % config["gw_id"], "alive")
            time.sleep(60)
        except Exception:
            time.sleep(60)
            

def serialRead(ser, mqttc):
    while 1:
        if ser.in_waiting > 0:
            try:
                line = read_until(ser, b'\n').decode('UTF-8')
                line = line[:-2]  # Remove the last two characters for new line /r/n
                if line == "E#v2":
                    print("Init Message")
                    continue
                linejs = json.loads(line)
                linejs['TMSTMP'] = int(time.time())
                mqttc.publish("atlas/%s/up" % config["gw_id"], json.dumps(linejs))
            except TimeoutError:
                print("TIMEOUT")


def initClients():
    serialClient = serial.Serial(port=config['waspmote_device'],
                                 baudrate=115200,
                                 parity=serial.PARITY_NONE,
                                 stopbits=serial.STOPBITS_ONE,
                                 bytesize=serial.EIGHTBITS,
                                 timeout=0)
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(config['mqtt_ip'], 1883, 60)

    return serialClient, client


if __name__ == '__main__':
    print("Start of the program")
    ser = None
    try:
        config = configparser.ConfigParser()
        config.read('config.ini')
        config = config.defaults()
        ser, mqttc = initClients()
        ser.flushOutput()
        ser.flushInput()
        key = bytearray.fromhex(config["nw_key"])
    except Exception as e:
        print(e)
        exit(1)
    print("End of INIT")
    threading.Thread(target=serialRead, args=(ser, mqttc,)).start()
    threading.Thread(target=heartBeat, args=(mqttc,)).start()
    mqttc.loop_forever()

# encrypted = xor(input, len(input), key, len(key))
# encrStr = toHexArrayStr(toHexArrayInt(encrypted))
# encr = bytearray.fromhex(encrStr)
