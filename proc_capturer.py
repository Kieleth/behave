import time

from utils import Capturer, flip_frame, circular_counter, convert_to_gray, equalize
import classifiers


def cam_loop(q_frames, q_control):
    face_classifier = classifiers.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')
    face_classifier.set_params(minSize=(50,50), maxSize=(150,150))

    FPS = 12
    FRAME_TIME = 1.0 / FPS
    CAP = FPS

    def detect_face_in_frame(a_frame):
        a_frame_prepared = equalize(a_frame)
        # watch out for detect_multiscale and the size of capture!
        faces_list = face_classifier.detect_multiscale(a_frame_prepared)

        return faces_list[0] if len(faces_list) == 1 else None

    capturer = Capturer(cam_width=400, cam_height=300)
    count = circular_counter(CAP)
    show = True

    def prepare_frame():
        frame = capturer.get_frame()
        if frame is not None:
            frame = flip_frame(frame)
            return convert_to_gray(frame)

    while True:
        start = time.time()

        if not q_control.empty():
            control = q_control.get()
            if control == 'show_hide_camera':
                print( 'show_hide received from gui')
                show = not show
            if control == 'auto_adjust':
                pass
                #TODO HERE

        face = None
        if show:
            frame = prepare_frame()
            # detect only every 5th frame
            if count.next() == CAP:
                face = detect_face_in_frame(frame)
            q_frames.put((frame, face))

        else:
            if count.next() == CAP:
                frame = prepare_frame()
                face = detect_face_in_frame(frame)
                q_frames.put((None, face))

        # delay in the frame so it does not go beyond the FPS
        end = time.time()
        loop_took = end - start
        if loop_took > 0 and loop_took < FRAME_TIME:
            #print 'frame delayed %s' % str(FRAME_TIME - frame_took)
            time.sleep(FRAME_TIME - loop_took)
 
    print( 'cam_loop process is stopping...')

