import classifiers
import enforcers
from utils import flip_frame, CvTimer, WorkTimer, Capturer, say, convert_to_gray_and_equalize, find_data_file, FPSCounter
from gui_managers import CX_Gui

#INIT:
timer = CvTimer()
work_timer = WorkTimer()
#TODO:this should be configurable from gui
frame_counter = FPSCounter(every=5)

capturer = Capturer()
frame_width, frame_heigth = capturer.get_camera_width_heigth()
#TODO: check the way to reduce the capture.
print('capturing %sx%s' % (frame_width, frame_heigth)) 

face_enforcer = enforcers.EnforceFaceWithin(say)
face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))

#Initialize GUI:
gui = CX_Gui(window_name='behave', enforcer=face_enforcer)
gui.initialize_gui()

#FIXME quick and dirty counter for only processing every 5th frame.
msg = None
debug = False
while(True):
    #Time tracking w opencv:
    timer.mark_new_frame()

    #Capture frame-by-frame
    a_frame = capturer.get_frame()
    a_frame = flip_frame(a_frame)

    gui.feed_frame(a_frame)

    gui.show_limits(face_enforcer, frame_width)

    if frame_counter.check_if_capture:

        a_frame_prepared = convert_to_gray_and_equalize(a_frame)
        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        if len(faces_list) > 0:
            gui.display_faces(faces_list, with_debug=debug)

        #Only doing some behaving if there's only one face:
        if len(faces_list) == 1:
            action_needed, msg = face_enforcer.check_face(faces_list[0])
            if action_needed:
                action_needed()
            if msg:
                gui.put_msg(msg)
    
    #gui event handler:
    to_do = gui.get_action()
    if to_do == 'quit':
        break
    elif to_do == 'debug':
        debug = not debug
    elif to_do == 'toggle_work_timer':
        if work_timer.is_started:
            work_timer.stop()
        else: 
            work_timer.start()

    if debug:
        gui.show_debug(timer)

    #TODO: if face detected, work counter counts:
    if work_timer.is_started:
        gui.show_contdown(work_timer.get_time_left())

    #On-screen controls:
    gui.put_controls()

    #Display the resulting frame
    gui.show_image('behave')

#Cleaning up
capturer.release()
gui.close_window()
