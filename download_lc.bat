
FOR %%F IN (
apds9960.lc
apds9960debug.lc
brewNode.lc
buttonNode.lc
credential.lc
ds18b20.lc
espConfig.lc
garageNode.lc
gestureNode.lc
httpDL.lc
ledNode.lc
mqttNode.lc
mqttNodeConfig.lc
mqttNodeConnect.lc
mqttNodeUpdate.lc
noNode.lc
oledNode.lc
poolNode.lc
relayNode.lc
rfNode.lc
sonoffNode.lc
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
