import numpy as np
import cv2

from classifiers import FaceClassifier
from enforcers import EnforceFaceWithin
import utils
import gui

#INIT:
frame_num = 0
timer = utils.CvTimer()

capture = cv2.VideoCapture(0)
frame_width = int(capture.get(3))
frame_heigth = int(capture.get(4))
print('capturing %sx%s' % (frame_width, frame_heigth)) 

face_enforcer = EnforceFaceWithin(utils.say)
y_limit = face_enforcer.y_limit_low
face_classifier = FaceClassifier()

while(True):
    #Time tracking w opencv:
    timer.reset()

    #Capture frame-by-frame
    _, the_frame = capture.read()
    if the_frame is None:
        raise

    the_frame = utils.flip_frame(the_frame)

    frame_prepared = utils.prepare_frame_for_detection(the_frame)

    faces_list = face_classifier.detect_multiscale(frame_prepared)

    #display red line for lower limit
    #TODO: change this to a general method to show limits:
    gui.display_line(the_frame, (0, y_limit), (frame_width, y_limit))

    if faces_list != () :
        gui.display_faces(the_frame, faces_list)

    if len(faces_list) == 1:
        action_needed = face_enforcer.check_face(faces_list[0])
        if action_needed:
            action_needed()

    #key handler:
    if gui.should_quit():
        break

    #Timecv:
    cv2.putText(the_frame, "fps=%s avg=%s" % (timer.fps, timer.avg_fps), (10, 35),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
    #Frame counter:
    frame_num += 1
    cv2.putText(the_frame, "frame=%s" % (frame_num), (10, 55),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    #Display the resulting frame
    cv2.imshow('frame', the_frame)

capture.release()
cv2.destroyAllWindows()
