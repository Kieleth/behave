import cv2
import subprocess
import sys

def say():
    subprocess.call('say -v Victoria "I think your back is not straight, bitch."&',
                    shell=True)

def flip_frame(frame):
    #1 flips horizontally:
    return cv2.flip(frame, 1)

def convert_to_gray_and_equalize(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    return gray

class Capturer(object):
    """ provides interface to the camera
    #TODO: automatize process of capturing by testing each channel
    """
    def __init__(self, channel=0):
        try:
            self._camera = cv2.VideoCapture(channel)
        except Exception as e:
            sys.exit('Unable to use the webcam, error: %s' % str(e))

        self._frame = None
        self._channel = channel
        self.cam_width = int(self._camera.get(3)) #cv2.CAP_PROP_FRAME_WIDTH)
        self.cam_height = int(self._camera.get(4)) #cv2.CAP_PROP_FRAME_HEIGHT) 

    def get_cam_width(self):
        return self.cam_width

    def get_cam_height(self):
        return self.cam_height

    def get_frame(self):
        _, frame = self._camera.read()
        return frame
    
    def release(self):
        self._camera.release()

def circular_counter(max):
    """helper function that creates an eternal counter till a max value"""
    x = 0
    while True:
        if x == max:
            x = 0
        x += 1
        yield x

class CvTimer(object):
    def __init__(self):
        self.tick_frequency = cv2.getTickFrequency()
        self.tick_at_init = cv2.getTickCount()
        self.last_tick = self.tick_at_init
        self.fps_len = 100
        self.l_fps_history = [ 10 for x in range(self.fps_len)]
        self.fps_counter = circular_counter(self.fps_len)
        self.frame_num = 0

    def new_frame(self):
        self.last_tick = cv2.getTickCount()
        self.frame_num += 1

    def get_tick_now(self):
        return cv2.getTickCount()

    @property    
    def fps(self):
        fps = self.tick_frequency / (self.get_tick_now() - self.last_tick)
        self.l_fps_history[self.fps_counter.next() - 1] = fps 
        return fps

    @property
    def avg_fps(self):
        return sum(self.l_fps_history) / float(self.fps_len) 
