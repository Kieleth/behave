import cv2
import subprocess
import sys
import os
import time

def say_warning():
    subprocess.call('say -v Victoria "I think your back is not straight, darling."&',
                    shell=True)

def flip_frame(frame):
    #1 flips horizontally:
    return cv2.flip(frame, 1)

def convert_to_gray_and_equalize(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    return gray

#cx_freeze data hanlder
def find_data_file(filename):
    if getattr(sys, 'frozen', False):
        # The application is frozen
        datadir = os.path.dirname(sys.executable)
    else:
        # The application is not frozen
        # Change this bit to match where you store your data files:
        datadir = os.path.dirname(__file__)

    return os.path.join(datadir, filename)

class Capturer(object):
    """ provides interface to the camera
    #TODO: automatize process of capturing by testing each channel
    """
    def __init__(self, channel=0, cam_width=800, cam_height=600):
        try:
            self._camera = cv2.VideoCapture(channel)
        except Exception as e:
            sys.exit('Unable to use the webcam, error: %s' % str(e))

        self._frame = None
        self.cam_width = cam_width
        self.cam_height = cam_height

        self._channel = channel
        self._camera.set(cv2.CAP_PROP_FRAME_WIDTH, cam_width)
        self._camera.set(cv2.CAP_PROP_FRAME_HEIGHT, cam_height)

    def get_camera_width_heigth(self):
        return self.cam_width, self.cam_height

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

    def mark_new_frame(self):
        self.last_tick = cv2.getTickCount()
        self.frame_num += 1

    def get_tick_now(self):
        return cv2.getTickCount()

    @property    
    def fps(self):
        fps = self.tick_frequency / (self.get_tick_now() - self.last_tick)
        self.l_fps_history[self.fps_counter.next() - 1] = fps 
        return int(fps)

    @property
    def avg_fps(self):
        return int(sum(self.l_fps_history) / float(self.fps_len))

class CountdownTimer(object):
    def __init__(self):
        self.start_time = 0
        self.contdown = 0

    def start(self, count_down_to=None):
        if count_down_to is None:
            self.contdown = 3000
        self.start_time = time.time()

    def stop(self):
        self.contdown = 0

    @property
    def is_started(self):
        return self.contdown

    def get_time_left(self):
        time_left = self.contdown - (time.time() - self.start_time)
        return int(time_left) if time_left >= 0 else 0
    
class FPSCounter(object):
    '''Helper class that tells if we need to process this frame or not
       Improves performance, a lot'''
    def __init__(self, every):
        self.every = every
        self.counter = every

    @property
    def check_if_capture(self):
        if self.counter == self.every:
            self.counter = 0
            return True
        else:
            self.counter += 1
        
        

