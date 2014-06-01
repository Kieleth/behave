from utils import Capturer, flip_frame, color_frame, circular_counter, convert_to_gray_and_equalize
import classifiers

face_classifier = classifiers.CascadeClassifier('cascades/haarcascade_frontalface_alt.xml')

def detect_face_in_frame(a_frame):
    a_frame_prepared = convert_to_gray_and_equalize(a_frame)
    faces_list = face_classifier.detect_multiscale(a_frame_prepared)

    return faces_list[0] if len(faces_list) == 1 else None

def cam_loop(the_q, event):
    capturer = Capturer()
    count_5 = circular_counter(5)

    while True:
        c = count_5.next()

        frame = capturer.get_frame()
        if frame is not None:
            if c == 5:
                face = detect_face_in_frame(frame)
                print face

            frame = flip_frame(frame)
            frame = color_frame(frame)
            

            the_q.put(frame)
            #event.set()


