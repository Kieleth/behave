import classifiers
import enforcers
from utils import flip_frame, CvTimer, WorkTimer, Capturer, say_warning, convert_to_gray_and_equalize, find_data_file, FPSCounter
from gui_managers import CX_Gui

class Behave(object):
    def __init__(self):
        #INIT:
        self.timer = CvTimer()
        self.work_timer = WorkTimer()
        #TODO:this should be configurable from gui
        self.frame_counter = FPSCounter(every=5)

        self.capturer = Capturer()
        self.frame_size = frame_width, frame_heigth = self.capturer.get_camera_width_heigth()
        #TODO: check the way to reduce the capture.
        print('capturing %sx%s' % (frame_width, frame_heigth)) 

        self.face_enforcer = enforcers.EnforceFaceLimits(say_warning)
        self.face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))

        #Initialize GUI:
        self.gui = CX_Gui(window_name='behave', enforcer=self.face_enforcer, frame_size=self.frame_size)
        self.gui.initialize_gui()

        #FIXME quick and dirty counter for only processing every 5th frame.
        self.msg = None
        self.debug = False
        self.enforcing = True

    def main(self):
                
        while(True):
            #Time tracking w opencv:
            self.timer.mark_new_frame()

            #Capture frame-by-frame
            a_frame = self.capturer.get_frame()
            a_frame = flip_frame(a_frame)

            self.gui.feed_frame(a_frame)

            self.gui.show_limits(self.face_enforcer)

            if self.frame_counter.check_if_capture:

                a_frame_prepared = convert_to_gray_and_equalize(a_frame)
                faces_list = self.face_classifier.detect_multiscale(a_frame_prepared)

                if len(faces_list) > 0:
                    self.gui.display_faces(faces_list, with_debug=self.debug)

                #Only doing some behaving if there's only one face and we are enforcing:
                if self.enforcing and len(faces_list) == 1:
                    action_needed, msg = self.face_enforcer.check_face(faces_list[0])
                    if action_needed:
                        action_needed()
                    if msg:
                        self.gui.show_msg(msg)
            
            #gui keypress event handler:
            to_do = self.gui.get_action()
            if to_do == 'quit':
                break
            elif to_do == 'debug':
                self.debug = not self.debug
            elif to_do == 'toggle_work_timer':
                if self.work_timer.is_started:
                    self.work_timer.stop()
                else: 
                    self.work_timer.start()
            elif to_do == 'set_limit_auto':
                #Set face limits auto protocol:
                #show msg to stay still in good position and press space to start.
                self.gui.show_msg("AUTO-adjusting, press 'space' to beging")
                #disable enforcing
                self.enforcing = False
                #get and save face position last N frames
                #get and save face size last N frames
                #calculate face_y average of N
                #calculate face_size avg of N 
                #calculate position of new y_limit = face_y_avg * (face_size_avg * Constant)
                #set_enforcer with new new_y_limit
                #enable enforcing
                self.enforcing = True
                pass

            if self.debug:
                self.gui.show_debug(self.timer)

            #TODO: if face detected, work counter counts:
            if self.work_timer.is_started:
                self.gui.show_contdown(self.work_timer.get_time_left())

            #On-screen controls:
            self.gui.show_controls()

            #Display the resulting frame
            self.gui.show_image('behave')

        #Cleaning up
        self.capturer.release()
        self.gui.close_window()

if __name__ == '__main__':
    Behave().main()
