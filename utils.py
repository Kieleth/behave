import cv2
import subprocess

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

class CvTimer(object):
    def __init__(self):
        self.tick_frequency = cv2.getTickFrequency()
        self.tick_at_init = cv2.getTickCount()
        self.last_tick = self.tick_at_init
        self.fps_history = []

    def reset(self):
        self.last_tick = cv2.getTickCount()

    def get_tick_now(self):
        return cv2.getTickCount()

    @property    
    def fps(self):
        fps = self.tick_frequency / (self.get_tick_now() - self.last_tick)
        self.fps_history.append(fps) 
        return fps

    @property
    def avg_fps(self):
        return float(sum(self.fps_history)) / len(self.fps_history) 
