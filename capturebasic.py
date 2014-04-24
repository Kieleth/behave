import cv2
import os
import sys

import classifiers
import enforcers
from utils import flip_frame, CvTimer, Capturer, say, convert_to_gray_and_equalize
import gui

#cx_freeze data hanlder
def find_data_file(filename):
    if getattr(sys, 'frozen', False):
        # The application is frozen
        datadir = os.path.dirname(sys.executable)
    else:
        # The application is not frozen
        # Change this bit to match where you store your data files:
        datadir = os.path.dirname(__file__)

    return os.path.join(datadir, filename)

#INIT:
timer = CvTimer()

capturer = Capturer()
frame_width = capturer.get_cam_width()
frame_heigth = capturer.get_cam_height() 
print('capturing %sx%s' % (frame_width, frame_heigth)) 

face_enforcer = enforcers.EnforceFaceWithin(say)
face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))

# mouse callback function sets red line to enforce
def set_y_limit_low(event,x,y,flags,param):
    if event == cv2.EVENT_LBUTTONDOWN:
        face_enforcer.set_enforce_parameters(y_limit_low=y) 

# Create a window and bind function(s) to window
window_name = 'behave'
gui.create_window(window_name)
gui.assign_action(window_name, set_y_limit_low)

#FIXME quick and dirty counter for only processing every 5th frame.
fps_counter = fps_while_counter = 5
msg = None
debug = False
#Main Loop
while(True):
    #Time tracking w opencv:
    timer.new_frame()

    fps_while_counter -= 1

    #Capture frame-by-frame
    a_frame = capturer.get_frame()

    a_frame = flip_frame(a_frame)

    #display red line for lower limit
    #TODO: change this to a general method to show limits:
    gui.display_line(a_frame, (0, face_enforcer.y_limit_low),
                                (frame_width / 7, face_enforcer.y_limit_low), thickness=2)
    gui.display_line(a_frame, (frame_width - (frame_width / 7), face_enforcer.y_limit_low),
                                (1280, face_enforcer.y_limit_low), thickness=2)

    if fps_while_counter == 0:
        fps_while_counter = fps_counter

        a_frame_prepared = convert_to_gray_and_equalize(a_frame)

        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        if len(faces_list) == 1:
            action_needed, msg = face_enforcer.check_face(faces_list[0])
            if action_needed:
                action_needed()

        if faces_list != () :
            #TODO: change the colour of the face rect when in warning.
            #TODO: create an average of the positions of the last faces.
            gui.display_faces(a_frame, faces_list, with_debug=debug)
    
    if msg:
        cv2.putText(a_frame, msg, (10, 35),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (255,255,255))

    #key handler:
    to_do = gui.get_key_pressed()
    if to_do == 'quit':
        break
    elif to_do == 'debug':
        debug = not debug

    if debug:
        #Timecv:
        cv2.putText(a_frame, "fps=%s avg=%s" % (timer.fps, timer.avg_fps), (10, 75),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        #Frame counter:
        cv2.putText(a_frame, "frame=%s" % (timer.frame_num), (10, 95),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    #On-screen controls:
    gui.put_controls(a_frame)

    #Display the resulting frame
    gui.show_image('behave', a_frame)

capturer.release()
cv2.destroyAllWindows()
