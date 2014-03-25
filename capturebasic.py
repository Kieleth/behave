import numpy as np
import cv2
import time
import subprocess
import time

capture = cv2.VideoCapture(0)

face_cascade = cv2.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')

def say():
    subprocess.call('say -v Victoria "I think your back is not straight, Mister."&', shell=True)

def delay_to(fps):
    time.sleep(1.0 / fps)

#INIT:
COUNTER = 20
counter = 0
counter_ok = 0

frame_num = 0
tick_frequency = cv2.getTickFrequency()

x_limit_low = 350
x_limit_high = 650
y_limit_low = 150
y_limit_high = 0

scale_factor = 1.3
min_neigh = 4
flags = cv2.CASCADE_SCALE_IMAGE
minSize = (200, 200)
maxSize = None # (300, 300)

while(True):
    #Time tracking w opencv:
    frame_tick_start = cv2.getTickCount()

    #Capture frame-by-frame
    ret, frame = capture.read()
    if frame is None:
        raise

    #flips horizontally:
    #frame = np.fliplr(frame) # check which is faster:
    frame = cv2.flip(frame, 1)

    # Our operations on the frame come here
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)

    #Recognition:
    faces = face_cascade.detectMultiScale(gray, scale_factor, min_neigh,minSize=minSize, maxSize=maxSize, flags=flags)
    #LOG>print faces

    for (x, y, w, h) in faces:
        cv2.rectangle(frame, (x, y), (x + w, y + h), (255, 0, 0), 2)
        roi_gray = gray[y:y + h, x:x + w]
        roi_color = frame[y:y + h, x:x + w]

        #displays coords on screen
        cv2.putText(frame, "pos(x, y)=(%s,%s)" % (x, y), (x + w + 10, y + 15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        cv2.putText(frame, "size(w x h)=(%sx%s)" % (w, h), (x + w + 10, y + 40), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    # FACE POSITION CONTROL:
    #assuming one face:
    if len(faces) == 1:
        face_rect = faces[0]

        x, y, w, h = face_rect
        #>LOG>print 'face is positioned at x=%s y=%s' % (x, y)
        if x < x_limit_low or x > x_limit_high or y > y_limit_low or y < y_limit_high:
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

    #key handler:
    k = cv2.waitKey(1) & 0xFF
    if k == ord('q') or k == 27:
        break

    #Timecv
    frame_ticks = cv2.getTickCount() - frame_tick_start
    cv2.putText(frame, "fps=%s" % (tick_frequency / frame_ticks), (10, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
    cv2.putText(frame, "frame=%s" % (frame_num), (10, 55), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
    frame_num += 1

    #Display the resulting frame
    cv2.imshow('frame', frame)


capture.release()
cv2.destroyAllWindows()
