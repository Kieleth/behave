###Project:
Behave is a helper app that allows people control themselves in front of a computer.

####Implementation:
Some Python code doing computer vision that takes control of the webcam and, througth OpenCV, processes the video stream enforcing certain parameters set by the user.

####Features:
- 140504 debug option // work timer countdown of 50 minutes // Auto-adjust functionality included.
- 140329 User can set treshold by clicking in image.
- 140323 Captures the position of the face, makes sure that it does not go below cerain treshold. Keeps back in straigth position.

####Requirements:
(At the moment this are the specs of the dev environment that works):
- Mac Os 10.8.5
- OpenCv version 2.4.7
- Python 2.7 in 32-bit version (should work in x64)
- Webcam!

####TODO:
- 140324 --> FIX/handle "Camera dropped frame!" output
- 140329 --> Reduce cpu usage. Done partially, with processing only every 5th frame
