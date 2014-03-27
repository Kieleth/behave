import cv2

def say():
    subprocess.call('say -v Victoria "I think your back is not straight, Mister."&',
                    shell=True)

def delay_to(fps):
    time.sleep(1.0 / fps)

def flip_frame(frame):
    #1 flips horizontally:
    return cv2.flip(frame, 1)

def prepare_frame_for_detection(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    return gray

