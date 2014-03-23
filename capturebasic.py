import numpy as np
import cv2
import time
import subprocess

capture = cv2.VideoCapture(0)

face_cascade = cv2.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')

def say():
    subprocess.call('say -v Victoria "I think your back is not straight, Mister!"', shell=True)

def delay_to(fps):
    time.sleep(1.0 / fps)

#INIT:
COUNTER = 10
counter = 0
counter_ok = 0

while(True):
    #Capture frame-by-frame
    ret, frame = capture.read()

    if not ret:
        print 'frame skipped'
        continue

    #flips horizontally:
    #frame = np.fliplr(frame) # check which is faster:
    frame = cv2.flip(frame, 1)

    # Our operations on the frame come here
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)

    #Recognition:
    scale_factor = 1.3
    min_neigh = 4
    flags = cv2.CASCADE_SCALE_IMAGE
    minSize = (200, 200)
    maxSize = None # (300, 300)
    faces = face_cascade.detectMultiScale(gray, scale_factor, min_neigh,minSize=minSize, maxSize=maxSize, flags=flags)
    print faces

    for (x, y, w, h) in faces:
        cv2.rectangle(frame, (x, y), (x + w, y + h), (255, 0, 0), 2)
        roi_gray = gray[y:y + h, x:x + w]
        roi_color = frame[y:y + h, x:x + w]

        #displays coords on screen
        cv2.putText(frame, "x=%s y=%s w=%s h=%s" % (x,y,w,h), (x, y+h+20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    # FACE POSITION CONTROL:
    #assuming one face:
    if len(faces) == 1:
        face_rect = faces[0]
        # the face in my desk should be around x: 400-600 y: 60-150
        x, y, w, h = face_rect
        print 'face is positioned at x=%s y=%s' % (x, y)
        if x < 350 or x > 650 or y > 150:
            counter += 1
            print 'warning... :>'
    
            if counter == COUNTER:
                print 'You are doing something wrong!!!'
                say()
                counter = 0
        elif counter > 0:
            counter_ok += 1
    
    if counter_ok == 10:
        print 'counter_ok is RESET'
        counter_ok = 0
        counter = 0


    #Display the resulting frame
    cv2.imshow('frame', frame)

    #fps:
    fps = 25
    delay_to(fps)
            
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
