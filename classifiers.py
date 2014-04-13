import cv2

class CascadeClassifier(object):
    def __init__(self, xml_file):
        try:
            self.cascade = cv2.CascadeClassifier(xml_file)
        except IOError as e:
            raise e

        self.set_cascade_params()

    def set_cascade_params(self, scale_factor=None, min_neigh=None, minSize=None, maxSize=None, flags=None):
        """Allows to modify the detector parameters on the fly, has defaults if any
           not initialized"""
        self.scale_factor = 1.3 if not scale_factor else scale_factor
        self.min_neigh = 4 if not min_neigh else min_neigh
        self.flags = cv2.CASCADE_SCALE_IMAGE if not flags else flags
        self.minSize = (200, 200) if not minSize else minSize
        self.maxSize = None if not maxSize else MaxSize # (300, 300)

    def detect_multiscale(self, image):
        """ calls detectMultiSsale with the parameters present in the class, returns
           a list of objects found"""
        found_list = self.cascade.detectMultiScale(image,
                                           self.scale_factor,
                                           self.min_neigh,
                                           minSize=self.minSize,
                                           maxSize=self.maxSize,
                                           flags=self.flags)
        return found_list

