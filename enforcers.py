class EnforceFaceWithin(object):
    def __init__(self, trigger):
        self.wrongs_count = 0
        self.oks_count = 0
        self.nasty_trigger = trigger

        self.set_enforce_parameters()

    def set_enforce_parameters(self, wrongs_max=None, oks_max=None, y_limit_low=None):
        """TODO: change this to enforce seconds instead of frames?"""
        self.wrongs_max = 30 if not wrongs_max else wrongs_max
        self.oks_max = 10 if not oks_max else oks_max

        self.y_limit_low = 3000 if not y_limit_low else y_limit_low

    def reset_wrongs(self):
        self.wrongs_count = 0

    def reset_oks(self):
        self.oks_count = 0

    def check_face(self, face):
        # FACE POSITION CONTROL:
        x, y, w, h = face
        #mid_face_y is half the heigth of the face captured
        mid_face_y = y + (h / 2)

        if mid_face_y > self.y_limit_low:
            self.wrongs_count += 1
            self.reset_oks()
            print 'warning...(%s) :|' % self.wrongs_count

            if self.wrongs_count == self.wrongs_max:
                print 'Oh-oh, telling you that something is not right... :('
                self.reset_wrongs()
                return self.nasty_trigger

        #if some wrongs/warnings, then if some oks happened, reset warnings
        elif self.wrongs_count > 0:
            self.oks_count += 1
            print 'better...(%s) :)' % self.oks_count

            if self.oks_count == self.oks_max:
                print 'All good now! :D'
                self.reset_wrongs()
                self.reset_oks()
