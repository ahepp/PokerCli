# Poker
Poker is a tool to adjust Embers.

<img width="250" alt="An Ember temperature controlled mug" src="https://user-images.githubusercontent.com/7539436/163346383-17afeca6-b1b1-463d-bcdc-bc15c5001c64.png">

## Getting started
You'll need to know the UUID of your Ember device.
 One way to do this is by sniffing with the MacOS tool "PacketLogger", but I'm sure there are many others.

Once you know the UUID, make sure your device is unpaired. Then run `poker pair <UUID>`.
 Alternatively, you can use the Ember app to pair the device with your Mac.

After the device is paired, you can run `poker get <UUID> target|current` to get temperature data.
 The target temperature is the temperature your device is attempting to keep the beverage at.
 The current temperature is the actual temperature of your beverage.

You can change the target temperature with `poker set <UUID> target <temp>`.
 Setting the target temperature to 0 will turn off the temperature control function.

`poker` uses a celcius, fixed point representation of temperature.
 That is, 5723 represents 57.23c, or 135f.
 Ember appears to support temperatures from 120f to 145f in their app.

## Poker in action
<img width="500" alt="A screenshot showing usage of the poker tool" src="https://user-images.githubusercontent.com/7539436/163345336-1512bc44-657e-47ab-ab4b-af07b6257969.png">
