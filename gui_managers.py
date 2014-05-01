import cv2

class CX_Gui(object):
    def __init__(self, window_name, enforcer, frame_size):
        self.enforcer = enforcer
        self.window_name = window_name
        self.a_frame = None
        self.frame_width = frame_size[0]
        self.frame_heigth = frame_size[1]

    def initialize_gui(self):
        # Create a window and bind function(s) to window
        cv2.namedWindow(self.window_name)
        #below should be modifiable:
        cv2.setMouseCallback(self.window_name, self.set_y_limit_low)

    # mouse callback function sets red line to enforce
    def set_y_limit_low(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            self.enforcer.set_y_limit_low(y_limit_low=y)

    def feed_frame(self, a_frame):
        self.a_frame = a_frame

    def display_rectangle_coords(self, x, y, w, h):
        """displays coords on screen"""
        cv2.putText(self.a_frame, "pos(x, y)=(%s,%s)" % (x, y), (x + w + 10, y + 15),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

        cv2.putText(self.a_frame, "size(w x h)=(%sx%s)" % (w, h), (x + w + 10, y + 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    def display_line(self, coord1, coord2, color=(0, 0, 255), thickness=1):
        """ # Draw a diagonal blue line with thickness of 5 px
            cv2.line(img,(0,0),(511,511),(255,0,0),5)"""
        cv2.line(self.a_frame, coord1, coord2 , color=color, thickness=thickness)

    def display_faces(self, faces_list, with_debug=False):
        """faces_list has format [(x, y, w, h), ..]"""
        #TODO: change the colour of the face rect when in warning.
        #TODO: create an average of the positions of the last faces.
        for (x, y, w, h) in faces_list:
            #TODO: change rectangle for frame-like only corners.
            self.display_line((0, y + h / 2), (x - 10, y + h /2), color=(0, 255, 0))
            #1280 should be passed somehow
            self.display_line((x + w + 10, y + h / 2), (1280, y + h /2), color=(0, 255, 0))
            if with_debug:
                cv2.rectangle(self.a_frame, (x, y), (x + w, y + h), (255, 0, 0), 1)   
                self.display_rectangle_coords(x, y, w, h)

    @staticmethod
    def get_action():
        #key handler:
        k = cv2.waitKey(1) & 0xFF
        if k == ord('q') or k == 27:
            return 'quit'
        elif k == ord('d'):
            return 'debug'
        elif k == ord('t'):
            return 'toggle_work_timer'
        elif k == ord('a'):
            return 'set_limit_auto'

    def show_controls(self):
        cv2.putText(self.a_frame, "Behave!!! :)", (10, 130),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        cv2.putText(self.a_frame, "Click with the mouse to set face limit", (10, 170),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        cv2.putText(self.a_frame, "Or press 'a' to have the limit automatically set", (10, 190),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        cv2.putText(self.a_frame, "Press 't' to set the work timer", (10, 210),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        cv2.putText(self.a_frame, "Press 'd' to debug, 'q' to quit", (10, 230),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
    
    def show_msg(self, msg):
            cv2.putText(self.a_frame, msg, (10, 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (255,255,255))

    def show_image(self, where):
        cv2.imshow(where, self.a_frame)

    def show_limits(self, face_enforcer):
        """displays red lines for the low limits"""
        self.display_line((0, face_enforcer.y_limit_low),
                                    (self.frame_width / 7, face_enforcer.y_limit_low), thickness=2)
        self.display_line((self.frame_width - (self.frame_width / 7), face_enforcer.y_limit_low),
                                    (1280, face_enforcer.y_limit_low), thickness=2)

    def show_debug(self, timer):
        #Timecv:
        cv2.putText(self.a_frame, "fps=%s avg=%s" % (timer.fps, timer.avg_fps), (10, 75),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))
        #Frame counter:
        cv2.putText(self.a_frame, "frame=%s" % (timer.frame_num), (10, 95),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    def show_contdown(self, time):
        cv2.putText(self.a_frame, "seconds left=%s" % (time), (10, 595),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    @staticmethod
    def close_window():
        cv2.destroyAllWindows()

