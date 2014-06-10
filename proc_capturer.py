import time

from utils import Capturer, flip_frame, circular_counter, convert_to_gray, equalize
import classifiers

face_classifier = classifiers.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')

FPS = 15
FRAME_TIME = 1.0 / FPS

def detect_face_in_frame(a_frame):
    a_frame_prepared = equalize(a_frame)
    # watch out for detect_multiscale and the size of capture!
    faces_list = face_classifier.detect_multiscale(a_frame_prepared)

    return faces_list[0] if len(faces_list) == 1 else None

def cam_loop(q_frames, q_control, event):
    capturer = Capturer()
    count_5 = circular_counter(5)
    mode = 'show'

    while True:
        start = time.time()

        if not q_control.empty():
            control = q_control.get()

            if control == 'stop':
                print 'webcam capture process received "stop" from gui'
                break
            
            if control == 'show_hide_camera':
                print 'debug here', control
                if mode == 'show':
                    mode = 'hide'
                elif mode == 'hide':
                    mode = 'show'

        frame = capturer.get_frame()
        if frame is not None:
            frame = flip_frame(frame)
            frame = convert_to_gray(frame)

            # detect only every 5th frame
            face = None
            if count_5.next() == 5:
                face = detect_face_in_frame(frame)

            if mode == 'show':
                q_frames.put((frame, face))
            elif mode == 'hide':
                q_frames.put((None, face))

        # delay in the frame so it does not go beyond the FPS
        end = time.time()
        frame_took = end - start
        if frame_took > 0 and frame_took < FRAME_TIME:
            #print 'frame delayed %s' % str(FRAME_TIME - frame_took)
            time.sleep(FRAME_TIME - frame_took)

    print 'cam_loop process is stopping...'

