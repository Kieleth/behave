import time

from utils import Capturer, flip_frame, circular_counter, convert_to_gray, equalize, find_data_file
import classifiers

# This function will be called as a process from behave module.
def cam_loop(q_frames, q_control):

    FPS = 12
    FRAME_TIME = 1.0 / FPS
    CAP = FPS
    send_frame = True
    working = True

    capturer = Capturer(cam_width=200, cam_height=150)
    counter = circular_counter(CAP)

    face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))
    face_classifier.set_params(minSize=(30,30), maxSize=(150,150))

    def detect_face_in_frame(a_frame):
        a_frame_prepared = equalize(a_frame)
        # watch out for detect_multiscale and the size of capture!
        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        return faces_list[0] if len(faces_list) == 1 else None

    def prepare_frame():
        frame = capturer.get_frame()
        if frame is not None:
            frame = flip_frame(frame)
            return convert_to_gray(frame)

    def do_send_frame():
        face = None
        frame = prepare_frame()
        # detect only every CAP'th frame
        if counter.next() == CAP:
            face = detect_face_in_frame(frame)
        q_frames.put((frame, face))

    def dont_send_frame():
        if counter.next() == CAP:
            face = None
            frame = prepare_frame()
            face = detect_face_in_frame(frame)
            q_frames.put((None, face))

    def adjust_to_fps(start_time):
        # delay in the frame so the while runs at FPS-speed
        end_time = time.time()
        loop_took = end_time - start_time
        if loop_took < FRAME_TIME:
            print 'frame delayed %s' % str(FRAME_TIME - loop_took)
            time.sleep(FRAME_TIME - loop_took)
 
    while True:
        start_time = time.time()

        if not q_control.empty():
            control = q_control.get()
            if control == 'show_hide_camera':
                print( 'show_hide received from gui')
                send_frame = not send_frame
            if control == 'start_stop':
                print( 'received start_stop from gui')
                working = not working

        if working:
            if send_frame:
                do_send_frame()
            else:
                dont_send_frame()

        adjust_to_fps(start_time)

    print( 'cam_loop process is stopping...')

