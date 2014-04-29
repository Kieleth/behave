import classifiers
import enforcers
from utils import flip_frame, CvTimer, WorkTimer, Capturer, say, convert_to_gray_and_equalize, find_data_file
from gui_managers import CX_Gui

#INIT:
timer = CvTimer()
work_timer = WorkTimer()

capturer = Capturer()
frame_width = capturer.get_cam_width()
frame_heigth = capturer.get_cam_height() 
#TODO: check the way to reduce the capture.
print('capturing %sx%s' % (frame_width, frame_heigth)) 

face_enforcer = enforcers.EnforceFaceWithin(say)
face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))

#Initialize GUI:
gui = CX_Gui(window_name='behave', enforcer=face_enforcer)
gui.initialize_gui()

#FIXME quick and dirty counter for only processing every 5th frame.
fps_counter = fps_while_counter = 5
msg = None
debug = False
#Main Loop
while(True):
    #Time tracking w opencv:
    timer.mark_new_frame()

    fps_while_counter -= 1

    #Capture frame-by-frame
    a_frame = capturer.get_frame()
    a_frame = flip_frame(a_frame)

    gui.feed_frame(a_frame)

    gui.show_limits(face_enforcer, frame_width)

    if fps_while_counter == 0:
        fps_while_counter = fps_counter

        a_frame_prepared = convert_to_gray_and_equalize(a_frame)
        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        #Only doing some behaving if there's only one face:
        if len(faces_list) == 1:
            action_needed, msg = face_enforcer.check_face(faces_list[0])
            if action_needed:
                action_needed()
            if msg:
                gui.put_msg(msg)

            #if face detected, work counter counts:
            if work_timer.is_started:
                gui.show_contdown(work_timer.get_time_left())

        if faces_list != ():
            gui.display_faces(faces_list, with_debug=debug)
    
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

    #On-screen controls:
    gui.put_controls()

    #Display the resulting frame
    gui.show_image('behave')

#Cleaning up
capturer.release()
gui.close_window()
