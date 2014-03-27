class EnforceFaceWithin(object):
    def __init__(self, trigger):
        self.wrongs_count = 0
        self.oks_count = 0
        self.nasty_trigger = trigger

        self.set_enforce_parameters()

    def set_enforce_parameters(self, wrongs_max=None, oks_max=None,
                               x_limit_low=None, x_limit_high=None,
                               y_limit_low=None, y_limit_high=None):
        """TODO: change this to enforce seconds instead of frames?"""
        self.wrongs_max = 20 if not wrongs_max else wrongs_max
        self.oks_max = 10 if not oks_max else oks_max

        self.x_limit_low = 350 if not x_limit_low else x_limit_low
        self.x_limit_high = 650 if not x_limit_high else x_limit_high
        self.y_limit_low = 150 if not y_limit_low else y_limit_low
        self.y_limit_high = 0 if not y_limit_high else y_limit_high

    def reset_wrongs(self):
        self.wrongs_count = 0

    def reset_oks(self):
        self.oks_count = 0

    def check_face(self, face):
        # FACE POSITION CONTROL:
        x, y, w, h = face

        if (x < self.x_limit_low or
            x > self.x_limit_high or
            y > self.y_limit_low or
            y < self.y_limit_high):

            self.wrongs_count += 1
            print 'warning... :|'

            if self.wrongs_count == self.wrongs_max:
                print 'You are doing something wrong!!!'
                self.reset_wrongs()
                return self.nasty_trigger

        #if some wrongs/warnings, then if some oks happened, reset warnings
        elif self.wrongs_count > 0:
            self.oks_count += 1

            if self.oks_count == self.oks_max:
                print 'All good now... :)'
                self.reset_wrongs()
                self.reset_oks()
