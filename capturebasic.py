import cv2

from classifiers import FaceClassifier
from enforcers import EnforceFaceWithin
import utils
import gui

#INIT:
timer = utils.CvTimer()

capturer = utils.Capturer()
frame_width = capturer.get_cam_width()
frame_heigth = capturer.get_cam_height() 
print('capturing %sx%s' % (frame_width, frame_heigth)) 

face_enforcer = EnforceFaceWithin(utils.say)
face_classifier = FaceClassifier()

# mouse callback function sets red line to enforce
def set_y_limit_low(event,x,y,flags,param):
    if event == cv2.EVENT_LBUTTONDOWN:
        face_enforcer.set_enforce_parameters(y_limit_low=y) 

# Create a window and bind function(s) to window
cv2.namedWindow('behave')
cv2.setMouseCallback('behave', set_y_limit_low)


while(True):
    #Time tracking w opencv:
    timer.new_frame()

    #Capture frame-by-frame
    the_frame = capturer.get_frame()

    the_frame = utils.flip_frame(the_frame)

    frame_prepared = utils.prepare_frame_for_detection(the_frame)

    faces_list = face_classifier.detect_multiscale(frame_prepared)

    #display red line for lower limit
    #TODO: change this to a general method to show limits:
    gui.display_line(the_frame, (0, face_enforcer.y_limit_low),
                                (frame_width / 7, face_enforcer.y_limit_low), thickness=2)
    gui.display_line(the_frame, (frame_width - (frame_width / 7), face_enforcer.y_limit_low),
                                (1280, face_enforcer.y_limit_low), thickness=2)

    if len(faces_list) == 1:
        action_needed = face_enforcer.check_face(faces_list[0])
        if action_needed:
            action_needed()

    if faces_list != () :
        #TODO: change the colour of the face rect when in warning.
        gui.display_faces(the_frame, faces_list)

    #key handler:
    if gui.should_quit():
        break

    #Timecv:
    cv2.putText(the_frame, "fps=%s avg=%s" % (timer.fps, timer.avg_fps), (10, 35),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
    #Frame counter:
    cv2.putText(the_frame, "frame=%s" % (timer.frame_num), (10, 55),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    #Display the resulting frame
    cv2.imshow('behave', the_frame)

capturer.release()
cv2.destroyAllWindows()
