import time

from utils import Capturer, flip_frame, circular_counter, convert_to_gray, equalize
import classifiers


def cam_loop(q_frames, q_control):
    face_classifier = classifiers.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')

    FPS = 15
    FRAME_TIME = 1.0 / FPS

    def detect_face_in_frame(a_frame):
        a_frame_prepared = equalize(a_frame)
        # watch out for detect_multiscale and the size of capture!
        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        return faces_list[0] if len(faces_list) == 1 else None

    capturer = Capturer()
    count_5 = circular_counter(5)
    show = False

    while True:
        start = time.time()

        if not q_control.empty():
            control = q_control.get()
            
            if control == 'show_hide_camera':
                print( 'show_hide received from gui')
                show = not show

        frame = capturer.get_frame()
        if frame is not None:
            frame = flip_frame(frame)
            frame = convert_to_gray(frame)

            # detect only every 5th frame
            face = None
            if count_5.next() == 5:
                face = detect_face_in_frame(frame)

            if show:
                q_frames.put((frame, face))
            else:
                q_frames.put((None, face))

        # delay in the frame so it does not go beyond the FPS
        end = time.time()
        frame_took = end - start
        if frame_took > 0 and frame_took < FRAME_TIME:
            #print 'frame delayed %s' % str(FRAME_TIME - frame_took)
            time.sleep(FRAME_TIME - frame_took)
 
    print( 'cam_loop process is stopping...')

