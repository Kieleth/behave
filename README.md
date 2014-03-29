###Project:

Behave is a little app to help people control themselves in front of a computer.

At the moment only works keeping the back straight when you are sitting.

Future versions aim will allow the user to teach the application how to recognice unwanted actions, like nail bitting for example.

####Implementation:

A Python script that takes control the webcam of the computer and with OpenCV processes the video stream to capture what is told to do.

####Features:

2014 Mar 23
Captures the position of the face, makes sure that it does not go below cerain treshold. 

####Requirements:
(At the moment this are the specs of the dev environment that works):

- Mac Os 10.8.5
- OpenCv version 2.4.7
- Python 2.7 in 32-bit version (should work in x64)
- Webcam!

####TODO:
- 140324 --> FIX/handle "Camera dropped frame!" output
- 140329 --> PACK it so it can be used in "one click"
