import numpy as np
import cv2
import time
import subprocess
import time

capture = cv2.VideoCapture(0)


class CascadeClassifier(object):
    def __init__(self, xml_file):
        try:
            self.cascade = cv2.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')
        except IOError as e:
            raise e

        self.set_cascade_params()
   
    def set_cascade_params(self, scale_factor=None, min_neigh=None, minSize=None, maxSize=None, flags=None):
        """Allows to modify the detector parameters on the fly, has defaults if any
           not initialized"""
        self.scale_factor = 1.3 if not scale_factor else scale_factor
        self.min_neigh = 4 if not min_neigh else min_neigh
        self.flags = cv2.CASCADE_SCALE_IMAGE if not flags else flags
        self.minSize = (200, 200) if not minSize else minSize
        self.maxSize = None if not maxSize else MaxSize # (300, 300)

    def detect_multiscale(self, image):
        """ calls detectMultiSsale with the parameters present in the class, returns
           a list of objects found"""
        found_list = self.cascade.detectMultiScale(image,
                                           self.scale_factor,
                                           self.min_neigh,
                                           self.minSize,
                                           self.maxSize,
                                           self.flags)
        return found_list


class FaceClassifier(CascadeClassifier):
    def __init__(self):
        super(self, FaceClassifier).__init__('cascades/haarcascade_frontalface_alt.xml')


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

def flip_frame(frame):
    #1 flips horizontally:
    #frame = np.fliplr(frame) # check which is faster:
    return cv2.flip(frame, 1)

def process_frame_for_capture(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    return gray

def detect_faces(frame, scale_factor, min_neigh, minSize, maxSize, flags):
    """calls detectMultiscale"""
    faces_list = face_cascade.detectMultiScale(
                                  frame,
                                  scale_factor,
                                  min_neigh,
                                  minSize=minSize,
                                  maxSize=maxSize,
                                  flags=flags)
    #LOG>print faces
    return faces_list

def display_faces(cv_img, faces_list):
    """faces_list has format [(x, y, w, h), ..]"""
    for (x, y, w, h) in faces_list:
        cv2.rectangle(cv_img, (x, y), (x + w, y + h), (255, 0, 0), 2)
        #roi_gray = gray[y:y + h, x:x + w]
        #roi_color = frame[y:y + h, x:x + w]
        display_rectangle_coords(cv_img, x, y, w, h)

def display_rectangle_coords(cv_image, x, y, w, h):
    """displays coords on screen"""
    cv2.putText(cv_image, "pos(x, y)=(%s,%s)" % (x, y), (x + w + 10, y + 15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    cv2.putText(cv_image, "size(w x h)=(%sx%s)" % (w, h), (x + w + 10, y + 40), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

def behave_enforces(face):
    """Here be the collection of controls to be enforced in the image"""
    enforce_face_within(face, x_limit_low, x_limit_high, y_limit_low, y_limit_high)
 
def enforce_face_within(face, x_limit_low, x_limit_high, y_limit_low, y_limit_high):
    # FACE POSITION CONTROL:
    x, y, w, h = face

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

while(True):
    #Time tracking w opencv:
    frame_tick_start = cv2.getTickCount()

    #Capture frame-by-frame
    _, the_frame = capture.read()
    if the_frame is None:
        raise

    frame_flipped = flip_frame(the_frame)

    frame_processed = process_frame_for_capture(the_frame)

    faces_detected = detect_faces(the_frame, scale_factor, min_neigh, minSize, maxSize, flags)

    display_faces(the_frame, faces_detected)

    if len(faces_detected[0]) > 1:
        continue

    behave_enforces(faces_detected[0])

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
