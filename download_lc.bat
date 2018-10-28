
FOR %%F IN (
brewNode.lc
breweryNode.lc
buttonNode.lc
credential.lc
electricityNode.lc
garageNode.lc
gestureNode.lc
ledNode.lc
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
tempNode.lc
touchNode.lc
update.lc
updateCompletion.lc
updateFailure.lc
updateFiles.lc
updateMqttState.lc
updateWifi.lc
xmasNode.lc
) DO (
	nodemcu-tool.cmd download %%F
)
