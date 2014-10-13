import time

from utils import Capturer, flip_frame, circular_counter, convert_to_gray, equalize, find_data_file
import classifiers

# This function will be called as a process from behave module.
def cam_loop(q_frames, q_control, FPS, verboseprint):

    FRAME_TIME = 1.0 / FPS
    CAP = FPS

    capturer = Capturer(cam_width=200, cam_height=150)
    counter = circular_counter(CAP)

    face_classifier = classifiers.CascadeClassifier(find_data_file('cascades/haarcascade_frontalface_alt.xml'))
    face_classifier.set_params(minSize=(30,30), maxSize=(100,100))

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

    def send_frame_and_face():
        face = None
        frame = prepare_frame()
        # detect only every CAP'th frame
        if counter.next() == CAP:
            face = detect_face_in_frame(frame)
        q_frames.put((frame, face))

    def send_face():
        if counter.next() == CAP:
            face = None
            frame = prepare_frame()
            face = detect_face_in_frame(frame)
            q_frames.put((None, face))

    def delay_to_fps(start_time):
        # delay in the frame so the while runs at FPS-speed
        end_time = time.time()
        loop_took = end_time - start_time
        if loop_took < FRAME_TIME:
            verboseprint('frame delayed %s' % str(FRAME_TIME - loop_took))
            time.sleep(FRAME_TIME - loop_took)
 
    def main_loop():
        send_frame = True
        working_switch = True

        while True:
            start_time = time.time()

            if not q_control.empty():
                control = q_control.get()
                if control == 'show_hide_camera':
                    verboseprint( 'show_hide received from gui')
                    send_frame = not send_frame
                if control == 'start_stop':
                    verboseprint( 'received start_stop from gui')
                    working_switch = not working_switch

            if working_switch:
                if send_frame:
                    send_frame_and_face()
                else:
                    send_face()

            delay_to_fps(start_time)

    main_loop()
    print( 'cam_loop process is stopping...')

