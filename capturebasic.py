import classifiers
import enforcers
from utils import flip_frame, CvTimer, CountdownTimer, Capturer, say_warning, convert_to_gray_and_equalize, find_data_file, FPSCounter
from gui_managers import CX_Gui

class Behave(object):
    def __init__(self):
        self.timer = CvTimer()
        self.work_timer = CountdownTimer()
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

        #Event hooks:
        self._event_debug = False
        self._event_enforcing = True
        self._event_quit = False
        self._event_auto_limit = False
        #_msg is used to get output from events
        self._event_msg = None

        #Auto-adjust protocol needs:
        self._auto_faces = []
        self._auto_num_faces = 5 #TODO: gui configurable
        self._auto_tilt = 10

    def dispatch_gui_events(self):
        event = self.gui.get_key_event()
        if event == 'quit':
            self._event_quit = True

        elif event == 'debug':
            self._event_debug = not self._event_debug

        elif event == 'toggle_work_timer':
            if self.work_timer.is_started:
                self.work_timer.stop()
            else: 
                self.work_timer.start()

        elif event == 'set_limit_auto':
            self._event_auto_limit = True

    def handle_auto_limit(self, face):
        """Fancy protocol, saves N faces, takes average and sets the y limit with a tilt"""
        #We disable enforcing
        self._event_enforcing = False

        self._auto_faces.append(face)

        len_faces = len(self._auto_faces)
        msg = ("AUTO-adjusting in process... sit correctly! %s of %s" % (len_faces, self._auto_num_faces))
        
        if len_faces == self._auto_num_faces:
            y_s = [y + h / 2. for x, y, w, h in self._auto_faces]
            h_s = [h for x, y, w, h in self._auto_faces]
            #Very ugly, but needed, float to get the real avg, then truncate to get pixels
            avg_y_s = int(sum(y_s) / len_faces)
            avg_size = int(float(sum(h_s)) / len_faces)

            surplus = int(float(avg_size) / self._auto_tilt)
            y_limit_low = avg_y_s + surplus
            self.face_enforcer.set_y_limit_low(y_limit_low)

            #leaving the auto adjustment, cleaning up:
            self.face_enforcer.reset_wrongs()
            self.face_enforcer.reset_oks()
            self._auto_faces = list() 
            self._event_auto_limit = False
            self._event_enforcing = True

        return msg

    def detect_face_in_frame(self, a_frame): 
        a_frame_prepared = convert_to_gray_and_equalize(a_frame)
        faces_list = self.face_classifier.detect_multiscale(a_frame_prepared)

        return faces_list[0] if len(faces_list) == 1 else None

    def handle_enforce(self, face): 
        action_needed, msg = self.face_enforcer.check_face(face)
        if action_needed:
            action_needed()
        if msg:
            return msg
    
    @property
    def should_process_this_frame(self):
        return self.frame_counter.check_if_capture

    def main(self):
                
        while(not self._event_quit):
            self.timer.mark_new_frame()

            #Capture frame-by-frame
            a_frame = self.capturer.get_frame()
            a_frame = flip_frame(a_frame)
            self.gui.feed_frame(a_frame)

            #detect face part:
            if self.should_process_this_frame:
                #face>>(x,y,w,h)
                face = self.detect_face_in_frame(a_frame)

                if face is not None:
                    self.gui.show_face_position(face)
                    if self._event_debug:
                        self.gui.show_face(face)
                    if self._event_auto_limit:
                        self._event_msg = self.handle_auto_limit(face)
                    if self._event_enforcing:
                        self._event_msg = self.handle_enforce(face)

            #this if is out of the process one to leave the msg in between frames
            if self._event_msg:
                self.gui.show_msg(self._event_msg)

            #Check user input, this part needs to be after the frame has been created and fed to gui:
            self.dispatch_gui_events()
            if self._event_debug:
                self.gui.show_debug(self.timer)
            #TODO: if face detected, work counter counts:
            if self.work_timer.is_started:
                self.gui.show_contdown(self.work_timer.get_time_left())
            #Add on-screen controls and limits visual guide:
            self.gui.show_controls()
            self.gui.show_limits(self.face_enforcer)

            #Display the resulting frame
            self.gui.show_image()

        #if we are out of the while:
        self.clean_up()

    def clean_up(self):
        self.capturer.release()
        self.gui.close_window()

if __name__ == '__main__':
    Behave().main()
