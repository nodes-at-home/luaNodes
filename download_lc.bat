
FOR %%F IN (
apds9960.lc
brewNode.lc
breweryNode.lc
buttonNode.lc
credential.lc
deepsleep.lc
electricityNode.lc
espConfig.lc
garageNode.lc
gestureNode.lc
httpDL.lc
i2ctool.lc
ledNode.lc
mpu6050.lc
mqttNode.lc
mqttNodeConfig.lc
mqttNodeConnect.lc
mqttNodeUpdate.lc
noNode.lc
oledNode.lc
pixel.lc
pixelNode.lc
pixelNodeConnect.lc
pixelNodeMessage.lc
poolNode.lc
relayNode.lc
rfNode.lc
rgbNode.lc
sonoffNode.lc
spindleNode.lc
ssrNode.lc
startup.lc
tempNode.lc
trace.lc
update.lc
updateCompletion.lc
updateFailure.lc
updateFiles.lc
updateMqttState.lc
updateWifi.lc
util.lc
xmasNode.lc
) DO (
	nodemcu-tool.cmd download %%F
)
