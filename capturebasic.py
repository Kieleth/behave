import classifiers
import enforcers
from utils import flip_frame, CvTimer, WorkTimer, Capturer, say_warning, convert_to_gray_and_equalize, find_data_file, FPSCounter
from gui_managers import CX_Gui

class Behave(object):
    def __init__(self):
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

        self._msg = None
        self._debug = False
        self._enforcing = True
        self._quit = False
        self._auto_limit_protocol = False
        self._auto_faces = []
        self._auto_num_faces = 5
        self._auto_tilt = 10

    def handle_gui_events(self):
        #gui keypress event handler:
        to_do = self.gui.get_action()
        if to_do == 'quit':
            self._quit = True

        elif to_do == 'debug':
            self._debug = not self._debug

        elif to_do == 'toggle_work_timer':
            if self.work_timer.is_started:
                self.work_timer.stop()
            else: 
                self.work_timer.start()

        elif to_do == 'set_limit_auto':
            self._auto_limit_protocol = True

    def adjusting_auto_limit(self, face):
        """Fancy protocol, saves N faces, takes average and sets the y limit with a tilt"""
        #We disable enforcing
        self._enforcing = False

        self._auto_faces.append(face)

        len_faces = len(self._auto_faces)
        msg = ("AUTO-adjusting in process... sit correctly! %s of %s" % (len_faces, self._auto_num_faces))
        
        if len_faces == self._auto_num_faces:
            y_s = [y + h / 2. for x, y, w, h in self._auto_faces]
            h_s = [h for x, y, w, h in self._auto_faces]
            #Very ugly, but needed, float to get the real avg, then truncate it since its pixels
            avg_y_s = int(sum(y_s) / len_faces)
            avg_size = int(float(sum(h_s)) / len_faces)

            surplus = int(float(avg_size) / self._auto_tilt)
            y_limit_low = avg_y_s + surplus
            self.face_enforcer.set_y_limit_low(y_limit_low)

            #cleaning up:
            self.face_enforcer.reset_wrongs()
            self.face_enforcer.reset_oks()
            self._auto_faces = list() 
            self._auto_limit_protocol = False
            self._enforcing = True
                
        return msg

    def detect_face_in_frame(self, a_frame): 
        a_frame_prepared = convert_to_gray_and_equalize(a_frame)
        faces_list = self.face_classifier.detect_multiscale(a_frame_prepared)

        return faces_list[0] if len(faces_list) == 1 else None

    def enforce_action_in(self, face): 
        action_needed, msg = self.face_enforcer.check_face(face)
        if action_needed:
            action_needed()
        if msg:
            return msg
    
    @property
    def should_process_this_frame(self):
        return self.frame_counter.check_if_capture

    def main(self):
        msg_out = None
                
        while(not self._quit):
            self.timer.mark_new_frame()

            #Capture frame-by-frame
            a_frame = self.capturer.get_frame()
            a_frame = flip_frame(a_frame)
            self.gui.feed_frame(a_frame)

            #detect face part:
            if self.should_process_this_frame:
                face_coords = self.detect_face_in_frame(a_frame)

                if face_coords is not None:
                    self.gui.show_face_position(face_coords)
                    if self._debug:
                        self.gui.show_face(face_coords)
                    if self._auto_limit_protocol:
                        msg_out = self.adjusting_auto_limit(face_coords)
                    if self._enforcing:
                        msg_out = self.enforce_action_in(face_coords)

            if msg_out:
                self.gui.show_msg(msg_out)

            #Check user input, this part needs to be after the frame has been created and fed to gui:
            self.handle_gui_events()
            if self._debug:
                self.gui.show_debug(self.timer)
            #TODO: if face detected, work counter counts:
            if self.work_timer.is_started:
                self.gui.show_contdown(self.work_timer.get_time_left())
            #Add on-screen controls and guide:
            self.gui.show_controls()
            self.gui.show_limits(self.face_enforcer)

            #Display the resulting frame
            self.gui.show_image()

        self.clean_up()

    def clean_up(self):
        #Cleaning up
        self.capturer.release()
        self.gui.close_window()

if __name__ == '__main__':
    Behave().main()
