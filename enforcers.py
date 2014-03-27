class EnforceFaceWithin(object):
    def __init__(self, trigger):
        self.count_wrongs = 0
        self.count_oks = 0
        self.nasty_trigger = trigger

        self.set_enforce_parameters()

    def set_enforce_parameters(self, max_wrongs=None, max_oks=None,
                               x_limit_low=None, x_limit_high=None,
                               y_limit_low=None, y_limit_high=None):
        """TODO: change this to enforce seconds instead of frames?"""
        self.max_wrongs = 20 if not max_wrongs else max_wrongs
        self.max_oks = 10 if not max_oks else max_oks

        self.x_limit_low = 350 if not x_limit_low else x_limit_low
        self.x_limit_high = 650 if not x_limit_high else x_limit_high
        self.y_limit_low = 150 if not y_limit_low else y_limit_low
        self.y_limit_high = 0 if not y_limit_high else y_limit_high

    def reset_wrongs(self):
        self.count_wrongs = 0

    def reset_oks(self):
        self.count_oks = 0

    def check_face(self, face):
        # FACE POSITION CONTROL:
        x, y, w, h = face

        if (x < self.x_limit_low or
            x > self.x_limit_high or
            y > self.y_limit_low or
            y < self.y_limit_high):

            self.counter_wrongs += 1
            print 'warning... :|'

            if self.counter_wrongs == self.max_wrongs:
                print 'You are doing something wrong!!!'
                self.reset_wrongs()
                return self.nasty_trigger

        #if some wrongs/warnings, then if some oks happened, reset warnings
        elif self.count_wrongs > 0:
            self.count_oks += 1

            if self.counter_oks == self.max_oks:
                print 'All good now... :)'
                self.reset_wrongs()
                self.reset_oks()
